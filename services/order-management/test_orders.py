"""
Test suite for Order Management Service
"""

import pytest
import uuid
from datetime import datetime, timezone
from models import OrderCreate, OrderStatus, OrderSide, OrderType, ProductType


@pytest.fixture
def order_payload():
    """Create a sample order payload."""
    return OrderCreate(
        user_id=str(uuid.uuid4()),
        symbol="RELIANCE",
        exchange="NSE",
        order_type=OrderType.MARKET,
        side=OrderSide.BUY,
        product=ProductType.MIS,
        quantity=10,
        price=2850.00,
    )


def test_order_create_validation():
    """Test order creation validation."""
    # Valid order
    order = OrderCreate(
        user_id=str(uuid.uuid4()),
        symbol="RELIANCE",
        side=OrderSide.BUY,
        quantity=10,
        order_type=OrderType.MARKET,
    )
    assert order.symbol == "RELIANCE"
    assert order.quantity == 10

    # Invalid quantity
    with pytest.raises(ValueError):
        OrderCreate(
            user_id=str(uuid.uuid4()),
            symbol="RELIANCE",
            side=OrderSide.BUY,
            quantity=-5,
            order_type=OrderType.MARKET,
        )


def test_order_side_enum():
    """Test order side enumeration."""
    assert OrderSide.BUY.value == "BUY"
    assert OrderSide.SELL.value == "SELL"


def test_order_type_enum():
    """Test order type enumeration."""
    assert OrderType.MARKET.value == "MARKET"
    assert OrderType.LIMIT.value == "LIMIT"


def test_order_status_enum():
    """Test order status enumeration."""
    assert OrderStatus.CREATED.value == "created"
    assert OrderStatus.VALIDATED.value == "validated"
    assert OrderStatus.PLACED.value == "placed"
    assert OrderStatus.EXECUTED.value == "executed"


def test_limit_order_requires_price():
    """Test that LIMIT orders require a price."""
    with pytest.raises(ValueError):
        OrderCreate(
            user_id=str(uuid.uuid4()),
            symbol="RELIANCE",
            side=OrderSide.BUY,
            quantity=10,
            order_type=OrderType.LIMIT,
            price=None,
        )


def test_market_order_optional_price():
    """Test that MARKET orders don't require a price."""
    order = OrderCreate(
        user_id=str(uuid.uuid4()),
        symbol="RELIANCE",
        side=OrderSide.BUY,
        quantity=10,
        order_type=OrderType.MARKET,
        price=None,
    )
    assert order.price is None
