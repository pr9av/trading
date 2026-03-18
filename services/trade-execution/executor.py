"""
Trade Executor
==============
Executes orders: matches against real-time prices (via Redis LTP cache)
or simulates fill. Returns a completed trade dict.
"""

import logging
import os
import uuid
from datetime import datetime, timezone

import redis

logger = logging.getLogger("trade-execution.executor")

redis_client = redis.Redis(
    host=os.getenv("REDIS_HOST", "redis"),
    port=int(os.getenv("REDIS_PORT", 6379)),
    decode_responses=True,
)

# Brokerage fee model (simplified SEBI/exchange charges)
BROKERAGE_RATE = 0.0003   # 0.03% per leg
STT_RATE       = 0.001    # Securities Transaction Tax (sell side)
EXCHANGE_RATE  = 0.0000345


class TradeExecutor:
    """
    Determines fill price from cached LTP in Redis, calculates charges,
    and returns a complete trade record.
    """

    async def execute(self, order_event: dict) -> dict | None:
        symbol   = order_event.get("symbol", "")
        quantity = int(order_event.get("quantity", 0))
        side     = order_event.get("side", "BUY")
        order_id = order_event.get("order_id")

        if not symbol or quantity <= 0:
            return None

        fill_price = self._get_fill_price(order_event)

        trade_value = fill_price * quantity
        brokerage   = round(trade_value * BROKERAGE_RATE, 4)
        stt         = round(trade_value * STT_RATE, 4) if side == "SELL" else 0.0
        exchange_ch = round(trade_value * EXCHANGE_RATE, 4)
        taxes       = round(stt + exchange_ch, 4)
        net_value   = round(trade_value + brokerage + taxes if side == "BUY"
                            else trade_value - brokerage - taxes, 4)

        trade = {
            "trade_id":    str(uuid.uuid4()),
            "order_id":    order_id,
            "user_id":     order_event.get("user_id"),
            "symbol":      symbol,
            "exchange":    order_event.get("exchange", "NSE"),
            "side":        side,
            "quantity":    quantity,
            "price":       fill_price,
            "value":       round(trade_value, 4),
            "brokerage":   brokerage,
            "taxes":       taxes,
            "net_value":   net_value,
            "executed_at": datetime.now(tz=timezone.utc).isoformat(),
        }
        return trade

    def _get_fill_price(self, order_event: dict) -> float:
        """Try Redis LTP cache first; fallback to order limit price."""
        symbol = order_event.get("symbol", "")
        cached_ltp = redis_client.get(f"ltp:{symbol}")
        if cached_ltp:
            return float(cached_ltp)
        # LIMIT or specified price
        if order_event.get("price"):
            return float(order_event["price"])
        # Absolute fallback
        logger.warning("No price data for %s — using last known price 0.0", symbol)
        return 0.0
