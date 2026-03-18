"""
Test suite for Trade Execution Service
"""

import pytest
import uuid
from executor import TradeExecutor


@pytest.fixture
def executor():
    """Create a TradeExecutor instance."""
    return TradeExecutor()


@pytest.fixture
def sample_order_event():
    """Create a sample order event."""
    return {
        "order_id": str(uuid.uuid4()),
        "user_id": str(uuid.uuid4()),
        "symbol": "RELIANCE",
        "exchange": "NSE",
        "side": "BUY",
        "quantity": 10,
        "price": 2850.00,
    }


@pytest.mark.asyncio
async def test_execute_buy_order(executor, sample_order_event):
    """Test executing a buy order."""
    trade = await executor.execute(sample_order_event)
    
    assert trade is not None
    assert trade["side"] == "BUY"
    assert trade["symbol"] == "RELIANCE"
    assert trade["quantity"] == 10
    assert trade["price"] == 2850.00
    assert "trade_id" in trade
    assert "executed_at" in trade


@pytest.mark.asyncio
async def test_execute_sell_order(executor):
    """Test executing a sell order."""
    order_event = {
        "order_id": str(uuid.uuid4()),
        "user_id": str(uuid.uuid4()),
        "symbol": "TCS",
        "exchange": "NSE",
        "side": "SELL",
        "quantity": 5,
        "price": 3900.00,
    }
    
    trade = await executor.execute(order_event)
    
    assert trade is not None
    assert trade["side"] == "SELL"
    assert trade["symbol"] == "TCS"
    assert trade["quantity"] == 5


@pytest.mark.asyncio
async def test_brokerage_calculation_buy(executor):
    """Test brokerage calculation for buy order."""
    order_event = {
        "order_id": str(uuid.uuid4()),
        "user_id": str(uuid.uuid4()),
        "symbol": "RELIANCE",
        "exchange": "NSE",
        "side": "BUY",
        "quantity": 100,
        "price": 2850.00,
    }
    
    trade = await executor.execute(order_event)
    
    # For BUY: brokerage and taxes are added to cost
    expected_value = 2850.00 * 100
    expected_brokerage = round(expected_value * 0.0003, 4)
    
    assert trade["brokerage"] == expected_brokerage
    assert trade["taxes"] == 0.0  # No STT on buy


@pytest.mark.asyncio
async def test_tax_calculation_sell(executor):
    """Test tax calculation for sell order."""
    order_event = {
        "order_id": str(uuid.uuid4()),
        "user_id": str(uuid.uuid4()),
        "symbol": "RELIANCE",
        "exchange": "NSE",
        "side": "SELL",
        "quantity": 50,
        "price": 2900.00,
    }
    
    trade = await executor.execute(order_event)
    
    # For SELL: STT is charged
    expected_value = 2900.00 * 50
    expected_stt = round(expected_value * 0.001, 4)
    
    assert trade["taxes"] > 0  # Should include STT
    assert trade["side"] == "SELL"


@pytest.mark.asyncio
async def test_invalid_order_no_symbol(executor):
    """Test execution with missing symbol."""
    invalid_order = {
        "order_id": str(uuid.uuid4()),
        "user_id": str(uuid.uuid4()),
        "symbol": "",
        "quantity": 10,
        "price": 2850.00,
    }
    
    trade = await executor.execute(invalid_order)
    assert trade is None


@pytest.mark.asyncio
async def test_invalid_order_zero_quantity(executor):
    """Test execution with zero quantity."""
    invalid_order = {
        "order_id": str(uuid.uuid4()),
        "user_id": str(uuid.uuid4()),
        "symbol": "RELIANCE",
        "quantity": 0,
        "price": 2850.00,
    }
    
    trade = await executor.execute(invalid_order)
    assert trade is None
