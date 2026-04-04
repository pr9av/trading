/**
 * Fundamentals API — Blauplug Trading Platform
 * 
 * GET /v1/fundamentals/search?q=... → search stocks (DB + Zerodha instruments)
 * GET /v1/fundamentals/:symbol → stock fundamental data
 * GET /v1/fundamentals → list all
 * 
 * Search priority:
 *   1. Local `fundamentals` table (rich data: company name, sector, market cap)
 *   2. Local `price_candles` table (symbols we have historical data for)
 *   3. Zerodha NSE instruments list (full 2000+ NSE stocks)
 */

const express = require('express');
const router = express.Router();
const db = require('../db');
const Joi = require('joi');
const validate = require('../middleware/validate');

// ── Zerodha Instruments Cache ───────────────────────────────
const _instrumentsCache = {
  NSE: { data: null, time: 0 },
  BSE: { data: null, time: 0 },
  NFO: { data: null, time: 0 },
};
const INSTRUMENTS_TTL = 12 * 60 * 60 * 1000; // 12 hours

async function getZerodhaInstruments(exchange = 'NSE') {
    const cache = _instrumentsCache[exchange];
    if (cache && cache.data && (Date.now() - cache.time < INSTRUMENTS_TTL)) {
        return cache.data;
    }

    const apiKey = process.env.ZERODHA_API_KEY;
    const accessToken = process.env.ZERODHA_ACCESS_TOKEN;
    if (!apiKey || !accessToken || process.env.ACTIVE_BROKER !== 'zerodha') {
        return null;
    }

    try {
        const { KiteConnect } = require('kiteconnect');
        const kite = new KiteConnect({ api_key: apiKey });
        kite.setAccessToken(accessToken);
        
        console.log(`[Fundamentals] Fetching ${exchange} instruments from Zerodha...`);
        const instruments = await kite.getInstruments(exchange);
        
        let filtered;
        if (exchange === 'NFO') {
            // Derivatives: Futures and Options
            filtered = instruments.filter(i => i.segment === 'NFO-FUT' || i.segment === 'NFO-OPT');
        } else {
            // Equity: EQ or BE segment
            filtered = instruments.filter(i => i.instrument_type === 'EQ' || i.instrument_type === 'BE');
        }

        _instrumentsCache[exchange] = {
            data: filtered,
            time: Date.now()
        };
        console.log(`[Fundamentals] Cached ${filtered.length} ${exchange} instruments`);
        return filtered;
    } catch (err) {
        console.error(`[Fundamentals] Failed to fetch ${exchange} instruments:`, err.message);
        return null;
    }
}

