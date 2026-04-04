/**
 * Market Status Route — Blauplug Trading Platform
 * 
 * Provides server-authoritative market state for the frontend.
 * The frontend should poll this on load to determine its display mode.
 */

const express = require('express');
const router = express.Router();
const { getMarketStatus } = require('../utils/marketHours');
const db = require('../db');

// GET /market/status - Returns current market mode and metadata
router.get('/status', async (req, res, next) => {
    try {
        const status = getMarketStatus();

        // Get timestamp of most recent data point
        let lastUpdated = null;
        try {
            const result = await db.query('SELECT MAX(time) as last_time FROM price_candles');
            lastUpdated = result.rows[0]?.last_time || null;
        } catch (e) {
            // Non-fatal: DB might not have data yet
        }

        res.json({
            ...status,
            last_updated: lastUpdated,
            broker: process.env.ACTIVE_BROKER || 'simulated',
        });
    } catch (err) {
        next(err);
    }
});

module.exports = router;
