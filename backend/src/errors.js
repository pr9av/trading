/**
 * Custom Error Classes — Blauplug Trading Platform
 * 
 * All API errors extend AppError. The global error handler in index.js
 * catches these and returns a consistent { error, code, message } shape.
 * No raw stack traces are ever sent to the client.
 */

class AppError extends Error {
  constructor(message, statusCode = 500, code = 'INTERNAL_ERROR') {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

class DatabaseError extends AppError {
  constructor(message = 'Database operation failed') {
    super(message, 503, 'DATABASE_ERROR');
  }
}

class AuthError extends AppError {
  constructor(message = 'Authentication failed', statusCode = 401) {
    super(message, statusCode, 'AUTH_ERROR');
  }
}

class ValidationError extends AppError {
  constructor(message = 'Validation failed', details = null) {
    super(message, 400, 'VALIDATION_ERROR');
    this.details = details;
  }
}

class NotFoundError extends AppError {
  constructor(message = 'Resource not found') {
    super(message, 404, 'NOT_FOUND');
  }
}

module.exports = {
  AppError,
  DatabaseError,
  AuthError,
  ValidationError,
  NotFoundError,
};
