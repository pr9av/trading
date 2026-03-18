"""
Simulated NSE Market Data Feed
================================
Generates realistic tick data for NSE equities using random walks
with volatility profiles. Used as a fallback when no broker is configured.
"""

import asyncio
import logging
import random
from datetime import datetime, timezone

from normalizer import MarketTick

logger = logging.getLogger("market-data.simulated")

# Symbol → (base_price, daily_volatility)
NSE_INSTRUMENTS = {
    "RELIANCE":  (2850.00, 0.012),
    "INFY":      (1740.00, 0.010),
    "TCS":       (3900.00, 0.009),
    "HDFCBANK":  (1650.00, 0.011),
    "ICICIBANK": (1100.00, 0.013),
    "WIPRO":     (470.00,  0.012),
    "AXISBANK":  (1050.00, 0.014),
    "SBIN":      (780.00,  0.015),
    "BHARTIARTL":(1580.00, 0.010),
    "BAJFINANCE":(7100.00, 0.016),
}


class SimulatedFeed:
    """
    Simulates realistic NSE tick data using geometric Brownian motion.
    Each symbol has its own price state and volatility profile.
    """

    def __init__(self, producer) -> None:
        self.producer = producer
        # Current price state per symbol
        self._prices = {sym: base for sym, (base, _) in NSE_INSTRUMENTS.items()}
        self._interval_ms = 500  # tick every 500ms

    async def start(self) -> None:
        logger.info("Simulated NSE feed started. Streaming %d instruments @ %dms intervals.",
                    len(NSE_INSTRUMENTS), self._interval_ms)

        while True:
            for symbol, (_, volatility) in NSE_INSTRUMENTS.items():
                tick = self._generate_tick(symbol, volatility)
                self.producer.publish(tick)

            await asyncio.sleep(self._interval_ms / 1000)

    def _generate_tick(self, symbol: str, volatility: float) -> MarketTick:
        """Apply a small random return to simulate a price movement."""
        drift = 0.00002  # slight upward drift
        shock = random.gauss(drift, volatility / 20)

        prev_price = self._prices[symbol]
        ltp = round(max(prev_price * (1 + shock), 1.0), 2)
        self._prices[symbol] = ltp

        spread = round(ltp * 0.0001, 2)
        volume = random.randint(100, 10_000)

        return MarketTick(
            time=datetime.now(tz=timezone.utc).isoformat(),
            symbol=symbol,
            exchange="NSE",
            ltp=ltp,
            open=round(ltp * (1 - random.uniform(0, 0.005)), 2),
            high=round(ltp * (1 + random.uniform(0, 0.008)), 2),
            low=round(ltp  * (1 - random.uniform(0, 0.008)), 2),
            close=round(ltp * (1 - random.uniform(0, 0.002)), 2),
            volume=volume,
            oi=random.randint(10_000, 1_000_000),
            bid=round(ltp - spread, 2),
            ask=round(ltp + spread, 2),
            broker_source="simulated",
        )
