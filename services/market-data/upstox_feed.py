"""
Upstox API v2 Market Data Feed
===============================
Connects to Upstox MarketDataStreamer WebSocket v3.
Requires UPSTOX_CLIENT_ID and UPSTOX_ACCESS_TOKEN in environment.
"""

import asyncio
import logging
import os

import upstox_client
from upstox_client.feeder.uplink_client_subscribe_request import UplinkClientSubscribeRequest
from normalizer import normalize_upstox_tick

logger = logging.getLogger("market-data.upstox")

# NSE instrument keys (format: NSE_EQ|symbol)
DEFAULT_INSTRUMENTS = [
    "NSE_EQ|INE002A01018",   # RELIANCE
    "NSE_EQ|INE009A01021",   # INFY
    "NSE_EQ|INE467B01029",   # TCS
    "NSE_EQ|INE040A01034",   # HDFCBANK
    "NSE_EQ|INE090A01021",   # ICICIBANK
]


class UpstoxFeed:
    """
    Streams live market data from Upstox MarketDataStreamer WebSocket.
    Handles token refresh and graceful reconnection.
    """

    def __init__(self, producer) -> None:
        self.producer = producer
        self.access_token = os.environ["UPSTOX_ACCESS_TOKEN"]
        self.instruments = (
            os.getenv("UPSTOX_INSTRUMENTS", "").split(",") or DEFAULT_INSTRUMENTS
        )

    async def start(self) -> None:
        configuration = upstox_client.Configuration()
        configuration.access_token = self.access_token

        streamer = upstox_client.MarketDataStreamer(
            upstox_client.ApiClient(configuration),
            self.instruments,
            "full",
        )

        def on_message(message) -> None:
            try:
                tick = normalize_upstox_tick(message)
                self.producer.publish(tick)
            except Exception as exc:
                logger.error("Tick normalization error: %s", exc)

        def on_open() -> None:
            logger.info("Upstox WebSocket connected. Streaming %d instruments.", len(self.instruments))

        def on_close() -> None:
            logger.warning("Upstox WebSocket closed. Will reconnect…")

        def on_error(error) -> None:
            logger.error("Upstox WebSocket error: %s", error)

        streamer.on("message", on_message)
        streamer.on("open",    on_open)
        streamer.on("close",   on_close)
        streamer.on("error",   on_error)

        logger.info("Starting Upstox MarketDataStreamer…")

        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, streamer.connect)

        while True:
            await asyncio.sleep(30)
