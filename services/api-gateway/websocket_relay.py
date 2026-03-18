"""
API Gateway — WebSocket Manager
==================================
Manages WebSocket client connections and streams real-time data
from Redis Pub/Sub channels to connected Flutter clients.
"""

import asyncio
import json
import logging
import os
from typing import Set

import redis.asyncio as aioredis
from fastapi import WebSocket

logger = logging.getLogger("api-gateway.websocket")

REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")


class WebSocketManager:
    """
    Manages a pool of connected WebSocket clients.
    Streams live tick data from Redis Pub/Sub to all subscribers.
    """

    def __init__(self) -> None:
        self._market_clients: Set[WebSocket]    = set()
        self._portfolio_clients: Set[WebSocket] = set()

    async def connect(self, ws: WebSocket) -> None:
        await ws.accept()

    def disconnect(self, ws: WebSocket) -> None:
        self._market_clients.discard(ws)
        self._portfolio_clients.discard(ws)

    async def stream_market_data(self, ws: WebSocket) -> None:
        """Subscribe to Redis 'market_ticks' channel and relay to WebSocket."""
        self._market_clients.add(ws)
        redis = aioredis.from_url(REDIS_URL)
        pubsub = redis.pubsub()
        await pubsub.subscribe("market_ticks")
        logger.info("WebSocket client subscribed to market_ticks. Total clients: %d",
                    len(self._market_clients))
        try:
            async for message in pubsub.listen():
                if message["type"] == "message":
                    data = message["data"]
                    if isinstance(data, bytes):
                        data = data.decode("utf-8")
                    await ws.send_text(data)
        finally:
            await pubsub.unsubscribe("market_ticks")
            await redis.aclose()
            self._market_clients.discard(ws)

    async def stream_portfolio_updates(self, ws: WebSocket) -> None:
        """Subscribe to Redis 'portfolio_updates' channel and relay to WebSocket."""
        self._portfolio_clients.add(ws)
        redis = aioredis.from_url(REDIS_URL)
        pubsub = redis.pubsub()
        await pubsub.subscribe("portfolio_updates")
        try:
            async for message in pubsub.listen():
                if message["type"] == "message":
                    data = message["data"]
                    if isinstance(data, bytes):
                        data = data.decode("utf-8")
                    await ws.send_text(data)
        finally:
            await pubsub.unsubscribe("portfolio_updates")
            await redis.aclose()
            self._portfolio_clients.discard(ws)

    async def broadcast(self, message: str, clients: Set[WebSocket]) -> None:
        """Broadcast a message to all connected clients in a set."""
        disconnected = set()
        for ws in clients:
            try:
                await ws.send_text(message)
            except Exception:
                disconnected.add(ws)
        clients -= disconnected
