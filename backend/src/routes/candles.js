const express = require('express');
const router = express.Router();
const db = require('../db');

router.get('/:symbol', async (req, res) => {
    const { symbol } = req.params;
    const { interval = '1min', from, to } = req.query;

    try {
        let intervalStr = '1 minute';
        if (interval === '5min') intervalStr = '5 minutes';
        if (interval === '1day') intervalStr = '1 day';

        let query = `
            SELECT 
                date_bin('${intervalStr}', time, '2000-01-01') AS time,
                (array_agg(ltp ORDER BY time ASC))[1] AS open,
                max(ltp) AS high,
                min(ltp) AS low,
                (array_agg(ltp ORDER BY time DESC))[1] AS close,
                COALESCE(sum(volume), 0) AS volume
            FROM price_ticks
            WHERE symbol = $1
        `;
        let params = [symbol];

        if (from) {
            params.push(from);
            query += ` AND time >= $${params.length}`;
        }
        if (to) {
            params.push(to);
            query += ` AND time <= $${params.length}`;
        }

        query += ` GROUP BY 1 ORDER BY 1 DESC LIMIT 500`;

        const result = await db.query(query, params);
        res.json(result.rows);
    } catch (err) {
        console.error('Error fetching candles:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

module.exports = router;
