const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
require('dotenv').config();

const { AppError } = require('./errors');
const requireAuth = require('./middleware/auth');
const { apiLimiter, authLimiter } = require('./middleware/rateLimit');
const cacheMiddleware = require('./middleware/cache');

const app = express();
const PORT = process.env.API_GATEWAY_PORT || 8000;

// ── Core Middleware ─────────────────────────────────────────
app.use(cors());
app.use(express.json());
app.use(morgan('dev'));
app.use(apiLimiter); // Global rate limit: 100 req/min

// ── WebSocket Setup ─────────────────────────────────────────
const http = require('http');
const WebSocket = require('ws');

const server = http.createServer(app);
const wss = new WebSocket.Server({ server, path: '/ws/market' });

wss.on('connection', (ws) => {
    console.log('[WS] Client connected to market stream');
    ws.on('close', () => console.log('[WS] Client disconnected'));
});

app.use((req, res, next) => {
    req.wss = wss;
    next();
});

// ── Route Imports ───────────────────────────────────────────
const authRouter = require('./routes/auth');
const ticksRouter = require('./routes/ticks');
const candlesRouter = require('./routes/candles');
const analyticsRouter = require('./routes/analytics');
const compareRouter = require('./routes/compare');
const fundamentalsRouter = require('./routes/fundamentals');

// ── Health Check (public) ───────────────────────────────────
app.get('/health', (req, res) => res.json({ status: 'UP', version: 'v1', timestamp: new Date() }));

// ── V1 Routes ───────────────────────────────────────────────
// Public routes
app.use('/v1/auth', authLimiter, authRouter);
app.use('/v1/ticks', ticksRouter);

// Protected routes (JWT + cache on reads)
app.use('/v1/candles', requireAuth, cacheMiddleware(30), candlesRouter);
app.use('/v1/analytics', requireAuth, cacheMiddleware(60), analyticsRouter);
app.use('/v1/compare', requireAuth, cacheMiddleware(60), compareRouter);
app.use('/v1/fundamentals', requireAuth, cacheMiddleware(300), fundamentalsRouter);

// ── Global Error Handler ────────────────────────────────────
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
    if (err instanceof AppError) {
        return res.status(err.statusCode).json({
            error: err.code,
            message: err.message,
            ...(err.details ? { details: err.details } : {}),
        });
    }
    console.error('[UNHANDLED ERROR]', err);
    return res.status(500).json({
        error: 'INTERNAL_ERROR',
        message: 'An unexpected error occurred.',
    });
});

// ── Start Background Jobs ───────────────────────────────────
require('./jobs/fetchCandles');

// ── Start Server ────────────────────────────────────────────
server.listen(PORT, () => {
    console.log(`🚀 Blauplug V1 API (HTTP+WS) running on port ${PORT}`);
});
