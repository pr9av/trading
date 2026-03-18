"""
Blauplug Trading Platform — Order Management System (OMS)
==========================================================
REST API for order lifecycle management with broker routing.
"""

import logging
import os
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy.orm import Session

from database import engine, Base, get_db
from models import OrderCreate, OrderResponse, OrderStatus, PortfolioResponse, HoldingResponse
from order_service import OrderService
from portfolio_service import PortfolioService
from kafka_producer import OrderEventProducer

Base.metadata.create_all(bind=engine)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("order-management")

# ── App Init ──────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Blauplug OMS — Order Management System",
    description="Manages the full order lifecycle: creation, validation, broker routing, and event publishing.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

Instrumentator().instrument(app).expose(app, endpoint="/metrics")

producer = OrderEventProducer()


# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/health", tags=["Ops"])
async def health() -> dict:
    return {"status": "healthy", "service": "order-management"}


@app.post("/orders", response_model=OrderResponse, status_code=status.HTTP_201_CREATED, tags=["Orders"])
async def place_order(payload: OrderCreate, db: Session = Depends(get_db)) -> OrderResponse:
    """
    Place a new buy or sell order.
    - Validates margin requirements.
    - Routes to the configured broker (Zerodha / Upstox / Simulated).
    - Publishes an order_event to Kafka.
    """
    service = OrderService(db, producer)
    try:
        order = await service.create_order(payload)
        logger.info("Order created: %s | %s %s x%d @ %.2f",
                    order.id, order.side, order.symbol, order.quantity, order.price or 0)
        return order
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc))


@app.get("/orders", response_model=list[OrderResponse], tags=["Orders"])
async def list_orders(user_id: str = None, symbol: str = None,
                      limit: int = 50, db: Session = Depends(get_db)) -> list[OrderResponse]:
    """List orders with optional filters by user or symbol."""
    service = OrderService(db, producer)
    return service.list_orders(user_id=user_id, symbol=symbol, limit=limit)


@app.get("/orders/{order_id}", response_model=OrderResponse, tags=["Orders"])
async def get_order(order_id: str, db: Session = Depends(get_db)) -> OrderResponse:
    """Fetch a single order by ID."""
    service = OrderService(db, producer)
    order = service.get_order(order_id)
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Order {order_id} not found.")
    return order


@app.delete("/orders/{order_id}", status_code=status.HTTP_200_OK, tags=["Orders"])
async def cancel_order(order_id: str, db: Session = Depends(get_db)) -> dict:
    """Cancel a pending order."""
    service = OrderService(db, producer)
    try:
        service.cancel_order(order_id)
        return {"message": f"Order {order_id} cancelled successfully."}
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


# ── Portfolio Endpoints ────────────────────────────────────────────────────────

@app.get("/portfolio/{user_id}", response_model=PortfolioResponse, tags=["Portfolio"])
async def get_portfolio(user_id: str, db: Session = Depends(get_db)) -> PortfolioResponse:
    """Get user portfolio summary including cash balance and P&L."""
    service = PortfolioService(db)
    portfolio = service.get_portfolio(user_id)
    if not portfolio:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found.")
    return portfolio


@app.get("/portfolio/{user_id}/holdings", response_model=list[HoldingResponse], tags=["Portfolio"])
async def get_holdings(user_id: str, db: Session = Depends(get_db)) -> list[HoldingResponse]:
    """Get all stock holdings for a user."""
    service = PortfolioService(db)
    return service.get_holdings(user_id)