// ── GET /fundamentals/search?q=...&exchange=NSE ──────────────
router.get('/search', validate({
  query: Joi.object({
    q: Joi.string().min(1).required(),
    exchange: Joi.string().valid('NSE', 'BSE', 'NFO').default('NSE'),
  })
}), async (req, res, next) => {
  try {
    const { q, exchange } = req.query;
    const qUpper = q.toUpperCase();

    // 1. Search local fundamentals table (NSE only for now)
    let rows = [];
    if (exchange === 'NSE') {
      const fundQuery = `
        SELECT symbol, company_name, sector, 'fundamentals' as source,
          CASE 
            WHEN symbol ILIKE $2 THEN 1
            WHEN company_name ILIKE $2 THEN 2
            ELSE 3
          END AS sort_order
        FROM fundamentals 
        WHERE symbol ILIKE $1 
           OR company_name ILIKE $1 
           OR sector ILIKE $1
        ORDER BY sort_order ASC, symbol ASC
        LIMIT 10
      `;
      const fundResult = await db.query(fundQuery, [`%${q}%`, `${q}%`]);
      rows = fundResult.rows;
    }
    
    const foundSymbols = new Set(rows.map(r => r.symbol));

    // 2. Search Zerodha instruments for target exchange
    if (rows.length < 10) {
      const instruments = await getZerodhaInstruments(exchange);
      if (instruments) {
        const matches = instruments
          .filter(i => 
            !foundSymbols.has(i.tradingsymbol) && (
              i.tradingsymbol.includes(qUpper) ||
              (i.name && i.name.toUpperCase().includes(qUpper))
            )
          )
          .slice(0, 10 - rows.length)
          .map(i => ({
            symbol: i.tradingsymbol,
            company_name: i.name || i.tradingsymbol,
            sector: i.segment || null,
            source: 'zerodha',
            sort_order: 5,
            instrument_token: i.instrument_token,
            exchange: exchange
          }));
        rows = [...rows, ...matches];
      }
    }

    // 4. Enrich with latest price from DB for all matched symbols
    const allSymbols = rows.map(r => r.symbol);
    if (allSymbols.length > 0) {
      try {
        const priceQuery = `
          SELECT DISTINCT ON (symbol) symbol, close as ltp, time as last_updated
          FROM price_candles
          WHERE symbol = ANY($1::text[])
          ORDER BY symbol, time DESC
        `;
        const priceResult = await db.query(priceQuery, [allSymbols]);
        const priceMap = {};
        for (const p of priceResult.rows) {
          priceMap[p.symbol] = { ltp: parseFloat(p.ltp), last_updated: p.last_updated };
        }
        rows = rows.map(r => ({
          ...r,
          ltp: priceMap[r.symbol]?.ltp || null,
          last_updated: priceMap[r.symbol]?.last_updated || null,
        }));
      } catch (e) {
        // Non-fatal: prices just won't be shown
      }
    }

    // 5. For results still without a price, fetch LTP live from Zerodha
    const missingPriceSymbols = rows.filter(r => r.ltp === null && r._is_fallback !== true).map(r => r.symbol);
    if (missingPriceSymbols.length > 0 && process.env.ACTIVE_BROKER === 'zerodha') {
      try {
        const apiKey = process.env.ZERODHA_API_KEY;
        const accessToken = process.env.ZERODHA_ACCESS_TOKEN;
        if (apiKey && accessToken) {
          const { KiteConnect } = require('kiteconnect');
          const kite = new KiteConnect({ api_key: apiKey });
          kite.setAccessToken(accessToken);

          // Kite getLTP accepts instruments like ["NSE:RELIANCE", "NSE:TCS"]
          const instruments = missingPriceSymbols.map(s => `NSE:${s}`);
          const ltpData = await kite.getLTP(instruments);

          // ltpData format: { "NSE:RELIANCE": { instrument_token, last_price }, ... }
          const ltpMap = {};
          for (const [key, val] of Object.entries(ltpData)) {
            const sym = key.replace('NSE:', '');
            ltpMap[sym] = val.last_price;
          }

          rows = rows.map(r => {
            if (r.ltp === null && ltpMap[r.symbol] !== undefined) {
              return { ...r, ltp: ltpMap[r.symbol], price_source: 'zerodha_live' };
            }
            return r;
          });
        }
      } catch (e) {
        console.warn('[Search] Zerodha LTP fetch failed:', e.message);
        // Non-fatal: results will just show without price
      }
    }

    res.json({ data: rows });
  } catch (err) {
    next(err);
  }
});

// ── GET /fundamentals/:symbol ───────────────────────────────
router.get('/:symbol', async (req, res, next) => {
  try {
    const { symbol } = req.params;
    const result = await db.query(
      'SELECT * FROM fundamentals WHERE symbol = $1',
      [symbol.toUpperCase()]
    );

    if (result.rows.length === 0) {
      // Try to find from Zerodha instruments as fallback
      const instruments = await getZerodhaInstruments();
      if (instruments) {
        const match = instruments.find(i => i.tradingsymbol === symbol.toUpperCase());
        if (match) {
          return res.json({
            data: {
              symbol: match.tradingsymbol,
              company_name: match.name || match.tradingsymbol,
              exchange: 'NSE',
              instrument_token: match.instrument_token,
              source: 'zerodha',
            }
          });
        }
      }

      return res.status(404).json({
        error: 'NOT_FOUND',
        message: `No data available for ${symbol}.`,
      });
    }

    res.json({ data: { ...result.rows[0], source: 'fundamentals' } });
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
