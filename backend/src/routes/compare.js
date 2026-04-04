/**
 * Company Comparison API — Blauplug Trading Platform
 * 
 * Allows comparing up to 10 companies side-by-side.
 * GET /v1/compare/pnl?symbols=RELIANCE,TCS,HDFCBANK
 * GET /v1/compare/volume?symbols=RELIANCE,TCS
 */

const express = require('express');
const router = express.Router();
const db = require('../db');
const Joi = require('joi');
const validate = require('../middleware/validate');

// ── Schemas ─────────────────────────────────────────────────
const compareSchema = {
  query: Joi.object({
    symbols: Joi.string().required().custom((value) => {
      const arr = value.split(',').map(s => s.trim()).filter(Boolean);
      if (arr.length === 0 || arr.length > 10) {
        throw new Error('Provide 1 to 10 comma-separated symbols');
      }
      return arr;
    }),
  }),
};

// ── GET /compare/pnl ────────────────────────────────────────
router.get('/pnl', validate(compareSchema), async (req, res, next) => {
  try {
    const symbols = req.query.symbols;
    const results = {};

    for (const symbol of symbols) {
      const query = `
          SELECT 
            time::date AS date,
            (array_agg(close ORDER BY time DESC))[1] - (array_agg(close ORDER BY time ASC))[1] AS daily_pnl
          FROM price_candles
          WHERE symbol = $1
            AND time >= now() - interval '30 days'
          GROUP BY 1
          ORDER BY 1 DESC
      `;
      const result = await db.query(query, [symbol]);
      results[symbol] = result.rows;
    }

    res.json({ data: results });
  } catch (err) {
    next(err);
  }
});

// ── GET /compare/volume ─────────────────────────────────────
router.get('/volume', validate(compareSchema), async (req, res, next) => {
  try {
    const symbols = req.query.symbols;
    const placeholders = symbols.map((_, i) => `$${i + 1}`).join(',');
    const query = `
      SELECT symbol, COALESCE(sum(volume), 0) as total_volume
      FROM price_candles
      WHERE symbol IN (${placeholders})
        AND time >= now() - interval '7 days'
      GROUP BY symbol
      ORDER BY total_volume DESC
    `;
    const result = await db.query(query, symbols);
    res.json({ data: result.rows });
  } catch (err) {
    next(err);
  }
});

// ── GET /compare/metrics ────────────────────────────────────
router.get('/metrics', validate(compareSchema), async (req, res, next) => {
  try {
    const symbols = req.query.symbols;
    const results = {};

    for (const symbol of symbols) {
      const query = `
        SELECT 
            (SELECT close FROM price_candles WHERE symbol = $1 ORDER BY time DESC LIMIT 1) as ltp,
            (SELECT max(high) FROM price_candles WHERE symbol = $1 AND time >= now() - interval '24 hours') as high_24h,
            (SELECT min(low) FROM price_candles WHERE symbol = $1 AND time >= now() - interval '24 hours') as low_24h,
            (SELECT sum(volume) FROM price_candles WHERE symbol = $1 AND time >= now() - interval '24 hours') as volume_24h,
            (SELECT time FROM price_candles WHERE symbol = $1 ORDER BY time DESC LIMIT 1) as last_updated
      `;
      const result = await db.query(query, [symbol]);
      results[symbol] = result.rows[0] || { ltp: 0, high_24h: 0, low_24h: 0, volume_24h: 0, last_updated: null };
    }

    res.json({ data: results });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
