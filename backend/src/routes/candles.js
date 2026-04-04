const express = require('express');
const router = express.Router();
const db = require('../db');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { KiteConnect } = require('kiteconnect');
const { getMarketStatus } = require('../utils/marketHours');

// ── Schemas ─────────────────────────────────────────────────
const candleQuerySchema = {
  params: Joi.object({
    symbol: Joi.string().required(),
  }),
  query: Joi.object({
    interval: Joi.string().valid('1min', '5min', '30min', '60min', '1day', 'day').default('1min'),
    from: Joi.string().isoDate().optional(),
    to: Joi.string().isoDate().optional(),
  }),
};

// ── Kite Instruments Cache ──────────────────────────────────
let _instrumentsCache = null;
let _instrumentsCacheTime = 0;
const INSTRUMENTS_CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours

async function getInstrumentsCached(kite) {
    if (_instrumentsCache && (Date.now() - _instrumentsCacheTime < INSTRUMENTS_CACHE_TTL)) {
        return _instrumentsCache;
    }
    _instrumentsCache = await kite.getInstruments('NSE');
    _instrumentsCacheTime = Date.now();
    return _instrumentsCache;
}

// ── Kite Instance Helper ────────────────────────────────────
function getKiteClient() {
    const apiKey = process.env.ZERODHA_API_KEY;
    const accessToken = process.env.ZERODHA_ACCESS_TOKEN;
    if (!apiKey || !accessToken || process.env.ACTIVE_BROKER !== 'zerodha') return null;

    const kite = new KiteConnect({ api_key: apiKey });
    kite.setAccessToken(accessToken);
    return kite;
}

// ── Gap Detection ───────────────────────────────────────────
/**
 * Check if DB has sufficient data for the requested range.
 * Returns { hasData, coverage, gaps }
 */
async function checkDataCoverage(symbol, from, to) {
    const result = await db.query(
        `SELECT MIN(time) as earliest, MAX(time) as latest, COUNT(*) as count 
         FROM price_candles WHERE symbol = $1 AND time >= $2 AND time <= $3`,
        [symbol, from, to]
    );

    const row = result.rows[0];
    const count = parseInt(row.count) || 0;

    if (count === 0) {
        return { hasData: false, coverage: 0, gaps: [{ from, to }] };
    }

    const earliest = new Date(row.earliest);
    const latest = new Date(row.latest);
    const fromDate = new Date(from);
    const toDate = new Date(to);
    const gaps = [];

    // Gap at the beginning?
    if (earliest - fromDate > 2 * 60 * 60 * 1000) { // > 2 hours gap
        gaps.push({ from: fromDate, to: earliest });
    }
    // Gap at the end?
    if (toDate - latest > 2 * 60 * 60 * 1000) { // > 2 hours gap
        gaps.push({ from: latest, to: toDate });
    }

    const totalRange = toDate - fromDate;
    const coveredRange = latest - earliest;
    const coverage = totalRange > 0 ? Math.min(1, coveredRange / totalRange) : 1;

    return { hasData: count > 0, coverage, gaps, count };
}

// ── Hydration: Fetch from Zerodha & Store ───────────────────
async function hydrateRange(symbol, from, to) {
    const kite = getKiteClient();
    if (!kite) return 0;

    try {
        const instruments = await getInstrumentsCached(kite);
        const instrument = instruments.find(i => i.tradingsymbol === symbol.toUpperCase());
        if (!instrument) {
            console.warn(`[Hydration] Instrument not found for ${symbol}`);
            return 0;
        }

        const token = instrument.instrument_token.toString();
        let insertCount = 0;
        const fromDate = new Date(from);
        const toDate = new Date(to);

        // ALWAYS fetch day-level data first (most reliable, available for all stocks)
        try {
            const data = await kite.getHistoricalData(token, 'day', fromDate, toDate, false);
            if (data && data.length > 0) {
                insertCount += await _insertCandles(data, symbol);
                console.log(`[Hydration] Inserted ${data.length} day candles for ${symbol}`);
            }
        } catch (e) {
            console.warn(`[Hydration] Day fetch failed for ${symbol}:`, e.message);
        }

        // For narrow ranges (< 7 days), also fetch minute-level data for finer granularity
        const rangeMs = toDate - fromDate;
        const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
        if (rangeMs <= sevenDaysMs) {
            try {
                const data = await kite.getHistoricalData(token, 'minute', fromDate, toDate, false);
                if (data && data.length > 0) {
                    insertCount += await _insertCandles(data, symbol);
                    console.log(`[Hydration] Inserted ${data.length} minute candles for ${symbol}`);
                }
            } catch (e) {
                console.warn(`[Hydration] Minute fetch failed for ${symbol}:`, e.message);
            }
        }

        return insertCount;
    } catch (err) {
        console.error(`[Hydration] Failed for ${symbol}:`, err.message);
        return 0;
    }
}

