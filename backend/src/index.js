const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
require('dotenv').config();

const app = express();
const PORT = process.env.API_GATEWAY_PORT || 8000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

const http = require('http');
const WebSocket = require('ws');

const server = http.createServer(app);
const wss = new WebSocket.Server({ server, path: '/ws/market' });

wss.on('connection', (ws) => {
    console.log('[WS] Client connected to market stream');
    ws.on('close', () => console.log('[WS] Client disconnected'));
});

// Expose wss to request object so routes (like /ticks) can broadcast
app.use((req, res, next) => {
    req.wss = wss;
    next();
});

// Routes
const authRouter = require('./routes/auth');
const ticksRouter = require('./routes/ticks');
const candlesRouter = require('./routes/candles');
const analyticsRouter = require('./routes/analytics');

app.use('/api/auth', authRouter);
app.use('/api/ticks', ticksRouter);
app.use('/api/candles', candlesRouter);
app.use('/api/analytics', analyticsRouter);

// Health check
app.get('/health', (req, res) => res.json({ status: 'UP', timestamp: new Date() }));

// Start background jobs
require('./jobs/fetchCandles');

server.listen(PORT, () => {
    console.log(`🚀 V2 Market Data API (HTTP+WS) running on port ${PORT}`);
});
