/**
 * Background Job: Fetch OHLC Candles
 * 
 * Schedule: Every minute during NSE market hours (Mon-Fri 9:15-15:30 IST)
 * Post-Close: One final sweep at 15:35 IST to capture closing candle
 * 
 * Uses Zerodha Kite Historical API when ACTIVE_BROKER=zerodha.
 */

const cron = require('node-cron');
const db = require('../db');
const { isMarketOpen } = require('../utils/marketHours');

// ── Instrument Token Map ────────────────────────────────────
const INSTRUMENT_TOKENS = {
    'NSE:RELIANCE': '738561',
    'NSE:TCS': '2953217',
    'NSE:HDFCBANK': '341249',
    'NSE:INFY': '408065',
    'NSE:ICICIBANK': '1270529',
};

async function fetchAndStoreCandles() {
    if (process.env.ACTIVE_BROKER !== 'zerodha') return;

    const apiKey = process.env.ZERODHA_API_KEY;
    const accessToken = process.env.ZERODHA_ACCESS_TOKEN;
    if (!apiKey || !accessToken) {
        console.warn('[CRON] Missing Zerodha credentials. Skipping candle fetch.');
        return;
    }

    try {
        const { KiteConnect } = require('kiteconnect');
        const kite = new KiteConnect({ api_key: apiKey });
        kite.setAccessToken(accessToken);

        const now = new Date();
        const from = new Date(now.getTime() - 2 * 60 * 1000); // last 2 minutes

        for (const [instrument, token] of Object.entries(INSTRUMENT_TOKENS)) {
            try {
                const [exchange, tradingsymbol] = instrument.split(':');
                const data = await kite.getHistoricalData(
                    token,
                    'minute',
                    from,
                    now
                );
                if (!data || data.length === 0) continue;

                const candle = data[data.length - 1];
                await db.query(`
                    INSERT INTO price_candles (time, symbol, exchange, open, high, low, close, volume)
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                    ON CONFLICT DO NOTHING
                `, [candle.date, tradingsymbol, exchange,
                    candle.open, candle.high, candle.low, candle.close, candle.volume]);

                console.log(`[CRON] Inserted candle for ${tradingsymbol}`);
            } catch (err) {
                console.error(`[CRON] Failed for ${instrument}:`, err.message);
            }
        }
    } catch (err) {
        console.error('[CRON] Top-level error:', err.message);
    }
}

// ── Market Hours Cron: Every minute during market hours ─────
cron.schedule('* 9-15 * * 1-5', async () => {
    if (!isMarketOpen()) return; // Extra guard (handles 15:31+ on the 15th hour)
    await fetchAndStoreCandles();
});

// ── Post-Close Sweep: Run at 15:35 IST to capture closing candle ──
cron.schedule('35 15 * * 1-5', async () => {
    console.log('[CRON] Post-close sweep — capturing final candle...');
    await fetchAndStoreCandles();
}, {
    timezone: 'Asia/Kolkata',
});

console.log('[CRON] Candle fetch jobs registered (market hours + post-close sweep).');
