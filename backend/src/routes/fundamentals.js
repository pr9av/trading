/**
 * Fundamentals API — Blauplug Trading Platform
 * 
 * GET /v1/fundamentals/:symbol → stock fundamental data (P/E, P/B, Revenue, etc.)
 * 
 * Data source: Currently seeded manually or from NSE/Alpha Vantage.
 * Refreshed daily by a cron job (to be added).
 */

const express = require('express');
const router = express.Router();
const db = require('../db');

// ── GET /fundamentals/:symbol ───────────────────────────────
router.get('/:symbol', async (req, res, next) => {
  try {
    const { symbol } = req.params;
    const result = await db.query(
      'SELECT * FROM fundamentals WHERE symbol = $1',
      [symbol.toUpperCase()]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'NOT_FOUND',
        message: `No fundamental data available for ${symbol}. Data may not be populated yet.`,
      });
    }

    res.json({ data: result.rows[0] });
  } catch (err) {
    next(err);
  }
});

// ── GET /fundamentals ─ List all available fundamentals ─────
router.get('/', async (req, res, next) => {
  try {
    const { sector } = req.query;
    let query = 'SELECT * FROM fundamentals';
    const params = [];

    if (sector) {
      params.push(sector);
      query += ' WHERE sector = $1';
    }

    query += ' ORDER BY symbol ASC';
    const result = await db.query(query, params);
    res.json({ data: result.rows });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
