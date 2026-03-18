"""
Broker Factory
==============
Reads ACTIVE_BROKER from environment and returns the appropriate
feed implementation. Supports: zerodha | upstox | simulated
"""

import os
import logging

logger = logging.getLogger("market-data.broker_factory")


class BrokerFactory:
    """Instantiates the correct market data feed based on ACTIVE_BROKER env var."""

    @staticmethod
    def create(producer):
        broker = os.getenv("ACTIVE_BROKER", "simulated").lower().strip()

        if broker == "zerodha":
            logger.info("BrokerFactory → Zerodha Kite Connect selected")
            from zerodha_feed import ZerodhaFeed
            return ZerodhaFeed(producer)

        elif broker == "upstox":
            logger.info("BrokerFactory → Upstox API v2 selected")
            from upstox_feed import UpstoxFeed
            return UpstoxFeed(producer)

        else:
            logger.info("BrokerFactory → Simulated NSE feed selected (fallback)")
            from simulated_feed import SimulatedFeed
            return SimulatedFeed(producer)
