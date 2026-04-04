const express = require('express');
const router = express.Router();
const db = require('../db');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { isMarketOpen, getMarketStatus } = require('../utils/marketHours');
const { getTickCache, getSnapshotCache, setTickCache } = require('../redis');

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

    // Store in database
    const query = `
      INSERT INTO price_ticks (time, symbol, exchange, ltp, volume, bid, ask)
      VALUES (now(), $1, $2, $3, $4, $5, $6)
    `;
    await db.query(query, [symbol, exchange, ltp, volume, bid, ask]);

    // Update Redis cache
    try {
      await setTickCache(symbol, {
        symbol, exchange, ltp, volume, bid, ask,
        timestamp: new Date().toISOString(),
      });
    } catch (e) { /* non-fatal */ }

    // Broadcast to WS clients
    const tickPayload = JSON.stringify({
      type: 'TICK',
      symbol, ltp, volume,
      change: 0, change_percent: 0,
      timestamp: new Date().toISOString(),
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

// GET /ticks/snapshot - Get latest price for all symbols
// Live mode: serve from Redis cache. Closed: query last known from DB.
router.get('/snapshot', async (req, res, next) => {
    try {
        const marketStatus = getMarketStatus();

        // During live hours, try Redis/memory cache first
        if (marketStatus.is_open) {
            const cached = await getSnapshotCache();
            if (cached && Object.keys(cached).length > 0) {
                const data = Object.values(cached).map(t => ({
                    symbol: t.symbol,
                    exchange: t.exchange || 'NSE',
                    ltp: t.ltp,
                    volume: t.volume,
                    time: t.timestamp || t.cached_at,
                }));
                return res.json({
                    data,
                    market_status: marketStatus,
                    source: 'live_cache',
                });
            }
        }

        // Fallback: query last known price from database
        const query = `
            SELECT DISTINCT ON (symbol) 
                symbol, exchange, close as ltp, volume, time
            FROM price_candles
            ORDER BY symbol, time DESC
        `;
        const result = await db.query(query);

        res.json({
            data: result.rows,
            market_status: marketStatus,
            source: marketStatus.is_open ? 'database_fallback' : 'historical',
        });
    } catch (err) {
        next(err);
    }
});

// GET /ticks/live/:symbol - Get live cached tick for a single symbol
router.get('/live/:symbol', async (req, res, next) => {
    try {
        const symbol = req.params.symbol.toUpperCase();
        const marketStatus = getMarketStatus();

        // Try Redis cache
        const cached = await getTickCache(symbol);
        if (cached) {
            return res.json({
                data: cached,
                market_status: marketStatus,
                source: 'live_cache',
            });
        }

        // Fallback to DB
        const query = `
            SELECT symbol, exchange, close as ltp, volume, time
            FROM price_candles
            WHERE symbol = $1
            ORDER BY time DESC
            LIMIT 1
        `;
        const result = await db.query(query, [symbol]);

        if (result.rows.length === 0) {
            return res.status(404).json({
                error: 'NOT_FOUND',
                message: `No price data for ${symbol}`,
                market_status: marketStatus,
            });
        }

        res.json({
            data: result.rows[0],
            market_status: marketStatus,
            source: 'historical',
        });
    } catch (err) {
        next(err);
    }
});

module.exports = router;
