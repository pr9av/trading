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
// Shows the trend of closing prices over time
router.get('/pnl', validate(pnlQuerySchema), async (req, res, next) => {
    try {
        const symbol = req.query.symbol.toUpperCase();
        const query = `
            SELECT 
                time::date AS date, 
                (array_agg(close ORDER BY time DESC))[1] AS daily_pnl 
            FROM price_candles 
            WHERE symbol = $1 
            GROUP BY 1 
            ORDER BY 1 ASC LIMIT 30
        `;
        const result = await db.query(query, [symbol]);
        res.json({ data: result.rows });
    } catch (err) {
        next(err);
    }
});

// GET /analytics/volume?sector=Finance
// Shows volume distribution from current/historical candles
router.get('/volume', validate(sectorQuerySchema), async (req, res, next) => {
    try {
        const { sector } = req.query;
        let query, params;
        if (sector) {
            query = `
                SELECT pc.symbol, COALESCE(sum(pc.volume), 0) as total_volume
                FROM price_candles pc
                INNER JOIN fundamentals f ON f.symbol = pc.symbol
                WHERE pc.time >= now() - interval '7 days'
                  AND LOWER(f.sector) = LOWER($1)
                GROUP BY pc.symbol
                ORDER BY total_volume DESC LIMIT 10
            `;
            params = [sector];
        } else {
            query = `
                SELECT symbol, COALESCE(sum(volume), 0) as total_volume
                FROM price_candles
                WHERE time >= now() - interval '7 days'
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
// Now summarizes backend health/stats since trades are live-only
router.get('/behavior', async (req, res, next) => {
    try {
        const query = `
            SELECT 
                (SELECT count(*) FROM price_candles) as total_data_points,
                (SELECT count(*) FROM fundamentals) as symbols_tracked,
                (SELECT count(*) FROM users) as active_users
        `;
        const result = await db.query(query);
        res.json({ data: {
            ...result.rows[0],
            status: 'LIVE_ZERODHA_SYNC',
            uptime: Math.floor(process.uptime())
        }});
    } catch (err) {
        next(err);
    }
});

// GET /analytics/distribution
// Professional view: Portfolio / Sector distribution based on tracked caps
router.get('/distribution', validate(sectorQuerySchema), async (req, res, next) => {
    try {
        const { sector } = req.query;
        let query, params;
        if (sector) {
            query = `
                SELECT symbol, market_cap as volume
                FROM fundamentals
                WHERE LOWER(sector) = LOWER($1)
                ORDER BY market_cap DESC LIMIT 5
            `;
            params = [sector];
        } else {
            query = `
                SELECT sector as symbol, SUM(market_cap) as volume
                FROM fundamentals
                GROUP BY sector
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

// GET /analytics/distribution
// Professional view: Portfolio / Sector distribution based on tracked caps
router.get('/distribution', validate(sectorQuerySchema), async (req, res, next) => {
    try {
        const { sector } = req.query;
        let query, params;
        if (sector) {
            query = `
                SELECT symbol, market_cap as volume
                FROM fundamentals
                WHERE LOWER(sector) = LOWER($1)
                ORDER BY market_cap DESC LIMIT 5
            `;
            params = [sector];
        } else {
            query = `
                SELECT sector as symbol, SUM(market_cap) as volume
                FROM fundamentals
                GROUP BY sector
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

// GET /analytics/trending
// Fetches the top 5 tracked symbols with their basic stats
router.get('/trending', async (req, res, next) => {
    try {
        const query = `
            SELECT 
                f.symbol, f.company_name, f.sector,
                (SELECT close FROM price_candles WHERE symbol = f.symbol ORDER BY time DESC LIMIT 1) as ltp,
                (SELECT (close - open)/open * 100 FROM price_candles WHERE symbol = f.symbol ORDER BY time DESC LIMIT 1) as change_percent
            FROM fundamentals f
            WHERE f.symbol IN ('RELIANCE', 'TCS', 'INFY', 'HDFCBANK', 'ICICIBANK')
            ORDER BY change_percent DESC
        `;
        const result = await db.query(query);
        res.json({ data: result.rows });
    } catch (err) {
        next(err);
    }
});

module.exports = router;
