const cron = require('node-cron');
const db = require('../db');

// ============================================================
//  BACKGROUND JOB: Fetch OHLC Candles
//  Schedule: Every minute during NSE market hours (Mon-Fri)
// ============================================================

// ⚠️  ZERODHA INTEGRATION — NOT YET ACTIVE
// Currently using the Python simulate.py to push ticks into the DB.
// When your Zerodha API key is ready, follow the steps below:
//
// STEP 1: Install KiteConnect
//   npm install kiteconnect
//
// STEP 2: Add these to your .env file:
//   ACTIVE_BROKER=zerodha
//   ZERODHA_API_KEY=your_api_key_here
//   ZERODHA_API_SECRET=your_api_secret_here
//   ZERODHA_ACCESS_TOKEN=daily_generated_token_here
//
// STEP 3: Uncomment the block below and delete the mock log line.
//
// STEP 4: Stop running simulate.py — live data replaces it.
// ============================================================

cron.schedule('* 9-15 * * 1-5', async () => {
    // TODO (Zerodha): Replace this log with the live integration block below.
    console.log('[CRON] Candle fetch job triggered. Awaiting Zerodha API key. (Using simulator data for now)');

    /* ── ZERODHA LIVE INTEGRATION ── Uncomment when STEP 1-4 above are done ──
    const { KiteConnect } = require('kiteconnect');
    const kite = new KiteConnect({ api_key: process.env.ZERODHA_API_KEY });
    kite.setAccessToken(process.env.ZERODHA_ACCESS_TOKEN);

    const symbols = ['NSE:RELIANCE', 'NSE:TCS', 'NSE:HDFCBANK', 'NSE:INFY', 'NSE:ICICIBANK'];
    const now = new Date();
    const from = new Date(now.getTime() - 2 * 60 * 1000); // last 2 minutes

    for (const instrument of symbols) {
        try {
            const [exchange, tradingsymbol] = instrument.split(':');
            const data = await kite.getHistoricalData(
                instrument,    // instrument_token (map via kite.getInstruments())
                from,
                now,
                'minute'
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
            console.error(`[CRON] Failed to fetch candle for ${instrument}:`, err.message);
        }
    }
    ── END ZERODHA LIVE INTEGRATION ── */
});
