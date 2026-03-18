"""
API Gateway — Redis-backed Rate Limiter
========================================
Implements a sliding window rate limiter using Redis.
Default: 100 requests per minute per user.
"""

import logging
import os
import time
from fastapi import HTTPException, Request, status
import redis

logger = logging.getLogger("api-gateway.rate_limiter")

redis_client = redis.Redis(
    host=os.getenv("REDIS_HOST", "redis"),
    port=int(os.getenv("REDIS_PORT", 6379)),
    decode_responses=True,
)

RATE_LIMIT   = int(os.getenv("RATE_LIMIT_REQUESTS", "100"))   # max requests
WINDOW_SEC   = int(os.getenv("RATE_LIMIT_WINDOW_SEC", "60"))  # per window (seconds)


class RateLimiter:
    """
    Sliding window rate limiter.
    Keyed per authenticated user; falls back to IP address for unauthenticated requests.
    """

    async def __call__(self, request: Request) -> None:
        await self.check(request, user=None)

    async def check(self, request: Request, user: dict | None) -> None:
        identifier = user["user_id"] if user else request.client.host
        key        = f"rate:{identifier}"
        now        = int(time.time())
        window_start = now - WINDOW_SEC

        pipe = redis_client.pipeline()
        pipe.zremrangebyscore(key, 0, window_start)         # Remove old entries
        pipe.zadd(key, {str(now): now})                     # Add current request
        pipe.zcard(key)                                     # Count in window
        pipe.expire(key, WINDOW_SEC)                        # Auto-expire key
        _, _, count, _ = pipe.execute()

        if count > RATE_LIMIT:
            logger.warning("Rate limit exceeded for %s (%d/%d)", identifier, count, RATE_LIMIT)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded: {RATE_LIMIT} requests per {WINDOW_SEC}s allowed.",
                headers={"Retry-After": str(WINDOW_SEC)},
            )
