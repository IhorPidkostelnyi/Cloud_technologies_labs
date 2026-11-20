import os

from redis import Redis
from redis.backoff import NoBackoff
from redis.retry import Retry

host = os.getenv("REDIS_HOST")
client = (
    Redis(
        host=host,
        port=int(os.getenv("REDIS_PORT", "6379")),
        password=os.getenv("REDIS_PASSWORD"),
        ssl=os.getenv("REDIS_TLS", "false").lower() == "true",
        ssl_check_hostname=True,
        decode_responses=True,
        socket_connect_timeout=0.5,
        socket_timeout=0.5,
        retry=Retry(NoBackoff(), 0),
    )
    if host
    else None
)
