/**
 * JWT Authentication Middleware — Blauplug Trading Platform
 * 
 * Applied globally to all routes except /v1/auth/*.
 * Verifies Bearer token and attaches user to req.user.
 */

const jwt = require('jsonwebtoken');
const { AuthError } = require('../errors');

const SECRET_KEY = process.env.SECRET_KEY || 'default-secret-key';

const requireAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new AuthError('No token provided. Please include a Bearer token.', 401);
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, SECRET_KEY);
    req.user = decoded;
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      throw new AuthError('Token has expired. Please log in again.', 401);
    }
    throw new AuthError('Invalid token.', 401);
  }
};

module.exports = requireAuth;
