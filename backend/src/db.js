/**
 * Centralized Database Wrapper — Blauplug Trading Platform
 * 
 * All DB operations go through this module. Provides:
 * - Structured query execution with timing
 * - Automatic error wrapping with DatabaseError
 * - Transaction support via withTransaction()
 */

const { Pool } = require('pg');
const { DatabaseError } = require('./errors');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

pool.on('error', (err) => {
  console.error('[DB] Unexpected idle client error:', err.message);
  // Do NOT exit; log and continue — the pool will recover.
});

/**
 * Execute a SQL query with structured error handling and timing.
 * @param {string} text - SQL query text
 * @param {Array} params - Query parameters
 * @returns {{ rows, rowCount }} Query result
 */
async function dbQuery(text, params = []) {
  const start = Date.now();
  try {
    const result = await pool.query(text, params);
    const duration = Date.now() - start;
    if (duration > 500) {
      console.warn(`[DB] Slow query (${duration}ms): ${text.substring(0, 80)}...`);
    }
    return { rows: result.rows, rowCount: result.rowCount };
  } catch (err) {
    const duration = Date.now() - start;
    console.error(`[DB] Query failed (${duration}ms):`, err.message);
    throw new DatabaseError(`Query failed: ${err.message}`);
  }
}

/**
 * Execute multiple queries within a single transaction.
 * @param {Function} callback - async function receiving a client
 * @returns {*} Result of the callback
 */
async function withTransaction(callback) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback({
      query: (text, params) => client.query(text, params),
    });
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[DB] Transaction rolled back:', err.message);
    throw new DatabaseError(`Transaction failed: ${err.message}`);
  } finally {
    client.release();
  }
}

module.exports = {
  query: dbQuery,
  withTransaction,
  pool,
};
