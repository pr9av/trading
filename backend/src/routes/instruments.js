/**
 * Instruments API — Blauplug Trading Platform
 * 
 * Detailed instrument search and lookup using Zerodha's master list.
 * Supports NSE, BSE, NFO (Futures & Options).
 */

const express = require('express');
const router = express.Router();
const Joi = require('joi');
const validate = require('../middleware/validate');
const { AuthError } = require('../errors');

// Reuse the cache logic from fundamentals if possible, or just re-implement here for isolation
const _instrumentsCache = {
  NSE: { data: null, time: 0 },
  BSE: { data: null, time: 0 },
  NFO: { data: null, time: 0 },
};
const INSTRUMENTS_TTL = 12 * 60 * 60 * 1000;

async function getZerodhaInstruments(exchange = 'NSE') {
    const cache = _instrumentsCache[exchange];
    if (cache && cache.data && (Date.now() - cache.time < INSTRUMENTS_TTL)) {
        return cache.data;
    }

    const apiKey = process.env.ZERODHA_API_KEY;
    const accessToken = process.env.ZERODHA_ACCESS_TOKEN;
    if (!apiKey || !accessToken) return null;

    try {
        const { KiteConnect } = require('kiteconnect');
        const kite = new KiteConnect({ api_key: apiKey });
        kite.setAccessToken(accessToken);
        const instruments = await kite.getInstruments(exchange);
        
        _instrumentsCache[exchange] = { data: instruments, time: Date.now() };
        return instruments;
    } catch (err) {
        console.error(`[Instruments] Failed to fetch ${exchange}:`, err.message);
        return null;
    }
}

// ── GET /instruments/search ─────────────────────────────────
router.get('/search', validate({
    query: Joi.object({
        q: Joi.string().min(2).required(),
        exchange: Joi.string().valid('NSE', 'BSE', 'NFO').default('NSE'),
        segment: Joi.string().optional(), // e.g. NFO-FUT, NFO-OPT
    })
}), async (req, res, next) => {
    try {
        const { q, exchange, segment } = req.query;
        const qUpper = q.toUpperCase();
        
        const instruments = await getZerodhaInstruments(exchange);
        if (!instruments) {
            return res.status(503).json({ error: 'SERVICE_UNAVAILABLE', message: 'Zerodha instruments not available.' });
        }

        let matches = instruments.filter(i => {
            const symMatch = i.tradingsymbol && i.tradingsymbol.toUpperCase().includes(qUpper);
            const nameMatch = i.name && i.name.toUpperCase().includes(qUpper);
            return symMatch || nameMatch;
        });

        if (segment) {
            matches = matches.filter(i => i.segment === segment);
        }

        res.json({
            data: matches.slice(0, 50).map(i => ({
                symbol: i.tradingsymbol,
                name: i.name || i.tradingsymbol,
                exchange: i.exchange,
                segment: i.segment,
                instrument_token: i.instrument_token,
                last_price: i.last_price,
                expiry: i.expiry,
                strike: i.strike,
                tick_size: i.tick_size,
                lot_size: i.lot_size,
                instrument_type: i.instrument_type
            }))
        });
    } catch (err) {
        next(err);
    }
});

// ── GET /instruments/:token ─────────────────────────────────
router.get('/:token', async (req, res, next) => {
    try {
        const { token } = req.params;
        // Search across all cached segments
        for (const exch of ['NSE', 'BSE', 'NFO']) {
            const list = _instrumentsCache[exch].data;
            if (list) {
                const match = list.find(i => String(i.instrument_token) === String(token));
                if (match) return res.json({ data: match });
            }
        }
        res.status(404).json({ error: 'NOT_FOUND', message: 'Instrument token not found in cache.' });
    } catch (err) {
        next(err);
    }
});

module.exports = router;
