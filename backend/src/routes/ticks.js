const express = require('express');
const router = express.Router();
const db = require('../db');
const Joi = require('joi');
const validate = require('../middleware/validate');

// ── Schemas ─────────────────────────────────────────────────
const tickSchema = {
  body: Joi.object({
    symbol: Joi.string().required(),
    exchange: Joi.string().default('NSE'),
    ltp: Joi.number().required(),
    volume: Joi.number().default(0),
    bid: Joi.number().allow(null).default(null),
    ask: Joi.number().allow(null).default(null),
  }),
};

// ── Routes ──────────────────────────────────────────────────

// POST /ticks - Ingest tick from Kite websocket or simulator
router.post('/', validate(tickSchema), async (req, res, next) => {
  try {
    const { symbol, exchange, ltp, volume, bid, ask } = req.body;

    const query = `
      INSERT INTO price_ticks (time, symbol, exchange, ltp, volume, bid, ask)
      VALUES (now(), $1, $2, $3, $4, $5, $6)
    `;
    await db.query(query, [symbol, exchange, ltp, volume, bid, ask]);

    // Broadcast to WS clients
    const tickPayload = JSON.stringify({
      symbol, ltp, volume, change: 0, change_percent: 0,
    });
    if (req.wss) {
      req.wss.clients.forEach((client) => {
        if (client.readyState === 1 /* WebSocket.OPEN */) {
          client.send(tickPayload);
        }
      });
    }

    res.status(201).json({ data: { success: true } });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
