import hashlib
from datetime import UTC, datetime, timedelta
from math import ceil

from fastapi import HTTPException
from pydantic import BaseModel
from redis.exceptions import RedisError
from sqlalchemy import text
from sqlalchemy.orm import Session

from models import BookRequest
from redis_connection import client
from schemas import BookInput, BookOutput

REPLAY_TTL = timedelta(hours=24)


class Replay(BaseModel):
    fingerprint: str
    book: BookOutput


def request_fingerprint(data: BookInput) -> str:
    return hashlib.sha256(data.model_dump_json().encode()).hexdigest()


def cache_key(key: str) -> str:
    return f"library:book-request:{key}"


def get_cached_replay(key: str) -> Replay | None:
    if client is not None:
        try:
            value = client.get(cache_key(key))
        except RedisError:
            return None
        if value is not None:
            return Replay.model_validate_json(value)
    return None


def cache_replay(key: str, replay: Replay, expires_at: datetime):
    remaining = ceil((expires_at - datetime.now(UTC)).total_seconds() * 1000)
    if client is not None and remaining > 0:
        try:
            client.set(cache_key(key), replay.model_dump_json(), px=remaining)
        except RedisError:
            pass


def replay_book(replay: Replay, fingerprint: str) -> BookOutput:
    if replay.fingerprint != fingerprint:
        raise HTTPException(409, "Idempotency-Key was already used with a different payload")
    return replay.book


def lock_book_request(db: Session, key: str) -> BookRequest | None:
    db.execute(
        text("SELECT pg_advisory_xact_lock(hashtextextended(:key, 75201))"),
        {"key": cache_key(key)},
    )
    return db.get(BookRequest, key)
