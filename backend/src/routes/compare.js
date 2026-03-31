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
          date_bin('1 day', time, '2000-01-01') AS date,
          (array_agg(ltp ORDER BY time DESC))[1] - (array_agg(ltp ORDER BY time ASC))[1] AS daily_pnl
        FROM price_ticks
        WHERE symbol = $1
        GROUP BY 1
        ORDER BY 1 DESC LIMIT 30
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
      FROM price_ticks
      WHERE symbol IN (${placeholders})
        AND time >= now() - interval '1 day'
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
      // Latest price
      const priceQuery = `
        SELECT ltp, time FROM price_ticks 
        WHERE symbol = $1 ORDER BY time DESC LIMIT 1
      `;
      const priceResult = await db.query(priceQuery, [symbol]);

      // 24h volume
      const volQuery = `
        SELECT COALESCE(sum(volume), 0) as volume_24h 
        FROM price_ticks 
        WHERE symbol = $1 AND time >= now() - interval '1 day'
      `;
      const volResult = await db.query(volQuery, [symbol]);

      // 24h high/low
      const hlQuery = `
        SELECT max(ltp) as high_24h, min(ltp) as low_24h 
        FROM price_ticks 
        WHERE symbol = $1 AND time >= now() - interval '1 day'
      `;
      const hlResult = await db.query(hlQuery, [symbol]);

      results[symbol] = {
        ltp: priceResult.rows[0]?.ltp || null,
        last_updated: priceResult.rows[0]?.time || null,
        volume_24h: volResult.rows[0]?.volume_24h || 0,
        high_24h: hlResult.rows[0]?.high_24h || null,
        low_24h: hlResult.rows[0]?.low_24h || null,
      };
    }

    res.json({ data: results });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
