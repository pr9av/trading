"""
OMS — Broker Order Router
==========================
Routes order placement to Zerodha, Upstox, or a simulated engine
based on ACTIVE_BROKER env var. Returns a broker_order_id on success.
"""

import logging
import os
import uuid as uuid_mod
from datetime import datetime, timezone

logger = logging.getLogger("order-management.broker_order")


class BrokerOrderRouter:
    """
    Sends validated orders to the configured broker's order placement API.
    Falls back to simulated execution if no real broker is configured.
    """

    def __init__(self) -> None:
        self.broker = os.getenv("ACTIVE_BROKER", "simulated").lower()

    async def place(self, order) -> tuple[str | None, str]:
        """
        Place an order and return (broker_order_id, resulting_status).
        """
        if self.broker == "zerodha":
            return await self._place_zerodha(order)
        elif self.broker == "upstox":
            return await self._place_upstox(order)
        else:
            return self._place_simulated(order)

    # ── Zerodha ──────────────────────────────────────────────────────────────

    async def _place_zerodha(self, order) -> tuple[str, str]:
        from kiteconnect import KiteConnect

        kite = KiteConnect(api_key=os.environ["ZERODHA_API_KEY"])
        kite.set_access_token(os.environ["ZERODHA_ACCESS_TOKEN"])

        params = {
            "tradingsymbol": order.symbol,
            "exchange":      order.exchange,
            "transaction_type": order.side,
            "order_type":    order.order_type,
            "product":       order.product,
            "quantity":      order.quantity,
        }
        if order.price:
            params["price"] = float(order.price)
        if order.trigger_price:
            params["trigger_price"] = float(order.trigger_price)

        try:
            response = kite.place_order(variety=kite.VARIETY_REGULAR, **params)
            broker_id = str(response.get("order_id", ""))
            logger.info("Zerodha order placed: broker_id=%s", broker_id)
            return broker_id, "placed"
        except Exception as exc:
            logger.error("Zerodha order placement failed: %s", exc)
            return None, "rejected"

    # ── Upstox ───────────────────────────────────────────────────────────────

    async def _place_upstox(self, order) -> tuple[str, str]:
        import upstox_client

        configuration = upstox_client.Configuration()
        configuration.access_token = os.environ["UPSTOX_ACCESS_TOKEN"]

        order_api = upstox_client.OrderApi(upstox_client.ApiClient(configuration))

        body = upstox_client.PlaceOrderRequest(
            quantity      = order.quantity,
            product       = order.product,
            validity      = "DAY",
            price         = float(order.price) if order.price else 0,
            tag           = "blauplug",
            instrument_token = f"{order.exchange}_EQ|{order.symbol}",
            order_type    = order.order_type,
            transaction_type = order.side,
            disclosed_quantity = 0,
            trigger_price = float(order.trigger_price) if order.trigger_price else 0,
            is_amo        = False,
        )

        try:
            response = order_api.place_order(body, api_version="2.0")
            broker_id = response.data.order_id if response.data else None
            logger.info("Upstox order placed: broker_id=%s", broker_id)
            return broker_id, "placed"
        except Exception as exc:
            logger.error("Upstox order placement failed: %s", exc)
            return None, "rejected"

    # ── Simulated ─────────────────────────────────────────────────────────────

    def _place_simulated(self, order) -> tuple[str, str]:
        simulated_id = f"SIM-{str(uuid_mod.uuid4())[:8].upper()}"
        logger.info("Simulated order placed: broker_id=%s", simulated_id)
        return simulated_id, "executed"
