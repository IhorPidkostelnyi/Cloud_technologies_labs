from collections import OrderedDict
from collections.abc import Callable
from os import getenv
from threading import Lock
from time import monotonic

from schemas import BookOutput

CACHE_ENABLED = getenv("BOOKS_CACHE_ENABLED", "false").lower() == "true"
TTL_SECONDS = 45
MAX_ENTRIES = 16
_entries: OrderedDict[int, tuple[float, tuple[BookOutput, ...]]] = OrderedDict()
_lock = Lock()


def get_books(
    limit: int, load: Callable[[], tuple[BookOutput, ...]]
) -> tuple[tuple[BookOutput, ...], str]:
    if not CACHE_ENABLED:
        return load(), "BYPASS"

    with _lock:
        now = monotonic()
        entry = _entries.get(limit)
        if entry is not None and entry[0] > now:
            _entries.move_to_end(limit)
            return entry[1], "HIT"

        books = load()
        _entries[limit] = (now + TTL_SECONDS, books)
        _entries.move_to_end(limit)
        if len(_entries) > MAX_ENTRIES:
            _entries.popitem(last=False)
        return books, "MISS"


def invalidate_books():
    if CACHE_ENABLED:
        with _lock:
            _entries.clear()
