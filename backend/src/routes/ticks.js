const express = require('express');
const router = express.Router();
const db = require('../db');

// POST /ticks - Ingest tick from Kite websocket
router.post('/', async (req, res) => {
    // Body: { symbol, exchange, ltp, volume, bid, ask }
    const { symbol, exchange = 'NSE', ltp, volume = 0, bid = null, ask = null } = req.body;

    if (!symbol || ltp === undefined) {
        return res.status(400).json({ error: 'Missing required standard tick fields (symbol, ltp)' });
    }

    try {
        const query = `
            INSERT INTO price_ticks (time, symbol, exchange, ltp, volume, bid, ask)
            VALUES (now(), $1, $2, $3, $4, $5, $6)
        `;
        await db.query(query, [symbol, exchange, ltp, volume, bid, ask]);

        // Broadcast to WS clients
        const tickPayload = JSON.stringify({
            symbol, ltp, volume, change: 0, change_percent: 0 
        });
        if (req.wss) {
            req.wss.clients.forEach(client => {
                if (client.readyState === 1 /* WebSocket.OPEN */) {
                    client.send(tickPayload);
                }
            });
        }

        res.status(201).json({ success: true });
    } catch (err) {
        console.error('Error ingesting tick:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

module.exports = router;
