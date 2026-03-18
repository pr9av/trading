"""
Zerodha Kite Connect Feed
=========================
Connects to Zerodha KiteTicker WebSocket and streams live tick data.
Requires ZERODHA_API_KEY and ZERODHA_ACCESS_TOKEN in environment.
"""

import asyncio
import logging
import os
from typing import Any

from kiteconnect import KiteTicker
from normalizer import normalize_zerodha_tick

logger = logging.getLogger("market-data.zerodha")

# Default instrument tokens for NSE equities (RELIANCE, INFY, TCS, HDFC, etc.)
DEFAULT_TOKENS = [
    738561,   # RELIANCE
    408065,   # INFY
    2953217,  # TCS
    341249,   # HDFCBANK
    895745,   # ICICIBANK
    2885633,  # WIPRO
]


class ZerodhaFeed:
    """
    Streams live market ticks from Zerodha KiteTicker WebSocket.
    Auto-reconnects on disconnection with exponential back-off.
    """

    def __init__(self, producer) -> None:
        self.producer = producer
        self.api_key = os.environ["ZERODHA_API_KEY"]
        self.access_token = os.environ["ZERODHA_ACCESS_TOKEN"]
        self.tokens = list(map(int, os.getenv("ZERODHA_TOKENS", "").split(","))) or DEFAULT_TOKENS
        self._reconnect_delay = 1  # seconds

    async def start(self) -> None:
        loop = asyncio.get_event_loop()

        def on_ticks(ws, ticks: list[dict[str, Any]]) -> None:
            for raw_tick in ticks:
                try:
                    tick = normalize_zerodha_tick(raw_tick)
                    self.producer.publish(tick)
                except Exception as exc:
                    logger.error("Tick normalization error: %s", exc)

        def on_connect(ws, response) -> None:
            logger.info("Zerodha WebSocket connected. Subscribing to %d instruments.", len(self.tokens))
            ws.subscribe(self.tokens)
            ws.set_mode(ws.MODE_FULL, self.tokens)
            self._reconnect_delay = 1  # reset backoff on successful connect

        def on_close(ws, code, reason) -> None:
            logger.warning("Zerodha WebSocket closed [%s]: %s. Reconnecting in %ds…", code, reason, self._reconnect_delay)

        def on_error(ws, code, reason) -> None:
            logger.error("Zerodha WebSocket error [%s]: %s", code, reason)

        def on_reconnect(ws, attempts_count) -> None:
            logger.info("Reconnecting to Zerodha… attempt %d", attempts_count)

        kws = KiteTicker(self.api_key, self.access_token)
        kws.on_ticks     = on_ticks
        kws.on_connect   = on_connect
        kws.on_close     = on_close
        kws.on_error     = on_error
        kws.on_reconnect = on_reconnect

        logger.info("Starting Zerodha KiteTicker…")
        await loop.run_in_executor(
            None,
            lambda: kws.connect(threaded=True, reconnect=True, max_reconnect_delay=60),
        )

        # Keep the coroutine alive
        while True:
            await asyncio.sleep(30)
