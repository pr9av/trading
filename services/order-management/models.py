"""
OMS — Pydantic & SQLAlchemy Models
=====================================
Defines domain models for order creation, response, and DB persistence.
"""

import uuid
from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, validator
from sqlalchemy import Column, String, Integer, Numeric, DateTime, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()


# ── Enumerations ──────────────────────────────────────────────────────────────

class OrderSide(str, Enum):
    BUY  = "BUY"
    SELL = "SELL"


class OrderType(str, Enum):
    MARKET = "MARKET"
    LIMIT  = "LIMIT"
    SL     = "SL"
    SL_M   = "SL-M"


class ProductType(str, Enum):
    MIS  = "MIS"    # Intraday
    CNC  = "CNC"    # Delivery
    NRML = "NRML"   # F&O Normal


class OrderStatus(str, Enum):
    CREATED   = "created"
    VALIDATED = "validated"
    PLACED    = "placed"
    EXECUTED  = "executed"
    REJECTED  = "rejected"
    CANCELLED = "cancelled"


# ── SQLAlchemy ORM Model ──────────────────────────────────────────────────────

class OrderDB(Base):
    __tablename__ = "orders"

    id               = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id          = Column(UUID(as_uuid=True), nullable=False)
    broker_order_id  = Column(String(128))
    symbol           = Column(String(32), nullable=False)
    exchange         = Column(String(16), default="NSE")
    order_type       = Column(String(16), nullable=False)
    side             = Column(String(8),  nullable=False)
    product          = Column(String(16), default="MIS")
    quantity         = Column(Integer, nullable=False)
    price            = Column(Numeric(18, 4))
    trigger_price    = Column(Numeric(18, 4))
    status           = Column(String(32), default=OrderStatus.CREATED.value)
    filled_quantity  = Column(Integer, default=0)
    avg_fill_price   = Column(Numeric(18, 4))
    rejection_reason = Column(Text)
    broker           = Column(String(32), default="simulated")
    placed_at        = Column(DateTime(timezone=True))
    executed_at      = Column(DateTime(timezone=True))
    created_at       = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at       = Column(DateTime(timezone=True), default=datetime.utcnow)


# ── Pydantic Schemas ──────────────────────────────────────────────────────────

class OrderCreate(BaseModel):
    user_id:       str          = Field(..., description="UUID of the placing user")
    symbol:        str          = Field(..., example="RELIANCE")
    exchange:      str          = Field(default="NSE", example="NSE")
    order_type:    OrderType    = Field(default=OrderType.MARKET)
    side:          OrderSide
    product:       ProductType  = Field(default=ProductType.MIS)
    quantity:      int          = Field(..., gt=0, example=10)
    price:         Optional[float] = Field(None, ge=0, example=2850.00)
    trigger_price: Optional[float] = Field(None, ge=0)

    @validator("price")
    def validate_price(cls, v, values):  # noqa: N805
        if values.get("order_type") == OrderType.LIMIT and (v is None or v <= 0):
            raise ValueError("Price is required and must be > 0 for LIMIT orders.")
        return v


class OrderResponse(BaseModel):
    id:              str
    user_id:         str
    broker_order_id: Optional[str]
    symbol:          str
    exchange:        str
    order_type:      str
    side:            str
    product:         str
    quantity:        int
    price:           Optional[float]
    trigger_price:   Optional[float]
    status:          str
    filled_quantity: int
    avg_fill_price:  Optional[float]
    rejection_reason: Optional[str]
    broker:          str
    placed_at:       Optional[datetime]
    executed_at:     Optional[datetime]
    created_at:      datetime

    class Config:
        orm_mode = True
        json_encoders = {uuid.UUID: str}


# ── Portfolio Schemas ──────────────────────────────────────────────────────────

class PortfolioResponse(BaseModel):
    """Portfolio summary with cash balance and holdings value."""
    portfolio_id:   str
    user_id:        str
    cash_balance:   float
    holdings_value: float
    total_value:    float
    total_pnl:      float
    day_pnl:        float
    last_synced_at: Optional[str] = None


class HoldingResponse(BaseModel):
    """Individual stock holding."""
    id:              str
    symbol:          str
    exchange:        str
    quantity:        int
    avg_buy_price:   float
    current_price:   float
    pnl:             float
    updated_at:      Optional[str] = None
