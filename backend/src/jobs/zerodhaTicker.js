/**
 * Zerodha KiteTicker — Market-Hours-Aware Live Data Ingestion
 * 
 * Connects to Zerodha WebSocket ONLY during market hours (9:15–15:30 IST).
 * On each tick: stores in DB, updates Redis cache, broadcasts via WS.
 * Auto-disconnects at market close, auto-reconnects at market open.
 */

const { KiteTicker } = require('kiteconnect');
const http = require('http');
require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });

const { isMarketOpen, onMarketEvent } = require('../utils/marketHours');
const { setTickCache, setSnapshotCache } = require('../redis');
const db = require('../db');

// Remove top-level caching of API_KEY and ACCESS_TOKEN to support dynamic refreshes
const API_PORT = process.env.API_GATEWAY_PORT || 8000;

// ── Instrument Token Map ────────────────────────────────────
// NSE instrument tokens for trending stocks
const TOKENS = {
    738561:  'RELIANCE',
    2953217: 'TCS',
    408065:  'INFY',
    341249:  'HDFCBANK',
    1270529: 'ICICIBANK',
};
const instrumentTokens = Object.keys(TOKENS).map(Number);

// ── State ───────────────────────────────────────────────────
let ticker = null;
let isConnected = false;
const latestTicks = {}; // In-memory snapshot for broadcasting

// ── Lifecycle ───────────────────────────────────────────────

function canStart() {
    if (!process.env.ZERODHA_API_KEY || !process.env.ZERODHA_ACCESS_TOKEN) {
        console.warn('[ZerodhaTicker] Missing ZERODHA_API_KEY or ZERODHA_ACCESS_TOKEN. Skipping.');
        return false;
    }
    return true;
}

function startTicker() {
    if (!canStart()) return;
    if (isConnected) {
        console.log('[ZerodhaTicker] Already connected. Skipping start.');
        return;
    }

    if (!isMarketOpen()) {
        console.log('[ZerodhaTicker] Market is closed. Ticker will auto-start at market open.');
        return;
    }

    console.log('[ZerodhaTicker] Starting KiteTicker...');

    ticker = new KiteTicker({
        api_key: process.env.ZERODHA_API_KEY,
        access_token: process.env.ZERODHA_ACCESS_TOKEN,
    });

    ticker.connect();

    ticker.on('connect', () => {
        isConnected = true;
        console.log('[ZerodhaTicker] ✅ Connected. Subscribing to', instrumentTokens.length, 'instruments.');
        ticker.subscribe(instrumentTokens);
        ticker.setMode(ticker.modeFull, instrumentTokens);
    });

    ticker.on('ticks', async (ticks) => {
        for (const tick of ticks) {
            const symbol = TOKENS[tick.instrument_token];
            if (!symbol) continue;

            const tickData = {
                symbol,
                exchange: 'NSE',
                ltp: tick.last_price,
                volume: tick.volume_traded || 0,
                bid: tick.depth?.buy?.[0]?.price || null,
                ask: tick.depth?.sell?.[0]?.price || null,
                open: tick.ohlc?.open || null,
                high: tick.ohlc?.high || null,
                low: tick.ohlc?.low || null,
                close: tick.ohlc?.close || null,
                timestamp: new Date().toISOString(),
            };

            // 1. Update Redis cache
            try {
                await setTickCache(symbol, tickData);
            } catch (e) {
                // Non-fatal: cache miss won't break anything
            }

            // 2. Store in-memory for snapshot
            latestTicks[symbol] = tickData;

            // 3. Forward to POST /v1/ticks (which stores in DB + broadcasts WS)
            const postData = JSON.stringify({
                symbol: tickData.symbol,
                exchange: tickData.exchange,
                ltp: tickData.ltp,
                volume: tickData.volume,
                bid: tickData.bid,
                ask: tickData.ask,
            });

            const options = {
                hostname: 'localhost',
                port: API_PORT,
                path: '/v1/ticks',
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(postData),
                },
            };

            const req = http.request(options, (res) => {
                if (res.statusCode !== 201) {
                    console.error(`[ZerodhaTicker] API ${res.statusCode} for ${symbol}`);
                }
            });
            req.on('error', (e) => {
                console.error(`[ZerodhaTicker] HTTP error: ${e.message}`);
            });
            req.write(postData);
            req.end();
        }

        // 4. Update full snapshot cache (all symbols at once)
        try {
            await setSnapshotCache(latestTicks);
        } catch (e) { /* non-fatal */ }
    });

    ticker.on('disconnect', () => {
        isConnected = false;
        console.log('[ZerodhaTicker] Disconnected.');
    });

    ticker.on('error', (err) => {
        console.error('[ZerodhaTicker] Error:', err.message || err);
    });
}

function stopTicker() {
    if (ticker && isConnected) {
        console.log('[ZerodhaTicker] ⛔ Stopping ticker (market closed).');
        try { ticker.disconnect(); } catch (e) { /* ignore */ }
        isConnected = false;
        ticker = null;
    }
}

// ── Auto Market-Hours Scheduling ────────────────────────────

function init() {
    if (!canStart()) return;

    // Start immediately if market is open
    if (isMarketOpen()) {
        startTicker();
    } else {
        console.log('[ZerodhaTicker] Market is closed. Waiting for market open...');
    }

    // Auto-start on market open
    onMarketEvent('open', () => {
        console.log('[ZerodhaTicker] 🔔 Market opened! Starting ticker...');
        startTicker();
    });

    // Auto-stop on market close
    onMarketEvent('close', () => {
        console.log('[ZerodhaTicker] 🔔 Market closed! Stopping ticker...');
        stopTicker();
    });
}

// ── Initialize ──────────────────────────────────────────────
init();

module.exports = { startTicker, stopTicker, isConnected: () => isConnected, latestTicks };
