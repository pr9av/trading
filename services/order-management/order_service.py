"""
OMS — Order Service
=====================
Business logic layer: validates, persists, routes to broker, and publishes Kafka events.
"""

import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session

from broker_order import BrokerOrderRouter
from kafka_producer import OrderEventProducer
from models import OrderCreate, OrderDB, OrderResponse, OrderStatus

logger = logging.getLogger("order-management.order_service")


class OrderService:
    def __init__(self, db: Session, producer: OrderEventProducer) -> None:
        self.db       = db
        self.producer = producer
        self.router   = BrokerOrderRouter()

    async def create_order(self, payload: OrderCreate) -> OrderResponse:
        # ── 1. Validate ───────────────────────────────────────────────────────
        self._validate(payload)

        # ── 2. Persist with CREATED status ───────────────────────────────────
        db_order = OrderDB(
            id=uuid.uuid4(),
            user_id=uuid.UUID(payload.user_id),
            symbol=payload.symbol.upper(),
            exchange=payload.exchange.upper(),
            order_type=payload.order_type,
            side=payload.side,
            product=payload.product,
            quantity=payload.quantity,
            price=payload.price,
            trigger_price=payload.trigger_price,
            status=OrderStatus.VALIDATED.value,
            broker=__import__("os").getenv("ACTIVE_BROKER", "simulated"),
        )
        self.db.add(db_order)
        self.db.commit()
        self.db.refresh(db_order)

        # ── 3. Publish VALIDATED event ────────────────────────────────────────
        self.producer.publish_order_event(db_order, "ORDER_VALIDATED")

        # ── 4. Route to broker ────────────────────────────────────────────────
        broker_id, new_status = await self.router.place(db_order)

        # ── 5. Update status ──────────────────────────────────────────────────
        db_order.broker_order_id = broker_id
        db_order.status = new_status
        db_order.placed_at = datetime.now(tz=timezone.utc)
        if new_status == OrderStatus.EXECUTED.value:
            db_order.executed_at = datetime.now(tz=timezone.utc)
            db_order.filled_quantity = payload.quantity
            db_order.avg_fill_price  = payload.price

        self.db.commit()
        self.db.refresh(db_order)

        # ── 6. Publish PLACED / EXECUTED event ────────────────────────────────
        event_type = "ORDER_EXECUTED" if new_status == "executed" else "ORDER_PLACED"
        self.producer.publish_order_event(db_order, event_type)

        logger.info("Order %s → status=%s broker_id=%s", db_order.id, new_status, broker_id)
        return OrderResponse.from_orm(db_order)

    # ── Queries ───────────────────────────────────────────────────────────────

    def get_order(self, order_id: str) -> Optional[OrderResponse]:
        row = self.db.query(OrderDB).filter(OrderDB.id == uuid.UUID(order_id)).first()
        return OrderResponse.from_orm(row) if row else None

    def list_orders(self, user_id: str = None, symbol: str = None, limit: int = 50) -> list[OrderResponse]:
        q = self.db.query(OrderDB)
        if user_id:
            q = q.filter(OrderDB.user_id == uuid.UUID(user_id))
        if symbol:
            q = q.filter(OrderDB.symbol == symbol.upper())
        rows = q.order_by(OrderDB.created_at.desc()).limit(limit).all()
        return [OrderResponse.from_orm(r) for r in rows]

    def cancel_order(self, order_id: str) -> None:
        row = self.db.query(OrderDB).filter(OrderDB.id == uuid.UUID(order_id)).first()
        if not row:
            raise ValueError(f"Order {order_id} not found.")
        if row.status in (OrderStatus.EXECUTED.value, OrderStatus.CANCELLED.value, OrderStatus.REJECTED.value):
            raise ValueError(f"Cannot cancel order in status '{row.status}'.")
        row.status = OrderStatus.CANCELLED.value
        self.db.commit()
        self.producer.publish_order_event(row, "ORDER_CANCELLED")

    # ── Validation ────────────────────────────────────────────────────────────

    def _validate(self, payload: OrderCreate) -> None:
        """Comprehensive order validation."""
        # Basic validation
        if not payload.symbol or len(payload.symbol.strip()) == 0:
            raise ValueError("Symbol cannot be empty.")
        
        if payload.quantity <= 0:
            raise ValueError("Quantity must be a positive integer.")
        
        if payload.quantity > 100000:
            raise ValueError("Quantity exceeds maximum limit (100,000).")
        
        # Price validation
        if payload.order_type in ("LIMIT", "SL") and not payload.price:
            raise ValueError("Price is required for LIMIT and SL orders.")
        
        if payload.price and payload.price <= 0:
            raise ValueError("Price must be positive.")
        
        if payload.price and payload.price > 1000000:
            raise ValueError("Price exceeds maximum limit (₹10,00,000).")
        
        # Trigger price validation
        if payload.order_type in ("SL", "SL-M") and not payload.trigger_price:
            raise ValueError("Trigger price is required for SL/SL-M orders.")
        
        if payload.trigger_price and payload.trigger_price <= 0:
            raise ValueError("Trigger price must be positive.")
        
        # Logic validation
        if payload.order_type in ("SL", "SL-M"):
            if payload.side == "BUY" and payload.trigger_price >= (payload.price or payload.trigger_price):
                raise ValueError("For BUY SL orders, trigger price must be below limit price.")
            elif payload.side == "SELL" and payload.trigger_price <= (payload.price or payload.trigger_price):
                raise ValueError("For SELL SL orders, trigger price must be above limit price.")
        
        # Exchange validation
        valid_exchanges = ["NSE", "BSE", "NCDEX", "MCX"]
        if payload.exchange.upper() not in valid_exchanges:
            raise ValueError(f"Invalid exchange. Valid options: {', '.join(valid_exchanges)}")
        
        # User validation
        try:
            uuid.UUID(payload.user_id)
        except ValueError:
            raise ValueError("Invalid user_id format.")
        
        logger.info("Order validation passed for symbol=%s, quantity=%d", payload.symbol, payload.quantity)
