/**
 * Simple In-Memory Cache Middleware — Blauplug Trading Platform
 * 
 * For MVP: memory-based TTL cache with no external dependency.
 * Can be upgraded to Redis later by swapping the store.
 */

const cache = new Map();

/**
 * Creates cache middleware with a given TTL (in seconds).
 * @param {number} ttlSeconds - Time to live for cached responses
 */
const cacheMiddleware = (ttlSeconds = 60) => (req, res, next) => {
  const key = req.originalUrl;
  const cached = cache.get(key);

  if (cached && Date.now() - cached.timestamp < ttlSeconds * 1000) {
    return res.json(cached.data);
  }

  // Monkey-patch res.json to capture the response
  const originalJson = res.json.bind(res);
  res.json = (data) => {
    cache.set(key, { data, timestamp: Date.now() });
    return originalJson(data);
  };

  next();
};

// Clear stale entries every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [key, value] of cache.entries()) {
    if (now - value.timestamp > 5 * 60 * 1000) {
      cache.delete(key);
    }
  }
}, 5 * 60 * 1000);

module.exports = cacheMiddleware;
