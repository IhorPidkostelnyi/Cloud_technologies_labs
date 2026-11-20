import logging
import os
import time
from datetime import UTC, datetime
from typing import Annotated
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Response
from sqlalchemy import select, text
from sqlalchemy.exc import OperationalError, SQLAlchemyError, IntegrityError
from sqlalchemy.orm import Session

from book_cache import get_books, invalidate_books
from book_idempotency import (
    REPLAY_TTL,
    Replay,
    cache_replay,
    get_cached_replay,
    lock_book_request,
    replay_book,
    request_fingerprint,
)
from database import Base, engine, get_db
from models import Author, Book, BookRequest
from schemas import AuthorInput, AuthorOutput, BookInput, BookOutput

WELCOME_MESSAGE = "Library API v1"
logger = logging.getLogger("uvicorn.error")


@asynccontextmanager
async def lifespan(app: FastAPI):
    for attempt in range(30):
        try:
            with engine.begin() as connection:
                connection.execute(text("SELECT pg_advisory_xact_lock(15001)"))
                Base.metadata.create_all(connection)
            break
        except OperationalError:
            if attempt == 29:
                raise
            logger.warning("Database is not ready; retrying startup")
            time.sleep(2)
    yield
    engine.dispose()


app = FastAPI(title="Library API", version="2.0.0", lifespan=lifespan)


@app.get("/", tags=["service"])
def root():
    return {"message": WELCOME_MESSAGE, "revision": os.getenv("APP_REVISION", "local")}


@app.get("/health", tags=["service"])
def health(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
    except SQLAlchemyError:
        raise HTTPException(503, "Database unavailable") from None
    return {"status": "ok", "database": "connected"}


def find_or_404(db: Session, model, item_id: int):
    item = db.get(model, item_id)
    if item is None:
        raise HTTPException(404, "Record not found")
    return item


@app.post("/authors", response_model=AuthorOutput, status_code=201, tags=["authors"])
def create_author(data: AuthorInput, db: Session = Depends(get_db)):
    author = Author(**data.model_dump())
    db.add(author)
    db.commit()
    db.refresh(author)
    return author


@app.get("/authors", response_model=list[AuthorOutput], tags=["authors"])
def list_authors(limit: int = Query(100, ge=1, le=1000), db: Session = Depends(get_db)):
    return db.scalars(select(Author).order_by(Author.id).limit(limit)).all()


@app.get("/authors/{author_id}", response_model=AuthorOutput, tags=["authors"])
def get_author(author_id: int, db: Session = Depends(get_db)):
    return find_or_404(db, Author, author_id)


@app.put("/authors/{author_id}", response_model=AuthorOutput, tags=["authors"])
def update_author(author_id: int, data: AuthorInput, db: Session = Depends(get_db)):
    author = find_or_404(db, Author, author_id)
    author.name = data.name
    db.commit()
    db.refresh(author)
    return author


@app.delete("/authors/{author_id}", status_code=204, tags=["authors"])
def delete_author(author_id: int, db: Session = Depends(get_db)):
    author = find_or_404(db, Author, author_id)
    db.delete(author)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Delete this author's books first") from None
    return Response(status_code=204)


@app.post("/books", response_model=BookOutput, status_code=201, tags=["books"])
def create_book(
    data: BookInput,
    idempotency_key: Annotated[
        str | None, Header(min_length=1, max_length=128, pattern=r"^[!-~]+$")
    ] = None,
    db: Session = Depends(get_db),
):
    if idempotency_key is None:
        return insert_book(db, data)

    fingerprint = request_fingerprint(data)
    replay = get_cached_replay(idempotency_key)
    if replay is not None:
        return replay_book(replay, fingerprint)

    request = lock_book_request(db, idempotency_key)
    now = datetime.now(UTC)
    if request is not None and request.expires_at > now:
        replay = Replay(fingerprint=request.fingerprint, book=request.response)
        result = replay_book(replay, fingerprint)
        expiry = request.expires_at
        db.commit()
        cache_replay(idempotency_key, replay, expiry)
        return result

    return insert_book(db, data, idempotency_key, request, fingerprint)


def insert_book(
    db: Session,
    data: BookInput,
    key: str | None = None,
    request: BookRequest | None = None,
    fingerprint: str = "",
) -> BookOutput:
    find_or_404(db, Author, data.author_id)
    book = Book(**data.model_dump())
    db.add(book)
    try:
        db.flush()
        result = BookOutput.model_validate(book)
        if key is not None:
            expiry = datetime.now(UTC) + REPLAY_TTL
            if request is None:
                request = BookRequest(key=key)
                db.add(request)
            request.fingerprint = fingerprint
            request.response = result.model_dump(mode="json")
            request.expires_at = expiry
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Author was removed; choose another author") from None

    invalidate_books()
    if key is not None:
        cache_replay(key, Replay(fingerprint=fingerprint, book=result), expiry)
    return result


@app.get("/books", response_model=list[BookOutput], tags=["books"])
def list_books(
    response: Response,
    limit: int = Query(100, ge=1, le=1000),
    author_id: int | None = Query(None, gt=0),
    db: Session = Depends(get_db),
):
    def load():
        query = select(Book)
        if author_id is not None:
            query = query.where(Book.author_id == author_id)
        books = db.scalars(query.order_by(Book.id).limit(limit))
        return tuple(BookOutput.model_validate(book) for book in books)

    books, cache_result = get_books(limit, author_id, load)
    response.headers["X-Books-Cache"] = cache_result
    return books


@app.get("/books/{book_id}", response_model=BookOutput, tags=["books"])
def get_book(book_id: int, db: Session = Depends(get_db)):
    return find_or_404(db, Book, book_id)


@app.put("/books/{book_id}", response_model=BookOutput, tags=["books"])
def update_book(book_id: int, data: BookInput, db: Session = Depends(get_db)):
    book = find_or_404(db, Book, book_id)
    find_or_404(db, Author, data.author_id)
    for field, value in data.model_dump().items():
        setattr(book, field, value)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Author was removed; choose another author") from None
    invalidate_books()
    db.refresh(book)
    return book


@app.delete("/books/{book_id}", status_code=204, tags=["books"])
def delete_book(book_id: int, db: Session = Depends(get_db)):
    db.delete(find_or_404(db, Book, book_id))
    db.commit()
    invalidate_books()
    return Response(status_code=204)
