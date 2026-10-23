import logging
import os
import time
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Query, Response
from sqlalchemy import select, text
from sqlalchemy.exc import OperationalError, SQLAlchemyError, IntegrityError
from sqlalchemy.orm import Session

from database import Base, engine, get_db
from models import Author, Book
from schemas import AuthorInput, AuthorOutput, BookInput, BookOutput

WELCOME_MESSAGE = "Library API v1"
logger = logging.getLogger("uvicorn.error")


@asynccontextmanager
async def lifespan(app: FastAPI):
    for attempt in range(30):
        try:
            # Serialize initial schema creation during overlapping deployments.
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


app = FastAPI(title="Library API", version="1.0.0", lifespan=lifespan)


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
def create_book(data: BookInput, db: Session = Depends(get_db)):
    find_or_404(db, Author, data.author_id)
    book = Book(**data.model_dump())
    db.add(book)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Author was removed; choose another author") from None
    db.refresh(book)
    return book


@app.get("/books", response_model=list[BookOutput], tags=["books"])
def list_books(limit: int = Query(100, ge=1, le=1000), db: Session = Depends(get_db)):
    return db.scalars(select(Book).order_by(Book.id).limit(limit)).all()


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
    db.refresh(book)
    return book


@app.delete("/books/{book_id}", status_code=204, tags=["books"])
def delete_book(book_id: int, db: Session = Depends(get_db)):
    db.delete(find_or_404(db, Book, book_id))
    db.commit()
    return Response(status_code=204)