async function _insertCandles(data, symbol) {
    let count = 0;
    for (const candle of data) {
        try {
            const result = await db.query(`
                INSERT INTO price_candles (time, symbol, exchange, open, high, low, close, volume)
                SELECT $1, $2, 'NSE', $3, $4, $5, $6, $7
                WHERE NOT EXISTS (
                    SELECT 1 FROM price_candles WHERE time = $1 AND symbol = $2
                )
            `, [candle.date, symbol, candle.open, candle.high, candle.low, candle.close, candle.volume]);
            if (result.rowCount > 0) count++;
        } catch (e) {
            // Skip duplicate/conflict errors silently
        }
    }
    return count;
}

// ── Routes ──────────────────────────────────────────────────

// GET /candles/:symbol
router.get('/:symbol', validate(candleQuerySchema), async (req, res, next) => {
  try {
    const symbol = req.params.symbol.toUpperCase();
    const { interval, from, to } = req.query;
    const marketStatus = getMarketStatus();

    // 1. Check if we have ANY data for this symbol at all
    const existsRes = await db.query('SELECT COUNT(*) as cnt FROM price_candles WHERE symbol = $1', [symbol]);
    const totalCount = parseInt(existsRes.rows[0].cnt) || 0;
    let source = 'database';

    if (totalCount === 0) {
        // FIRST TIME seeing this stock — do a broad synchronous hydration (30 days day-level)
        console.log(`[Candles] 🆕 First time stock ${symbol}. Hydrating 30 days of day-level data...`);
        const hydrateFrom = new Date();
        hydrateFrom.setDate(hydrateFrom.getDate() - 30);
        const inserted = await hydrateRange(symbol, hydrateFrom.toISOString(), new Date().toISOString());
        source = inserted > 0 ? 'zerodha' : 'database';
        console.log(`[Candles] Hydrated ${inserted} candles for ${symbol}`);
    } else if (from && to) {
        // We have some data — check coverage for the specific range
        const coverage = await checkDataCoverage(symbol, from, to);

        if (!coverage.hasData || coverage.coverage < 0.5) {
            console.log(`[Candles] Low coverage (${Math.round(coverage.coverage * 100)}%) for ${symbol}. Hydrating...`);
            const inserted = await hydrateRange(symbol, from, to);
            source = inserted > 0 ? 'zerodha' : 'database';
        } else if (coverage.gaps.length > 0) {
            for (const gap of coverage.gaps) {
                await hydrateRange(symbol, gap.from.toISOString(), gap.to.toISOString());
            }
            source = 'hybrid';
        }
    } else {
        // No range specified — staleness check
        const latestRes = await db.query('SELECT MAX(time) as last_time FROM price_candles WHERE symbol = $1', [symbol]);
        const lastTime = latestRes.rows[0].last_time;
        const isStale = !lastTime || (Date.now() - new Date(lastTime).getTime()) > 24 * 60 * 60 * 1000;

        if (isStale) {
            const defaultFrom = new Date();
            defaultFrom.setDate(defaultFrom.getDate() - 30);
            const inserted = await hydrateRange(symbol, defaultFrom.toISOString(), new Date().toISOString());
            source = inserted > 0 ? 'zerodha' : 'database';
        }
    }

    // 2. Query Builder
    const intervalMap = { '1min': '1 minute', '5min': '5 minutes', '30min': '30 minutes', '60min': '60 minutes', '1day': '1 day', 'day': '1 day' };
    const intervalStr = intervalMap[interval] || '1 minute';

    let query = `
      SELECT
        date_bin('${intervalStr}', time, '2000-01-01') AS time,
        (array_agg(open ORDER BY time ASC))[1] AS open,
        max(high) AS high,
        min(low) AS low,
        (array_agg(close ORDER BY time DESC))[1] AS close,
        COALESCE(sum(volume), 0) AS volume
      FROM price_candles
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

    query += ` GROUP BY 1 ORDER BY 1 DESC LIMIT 1500`;

    const result = await db.query(query, params);
    
    // Sort ascending for chart libraries
    const sortedData = result.rows.sort((a, b) => new Date(a.time) - new Date(b.time));
    
    res.json({
        data: sortedData,
        source,
        market_status: marketStatus,
        count: sortedData.length,
    });
  } catch (err) {
    next(err);
  }
});

// GET /candles/:symbol/sync — Force hydration from Zerodha
router.get('/:symbol/sync', async (req, res, next) => {
  try {
    const symbol = req.params.symbol.toUpperCase();
    const toDate = new Date();
    const fromDate = new Date();
    fromDate.setDate(toDate.getDate() - 180); // 6 months

    const inserted = await hydrateRange(symbol, fromDate.toISOString(), toDate.toISOString());
    res.json({
        message: `Synced ${symbol}: inserted ${inserted} new candles`,
        count: inserted,
        market_status: getMarketStatus(),
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
