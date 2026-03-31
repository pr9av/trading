const express = require('express');
const router = express.Router();
const db = require('../db');
const Joi = require('joi');
const validate = require('../middleware/validate');

// ── Schemas ─────────────────────────────────────────────────
const candleQuerySchema = {
  params: Joi.object({
    symbol: Joi.string().required(),
  }),
  query: Joi.object({
    interval: Joi.string().valid('1min', '5min', '1day').default('1min'),
    from: Joi.string().isoDate().optional(),
    to: Joi.string().isoDate().optional(),
  }),
};

// ── Routes ──────────────────────────────────────────────────

// GET /candles/:symbol
router.get('/:symbol', validate(candleQuerySchema), async (req, res, next) => {
  try {
    const { symbol } = req.params;
    const { interval, from, to } = req.query;

    const intervalMap = { '1min': '1 minute', '5min': '5 minutes', '1day': '1 day' };
    const intervalStr = intervalMap[interval] || '1 minute';

    let query = `
      SELECT
        date_bin('${intervalStr}', time, '2000-01-01') AS time,
        (array_agg(ltp ORDER BY time ASC))[1] AS open,
        max(ltp) AS high,
        min(ltp) AS low,
        (array_agg(ltp ORDER BY time DESC))[1] AS close,
        COALESCE(sum(volume), 0) AS volume
      FROM price_ticks
      WHERE symbol = $1
    `;
    const params = [symbol];

    if (from) {
      params.push(from);
      query += ` AND time >= $${params.length}`;
    }
    if (to) {
      params.push(to);
      query += ` AND time <= $${params.length}`;
    }

    query += ` GROUP BY 1 ORDER BY 1 DESC LIMIT 500`;

    const result = await db.query(query, params);
    res.json({ data: result.rows });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
