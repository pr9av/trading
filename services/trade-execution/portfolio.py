"""
Portfolio Manager
=================
Applies executed trades to portfolio holdings in Redis and PostgreSQL.
Handles position updates, P&L calculation, and cash balance changes.
"""

import logging
import os
import uuid
from datetime import datetime, timezone

import redis
import psycopg2
from psycopg2.extras import RealDictCursor

logger = logging.getLogger("trade-execution.portfolio")

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://blauplug:StrongPassword123!@postgres:5432/blauplug_trading"
)


class PortfolioManager:
    """Updates Redis portfolio cache and PostgreSQL after each trade execution."""

    def __init__(self) -> None:
        self._redis = redis.Redis(
            host=os.getenv("REDIS_HOST", "redis"),
            port=int(os.getenv("REDIS_PORT", 6379)),
            decode_responses=True,
        )

    def _get_db_connection(self):
        """Create a database connection."""
        return psycopg2.connect(DATABASE_URL)

    async def apply_trade(self, trade: dict) -> None:
        user_id  = trade["user_id"]
        symbol   = trade["symbol"]
        side     = trade["side"]
        quantity = int(trade["quantity"])
        price    = float(trade["price"])
        net_value = float(trade["net_value"])

        holding_key  = f"holding:{user_id}:{symbol}"
        cash_key     = f"cash:{user_id}"
        portfolio_key = f"portfolio:{user_id}"

        pipe = self._redis.pipeline()

        # ── Update cash balance ───────────────────────────────────────────────
        if side == "BUY":
            pipe.incrbyfloat(cash_key, -net_value)   # Debit
        else:
            pipe.incrbyfloat(cash_key, net_value)    # Credit

        # ── Update holdings ───────────────────────────────────────────────────
        existing_qty   = self._redis.hget(holding_key, "quantity")
        existing_avg   = self._redis.hget(holding_key, "avg_buy_price")
        curr_qty       = int(existing_qty or 0)
        curr_avg       = float(existing_avg or 0.0)

        if side == "BUY":
            new_qty = curr_qty + quantity
            new_avg = ((curr_avg * curr_qty) + (price * quantity)) / new_qty if new_qty else 0.0
            pipe.hset(holding_key, mapping={
                "quantity":      new_qty,
                "avg_buy_price": round(new_avg, 4),
                "symbol":        symbol,
                "user_id":       user_id,
            })
        else:
            new_qty = max(curr_qty - quantity, 0)
            pipe.hset(holding_key, mapping={
                "quantity":      new_qty,
                "avg_buy_price": curr_avg,
                "symbol":        symbol,
                "user_id":       user_id,
            })

        # ── Cache current LTP ─────────────────────────────────────────────────
        pipe.set(f"ltp:{symbol}", str(price), ex=60)

        # ── Update portfolio last activity ────────────────────────────────────
        pipe.hset(portfolio_key, "last_trade_at", trade["executed_at"])

        pipe.execute()
        logger.info("Portfolio updated (Redis): user=%s | %s %s x%d @ %.2f | new_qty=%d",
                    user_id, side, symbol, quantity, price, new_qty)

        # ── Persist to PostgreSQL ─────────────────────────────────────────────
        await self._persist_to_postgres(trade, new_qty, new_avg if side == "BUY" else curr_avg)

    async def _persist_to_postgres(self, trade: dict, new_qty: int, avg_price: float) -> None:
        """Persist portfolio changes to PostgreSQL."""
        try:
            conn = self._get_db_connection()
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            
            user_id = trade["user_id"]
            symbol = trade["symbol"]
            side = trade["side"]
            quantity = int(trade["quantity"])
            price = float(trade["price"])
            net_value = float(trade["net_value"])
            
            # Get or create portfolio
            cursor.execute("SELECT id FROM portfolios WHERE user_id = %s", (user_id,))
            portfolio = cursor.fetchone()
            
            if not portfolio:
                # Create portfolio if it doesn't exist
                cursor.execute("""
                    INSERT INTO portfolios (user_id, cash_balance)
                    VALUES (%s, %s)
                    RETURNING id
                """, (user_id, 100000.00))
                portfolio = cursor.fetchone()
            
            portfolio_id = portfolio["id"]
            
            # Update cash balance
            cash_change = -net_value if side == "BUY" else net_value
            cursor.execute("""
                UPDATE portfolios
                SET cash_balance = cash_balance + %s,
                    updated_at = NOW()
                WHERE id = %s
            """, (cash_change, portfolio_id))
            
            # Update or insert holding
            cursor.execute("""
                INSERT INTO portfolio_holdings (portfolio_id, symbol, exchange, quantity, avg_buy_price, current_price, pnl)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (portfolio_id, symbol, exchange)
                DO UPDATE SET
                    quantity = portfolio_holdings.quantity + %s,
                    avg_buy_price = CASE 
                        WHEN portfolio_holdings.quantity + %s > 0 
                        THEN (portfolio_holdings.avg_buy_price * portfolio_holdings.quantity + %s) / NULLIF(portfolio_holdings.quantity + %s, 0)
                        ELSE portfolio_holdings.avg_buy_price
                    END,
                    current_price = %s,
                    pnl = (portfolio_holdings.current_price - portfolio_holdings.avg_buy_price) * portfolio_holdings.quantity,
                    updated_at = NOW()
            """, (
                portfolio_id, symbol, "NSE", quantity if side == "BUY" else -quantity, 
                avg_price, price, 0,
                quantity if side == "BUY" else -quantity,
                quantity if side == "BUY" else -quantity,
                price * quantity,
                quantity if side == "BUY" else -quantity,
                price
            ))
            
            # Record trade in trades table
            cursor.execute("""
                INSERT INTO trades (id, order_id, user_id, symbol, exchange, side, quantity, price, value, brokerage, taxes, net_value, executed_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                str(uuid.uuid4()),
                trade.get("order_id"),
                user_id,
                symbol,
                trade.get("exchange", "NSE"),
                side,
                quantity,
                price,
                float(trade.get("value", price * quantity)),
                float(trade.get("brokerage", 0)),
                float(trade.get("taxes", 0)),
                net_value,
                datetime.now(tz=timezone.utc)
            ))
            
            conn.commit()
            cursor.close()
            conn.close()
            
            logger.info("Portfolio persisted to PostgreSQL: user=%s | %s %s x%d", 
                       user_id, side, symbol, quantity)
            
        except Exception as e:
            logger.error(f"Error persisting portfolio to PostgreSQL: {e}")
            # Don't raise - Redis update already succeeded
