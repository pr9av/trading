const express = require('express');
const router = express.Router();
const db = require('../db');
const Joi = require('joi');
const validate = require('../middleware/validate');

// ── Schemas ─────────────────────────────────────────────────
const pnlQuerySchema = {
  query: Joi.object({
    symbol: Joi.string().default('RELIANCE'),
  }),
};

const sectorQuerySchema = {
  query: Joi.object({
    sector: Joi.string().max(64).optional(),
  }),
};

// ── Routes ──────────────────────────────────────────────────

// GET /analytics/pnl
router.get('/pnl', validate(pnlQuerySchema), async (req, res, next) => {
    try {
        const { symbol } = req.query;
        const query = `
            SELECT 
                date_bin('1 day', time, '2000-01-01') AS date, 
                (array_agg(ltp ORDER BY time DESC))[1] - (array_agg(ltp ORDER BY time ASC))[1] AS daily_pnl 
            FROM price_ticks 
            WHERE symbol = $1 
            GROUP BY 1 
            ORDER BY 1 DESC LIMIT 30
        `;
        const result = await db.query(query, [symbol]);
        res.json({ data: result.rows });
    } catch (err) {
        next(err);
    }
});

// GET /analytics/volume?sector=Finance
router.get('/volume', validate(sectorQuerySchema), async (req, res, next) => {
    try {
        const { sector } = req.query;
        let query, params;
        if (sector) {
            query = `
                SELECT pt.symbol, COALESCE(sum(pt.volume), 0) as total_volume
                FROM price_ticks pt
                INNER JOIN fundamentals f ON f.symbol = pt.symbol
                WHERE pt.time >= now() - interval '1 day'
                  AND LOWER(f.sector) = LOWER($1)
                GROUP BY pt.symbol
                ORDER BY total_volume DESC LIMIT 10
            `;
            params = [sector];
        } else {
            query = `
                SELECT symbol, COALESCE(sum(volume), 0) as total_volume
                FROM price_ticks
                WHERE time >= now() - interval '1 day'
                GROUP BY symbol
                ORDER BY total_volume DESC LIMIT 10
            `;
            params = [];
        }
        const result = await db.query(query, params);
        res.json({ data: result.rows });
    } catch (err) {
        next(err);
    }
});

// GET /analytics/behavior
router.get('/behavior', async (req, res, next) => {
    try {
        const query = `
            SELECT 
                COUNT(*) as total_trades,
                COALESCE(SUM(value), 0) as total_volume,
                COALESCE(SUM(brokerage + taxes), 0) as total_fees,
                COUNT(CASE WHEN side = 'BUY' THEN 1 END) as buys,
                COUNT(CASE WHEN side = 'SELL' THEN 1 END) as sells
            FROM trades
        `;
        const result = await db.query(query);
        res.json({ data: result.rows[0] });
    } catch (err) {
        next(err);
    }
});

// GET /analytics/distribution?sector=Finance
router.get('/distribution', validate(sectorQuerySchema), async (req, res, next) => {
    try {
        const { sector } = req.query;
        let query, params;
        if (sector) {
            query = `
                SELECT t.symbol, COALESCE(SUM(t.value), 0) as volume
                FROM trades t
                INNER JOIN fundamentals f ON f.symbol = t.symbol
                WHERE LOWER(f.sector) = LOWER($1)
                GROUP BY t.symbol
                ORDER BY volume DESC LIMIT 5
            `;
            params = [sector];
        } else {
            query = `
                SELECT symbol, COALESCE(SUM(value), 0) as volume
                FROM trades
                GROUP BY symbol
                ORDER BY volume DESC LIMIT 5
            `;
            params = [];
        }
        const result = await db.query(query, params);
        res.json({ data: result.rows });
    } catch (err) {
        next(err);
    }
});

module.exports = router;
