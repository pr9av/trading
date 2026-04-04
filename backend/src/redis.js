/**
 * Redis Cache Layer — Blauplug Trading Platform
 * 
 * Uses REDIS_URL from .env (Upstash or local Redis).
 * Falls back to an in-memory Map if Redis is unavailable.
 * 
 * Primary use: caching latest tick prices during live market hours.
 */

require('dotenv').config();

let redisClient = null;
let useMemoryFallback = false;
const memoryCache = new Map();

// ── Initialize Redis ────────────────────────────────────────
async function initRedis() {
    const redisUrl = process.env.REDIS_URL;
    if (!redisUrl) {
        console.warn('[Redis] No REDIS_URL configured. Using in-memory fallback.');
        useMemoryFallback = true;
        return;
    }

    try {
        // Dynamic import to avoid crash if redis is not installed
        const { createClient } = require('redis');
        redisClient = createClient({ url: redisUrl });

        redisClient.on('error', (err) => {
            console.error('[Redis] Connection error:', err.message);
            if (!useMemoryFallback) {
                console.warn('[Redis] Switching to in-memory fallback.');
                useMemoryFallback = true;
            }
        });

        redisClient.on('connect', () => {
            console.log('[Redis] Connected successfully.');
            useMemoryFallback = false;
        });

        await redisClient.connect();
    } catch (err) {
        console.warn('[Redis] Failed to initialize:', err.message, '— using in-memory fallback.');
        useMemoryFallback = true;
    }
}

// ── Cache Operations ────────────────────────────────────────

/**
 * Set a cached value with TTL.
 * @param {string} key - Cache key
 * @param {*} value - Value to cache (will be JSON-serialized)
 * @param {number} ttlSeconds - Time to live in seconds (default: 60)
 */
async function setCache(key, value, ttlSeconds = 60) {
    const serialized = JSON.stringify(value);

    if (!useMemoryFallback && redisClient?.isOpen) {
        try {
            await redisClient.set(key, serialized, { EX: ttlSeconds });
            return;
        } catch (err) {
            console.error('[Redis] SET failed:', err.message);
        }
    }

    // In-memory fallback
    memoryCache.set(key, { data: serialized, expires: Date.now() + ttlSeconds * 1000 });
}

/**
 * Get a cached value.
 * @param {string} key - Cache key
 * @returns {*|null} Parsed value or null if not found/expired
 */
async function getCache(key) {
    if (!useMemoryFallback && redisClient?.isOpen) {
        try {
            const val = await redisClient.get(key);
            return val ? JSON.parse(val) : null;
        } catch (err) {
            console.error('[Redis] GET failed:', err.message);
        }
    }

    // In-memory fallback
    const entry = memoryCache.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expires) {
        memoryCache.delete(key);
        return null;
    }
    return JSON.parse(entry.data);
}

/**
 * Delete a cached key.
 * @param {string} key
 */
async function delCache(key) {
    if (!useMemoryFallback && redisClient?.isOpen) {
        try {
            await redisClient.del(key);
        } catch (err) {
            console.error('[Redis] DEL failed:', err.message);
        }
    }
    memoryCache.delete(key);
}

// ── Tick-Specific Helpers ───────────────────────────────────

/**
 * Cache the latest tick for a symbol.
 * @param {string} symbol
 * @param {object} tickData - { ltp, volume, bid, ask, timestamp }
 */
async function setTickCache(symbol, tickData) {
    await setCache(`tick:${symbol}`, { ...tickData, cached_at: new Date().toISOString() }, 120);
}

/**
 * Get the cached tick for a symbol.
 * @param {string} symbol
 * @returns {object|null}
 */
async function getTickCache(symbol) {
    return getCache(`tick:${symbol}`);
}

/**
 * Cache snapshot of all live ticks.
 * @param {object} snapshot - { RELIANCE: {...}, TCS: {...}, ... }
 */
async function setSnapshotCache(snapshot) {
    await setCache('market:snapshot', snapshot, 60);
}

/**
 * Get the cached market snapshot.
 * @returns {object|null}
 */
async function getSnapshotCache() {
    return getCache('market:snapshot');
}

// ── Cleanup in-memory stale entries every 2 minutes ─────────
setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of memoryCache.entries()) {
        if (now > entry.expires) memoryCache.delete(key);
    }
}, 2 * 60 * 1000);

module.exports = {
    initRedis,
    setCache,
    getCache,
    delCache,
    setTickCache,
    getTickCache,
    setSnapshotCache,
    getSnapshotCache,
};
