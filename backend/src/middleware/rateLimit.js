/**
 * Rate Limiting Middleware — Blauplug Trading Platform
 * 
 * In-memory rate limiter for MVP. Uses express-rate-limit.
 * 
 * DEV vs PROD:
 *  - In development (NODE_ENV !== 'production'), limits are relaxed so
 *    the Flutter hot-reload cycle and analytics providers don't get blocked.
 *  - In production, tighter limits apply.
 */

const rateLimit = require('express-rate-limit');

const isDev = process.env.NODE_ENV !== 'production';

// General API rate limiter
// Dev:  600 req/min  (Flutter rebuilds + multiple providers = high traffic locally)
// Prod: 100 req/min
const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: isDev ? 600 : 100,
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => {
    // Never rate-limit health checks
    return req.path === '/health';
  },
  message: {
    error: 'RATE_LIMITED',
    message: 'Too many requests. Please try again in a minute.',
  },
});

// Stricter limiter for auth routes
// Dev:  60 attempts/min  (prevents lockout during dev/testing)
// Prod: 10 attempts/min
const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: isDev ? 60 : 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'RATE_LIMITED',
    message: 'Too many login attempts. Please wait before trying again.',
  },
});

module.exports = { apiLimiter, authLimiter };
