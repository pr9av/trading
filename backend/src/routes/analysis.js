/**
 * User Trade Analysis API — Blauplug Trading Platform
 * 
 * Performance metrics based on user's recorded trades.
 * Senior: "Generate some analysis... for that particular account."
 */

const express = require('express');
const router = express.Router();
const db = require('../db');
const Joi = require('joi');
const validate = require('../middleware/validate');

// ── GET /analysis/stats ─────────────────────────────────────
// Overall performance stats
router.get('/stats', async (req, res, next) => {
    try {
        const userId = req.user.id;
        const result = await db.query(`
            WITH trade_pnl AS (
                SELECT 
                    symbol,
                    SUM(CASE WHEN trade_type = 'BUY' THEN -total_amount ELSE total_amount END) as realized_pnl
                FROM user_trades
                WHERE user_id = $1
                GROUP BY symbol
            )
            SELECT 
                COUNT(*) as total_trades,
                COALESCE(SUM(realized_pnl), 0) as total_profit_loss,
                COUNT(*) FILTER (WHERE realized_pnl > 0) as winning_trades,
                COUNT(*) FILTER (WHERE realized_pnl < 0) as losing_trades,
                COALESCE(AVG(realized_pnl), 0) as avg_profit_per_trade
            FROM trade_pnl
        `, [userId]);

        const stats = result.rows[0];
        const winRate = stats.total_trades > 0 
            ? (parseInt(stats.winning_trades) / parseInt(stats.total_trades)) * 100 
            : 0;

        res.json({
            data: {
                ...stats,
                win_rate: winRate.toFixed(2) + '%'
            }
        });
    } catch (err) {
        next(err);
    }
});

// ── GET /analysis/pnl ───────────────────────────────────────
// Cumulative P&L curve over time
router.get('/pnl', async (req, res, next) => {
    try {
        const userId = req.user.id;
        const { days = 30 } = req.query;

        const query = `
            SELECT 
                executed_at::date as date,
                SUM(CASE WHEN trade_type = 'BUY' THEN -total_amount ELSE total_amount END) as daily_pnl
            FROM user_trades
            WHERE user_id = $1
              AND executed_at >= NOW() - INTERVAL '1 day' * $2
            GROUP BY 1
            ORDER BY 1 ASC
        `;
        const result = await db.query(query, [userId, days]);

        // Calculate cumulative
        let cumulative = 0;
        const curve = result.rows.map(row => {
            cumulative += parseFloat(row.daily_pnl);
            return {
                date: row.date,
                pnl: row.daily_pnl,
                cumulative: cumulative
            };
        });

        res.json({ data: curve });
    } catch (err) {
        next(err);
    }
});

// ── GET /analysis/holdings ──────────────────────────────────
// Current open positions (Net quantity > 0)
router.get('/holdings', async (req, res, next) => {
    try {
        const userId = req.user.id;
        
        // 1. Get net positions from trades
        const result = await db.query(`
            SELECT 
                symbol,
                SUM(CASE WHEN trade_type = 'BUY' THEN quantity ELSE -quantity END) as net_quantity,
                SUM(CASE WHEN trade_type = 'BUY' THEN total_amount ELSE -total_amount END) / 
                   NULLIF(SUM(CASE WHEN trade_type = 'BUY' THEN quantity ELSE -quantity END), 0) as avg_price,
                SUM(CASE WHEN trade_type = 'BUY' THEN total_amount ELSE -total_amount END) as total_cost
            FROM user_trades
            WHERE user_id = $1
            GROUP BY symbol
            HAVING SUM(CASE WHEN trade_type = 'BUY' THEN quantity ELSE -quantity END) > 0
        `, [userId]);

        const holdings = result.rows;
        
        // 2. Fetch current prices for these holdings to calculate unrealized P&L
        if (holdings.length > 0) {
            const symbols = holdings.map(h => h.symbol);
            const priceQuery = `
                SELECT DISTINCT ON (symbol) symbol, close as ltp
                FROM price_candles
                WHERE symbol = ANY($1::text[])
                ORDER BY symbol, time DESC
            `;
            const priceResult = await db.query(priceQuery, [symbols]);
            const priceMap = {};
            priceResult.rows.forEach(r => priceMap[r.symbol] = parseFloat(r.ltp));

            holdings.forEach(h => {
                const ltp = priceMap[h.symbol] || 0;
                h.current_price = ltp;
                h.market_value = ltp * h.net_quantity;
                h.unrealized_pnl = h.market_value - h.total_cost;
                h.unrealized_pnl_percent = h.total_cost > 0 ? (h.unrealized_pnl / h.total_cost) * 100 : 0;
            });
        }

        res.json({ data: holdings });
    } catch (err) {
        next(err);
    }
});

module.exports = router;
