"""
OMS — Portfolio Service
========================
Manages portfolio retrieval, holdings, and P&L calculations.
"""

import logging
import os
import uuid
from typing import Optional

from sqlalchemy.orm import Session
from sqlalchemy import text
from models import PortfolioResponse, HoldingResponse

logger = logging.getLogger("order-management.portfolio_service")


class PortfolioService:
    """Service for managing user portfolios and holdings."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def get_portfolio(self, user_id: str) -> Optional[PortfolioResponse]:
        """Get user portfolio summary including cash balance and P&L."""
        try:
            result = self.db.execute(text("""
                SELECT 
                    p.id as portfolio_id,
                    p.user_id,
                    p.cash_balance,
                    p.total_pnl,
                    p.day_pnl,
                    p.last_synced_at,
                    COALESCE(SUM(ph.quantity * ph.current_price), 0) as holdings_value
                FROM portfolios p
                LEFT JOIN portfolio_holdings ph ON p.id = ph.portfolio_id
                WHERE p.user_id = :user_id
                GROUP BY p.id, p.user_id, p.cash_balance, p.total_pnl, p.day_pnl, p.last_synced_at
            """), {"user_id": user_id}).fetchone()

            if not result:
                # Create portfolio if it doesn't exist
                self.db.execute(text("""
                    INSERT INTO portfolios (user_id, cash_balance)
                    VALUES (:user_id, 100000.00)
                    RETURNING id, user_id, cash_balance, total_pnl, day_pnl, last_synced_at
                """), {"user_id": user_id})
                self.db.commit()
                
                result = self.db.execute(text("""
                    SELECT 
                        p.id as portfolio_id,
                        p.user_id,
                        p.cash_balance,
                        p.total_pnl,
                        p.day_pnl,
                        p.last_synced_at,
                        0 as holdings_value
                    FROM portfolios p
                    WHERE p.user_id = :user_id
                """), {"user_id": user_id}).fetchone()

            holdings_value = float(result.holdings_value or 0)
            cash_balance = float(result.cash_balance or 0)
            total_value = cash_balance + holdings_value

            return PortfolioResponse(
                portfolio_id=str(result.portfolio_id),
                user_id=str(result.user_id),
                cash_balance=round(cash_balance, 2),
                holdings_value=round(holdings_value, 2),
                total_value=round(total_value, 2),
                total_pnl=round(float(result.total_pnl or 0), 2),
                day_pnl=round(float(result.day_pnl or 0), 2),
                last_synced_at=str(result.last_synced_at) if result.last_synced_at else None,
            )
        except Exception as e:
            logger.error(f"Error fetching portfolio for user {user_id}: {e}")
            return None

    def get_holdings(self, user_id: str) -> list[HoldingResponse]:
        """Get all holdings for a user."""
        try:
            results = self.db.execute(text("""
                SELECT 
                    ph.id,
                    ph.symbol,
                    ph.exchange,
                    ph.quantity,
                    ph.avg_buy_price,
                    ph.current_price,
                    ph.pnl,
                    ph.updated_at
                FROM portfolio_holdings ph
                JOIN portfolios p ON ph.portfolio_id = p.id
                WHERE p.user_id = :user_id AND ph.quantity > 0
                ORDER BY ph.symbol
            """), {"user_id": user_id}).fetchall()

            holdings = []
            for row in results:
                holdings.append(HoldingResponse(
                    id=str(row.id),
                    symbol=row.symbol,
                    exchange=row.exchange,
                    quantity=row.quantity,
                    avg_buy_price=round(float(row.avg_buy_price), 2),
                    current_price=round(float(row.current_price or 0), 2),
                    pnl=round(float(row.pnl or 0), 2),
                    updated_at=str(row.updated_at) if row.updated_at else None,
                ))
            return holdings
        except Exception as e:
            logger.error(f"Error fetching holdings for user {user_id}: {e}")
            return []

    def update_holding_price(self, symbol: str, current_price: float) -> None:
        """Update current price for all holdings of a symbol."""
        try:
            self.db.execute(text("""
                UPDATE portfolio_holdings
                SET current_price = :price,
                    pnl = (current_price - avg_buy_price) * quantity,
                    updated_at = NOW()
                WHERE symbol = :symbol
            """), {"price": current_price, "symbol": symbol})
            self.db.commit()
        except Exception as e:
            logger.error(f"Error updating holding price for {symbol}: {e}")