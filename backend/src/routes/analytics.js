const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /analytics/pnl
router.get('/pnl', async (req, res) => {
    const { symbol } = req.query;
    try {
        // Mock analytics data query representing daily P&L trend
        const query = `
            SELECT 
                date_bin('1 day', time, '2000-01-01') AS date, 
                (array_agg(ltp ORDER BY time DESC))[1] - (array_agg(ltp ORDER BY time ASC))[1] AS daily_pnl 
            FROM price_ticks 
            WHERE symbol = $1 
            GROUP BY 1 
            ORDER BY 1 DESC LIMIT 30
        `;
        const result = await db.query(query, [symbol || 'RELIANCE']);
        res.json(result.rows);
    } catch (err) {
        console.error('Error fetching PNL analytics:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// GET /analytics/volume
router.get('/volume', async (req, res) => {
    try {
        const query = `
            SELECT symbol, COALESCE(sum(volume), 0) as total_volume 
            FROM price_ticks 
            WHERE time >= now() - interval '1 day' 
            GROUP BY symbol 
            ORDER BY total_volume DESC LIMIT 10
        `;
        const result = await db.query(query);
        res.json(result.rows);
    } catch (err) {
        console.error('Error fetching volume analytics:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// GET /analytics/behavior
router.get('/behavior', async (req, res) => {
    try {
        const query = `
            SELECT 
                COUNT(*) as total_trades,
                COALESCE(SUM(value), 0) as total_volume,
                COALESCE(SUM(brokerage + taxes), 0) as total_fees,
                COUNT(CASE WHEN side = 'BUY' THEN 1 END) as buys,
                COUNT(CASE WHEN side = 'SELL' THEN 1 END) as sells
            FROM trades
        `;
        const result = await db.query(query);
        res.json(result.rows[0]);
    } catch (err) {
        console.error('Error fetching behavior analytics:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// GET /analytics/distribution
router.get('/distribution', async (req, res) => {
    try {
        const query = `
            SELECT symbol, COALESCE(SUM(value), 0) as volume 
            FROM trades 
            GROUP BY symbol 
            ORDER BY volume DESC 
            LIMIT 5
        `;
        const result = await db.query(query);
        res.json(result.rows);
    } catch (err) {
        console.error('Error fetching asset distribution:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

module.exports = router;
