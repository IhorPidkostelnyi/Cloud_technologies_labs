from collections.abc import Callable
from os import getenv
from uuid import uuid4

from pydantic import TypeAdapter
from redis.exceptions import RedisError

from redis_connection import client
from schemas import BookOutput

CACHE_ENABLED = getenv("BOOKS_CACHE_ENABLED", "false").lower() == "true"
TTL_SECONDS = 45
GENERATION_KEY = "library:books:generation"
books_json = TypeAdapter(tuple[BookOutput, ...])


def get_books(
    limit: int, author_id: int | None, load: Callable[[], tuple[BookOutput, ...]]
) -> tuple[tuple[BookOutput, ...], str]:
    if not CACHE_ENABLED or client is None:
        return load(), "BYPASS"

    try:
        generation = client.get(GENERATION_KEY)
        if generation is None:
            client.set(GENERATION_KEY, uuid4().hex, nx=True)
            generation = client.get(GENERATION_KEY)
        if generation is None:
            return load(), "BYPASS"

        key = f"library:books:{generation}:{author_id}:{limit}"
        cached = client.get(key)
    except RedisError:
        return load(), "BYPASS"

    if cached is not None:
        return books_json.validate_json(cached), "HIT"

    books = load()
    try:
        client.set(key, books_json.dump_json(books), ex=TTL_SECONDS)
    except RedisError:
        return books, "BYPASS"
    return books, "MISS"


def invalidate_books():
    if client is not None:
        try:
            client.set(GENERATION_KEY, uuid4().hex)
        except RedisError:
            pass
