/**
 * User Trades API — Blauplug Trading Platform
 * 
 * Per-user trade ledger. Every BUY/SELL is recorded here.
 * Senior: "Track all the trade for that particular account."
 * 
 * POST /v1/trades         — Record a new trade
 * GET  /v1/trades         — List user's trades (paginated, filterable)
 * GET  /v1/trades/summary — P&L summary, win rate, total invested
 * GET  /v1/trades/:id     — Single trade detail
 */

const express = require('express');
const router = express.Router();
const db = require('../db');
const Joi = require('joi');
const validate = require('../middleware/validate');

// ── Schemas ─────────────────────────────────────────────────
const createTradeSchema = {
  body: Joi.object({
    symbol: Joi.string().max(20).required(),
    exchange: Joi.string().max(10).default('NSE'),
    trade_type: Joi.string().valid('BUY', 'SELL').required(),
    quantity: Joi.number().integer().min(1).required(),
    price: Joi.number().positive().required(),
    order_type: Joi.string().valid('MARKET', 'LIMIT', 'SL', 'SL-M').default('MARKET'),
    notes: Joi.string().max(500).allow('', null).optional(),
    executed_at: Joi.string().isoDate().optional(),
  }),
};

const listTradesSchema = {
  query: Joi.object({
    symbol: Joi.string().max(20).optional(),
    trade_type: Joi.string().valid('BUY', 'SELL').optional(),
    from: Joi.string().isoDate().optional(),
    to: Joi.string().isoDate().optional(),
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(100).default(50),
  }),
};

// ── POST /trades — Record a new trade ───────────────────────
router.post('/', validate(createTradeSchema), async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { symbol, exchange, trade_type, quantity, price, order_type, notes, executed_at } = req.body;

    const totalAmount = quantity * price;
    const brokerage = totalAmount * 0.001; // 0.1% brokerage

    const result = await db.query(`
      INSERT INTO user_trades (user_id, symbol, exchange, trade_type, quantity, price, total_amount, brokerage, order_type, notes, executed_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, COALESCE($11, NOW()))
      RETURNING *
    `, [userId, symbol.toUpperCase(), exchange, trade_type, quantity, price, totalAmount, brokerage, order_type, notes || null, executed_at || null]);

    res.status(201).json({ data: result.rows[0] });
  } catch (err) {
    next(err);
  }
});

// ── GET /trades — List user's trades (paginated) ────────────
router.get('/', validate(listTradesSchema), async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { symbol, trade_type, from, to, page, limit } = req.query;
    const offset = (page - 1) * limit;

    let query = 'SELECT * FROM user_trades WHERE user_id = $1';
    const params = [userId];

    if (symbol) {
      params.push(symbol.toUpperCase());
      query += ` AND symbol = $${params.length}`;
    }
    if (trade_type) {
      params.push(trade_type);
      query += ` AND trade_type = $${params.length}`;
    }
    if (from) {
      params.push(from);
      query += ` AND executed_at >= $${params.length}`;
    }
    if (to) {
      params.push(to);
      query += ` AND executed_at <= $${params.length}`;
    }

    // Count total for pagination
    const countResult = await db.query(
      query.replace('SELECT *', 'SELECT COUNT(*) as total'),
      params
    );
    const total = parseInt(countResult.rows[0].total);

    // Fetch page
    params.push(limit);
    query += ` ORDER BY executed_at DESC LIMIT $${params.length}`;
    params.push(offset);
    query += ` OFFSET $${params.length}`;

    const result = await db.query(query, params);

    res.json({
      data: result.rows,
      pagination: {
        page,
        limit,
        total,
        total_pages: Math.ceil(total / limit),
      },
    });
  } catch (err) {
    next(err);
  }
});

// ── GET /trades/summary — P&L summary ───────────────────────
router.get('/summary', async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { from, to } = req.query;

    let dateFilter = '';
    const params = [userId];

    if (from) {
      params.push(from);
      dateFilter += ` AND executed_at >= $${params.length}`;
    }
    if (to) {
      params.push(to);
      dateFilter += ` AND executed_at <= $${params.length}`;
    }

    const result = await db.query(`
      SELECT
        COUNT(*) as total_trades,
        COUNT(*) FILTER (WHERE trade_type = 'BUY') as total_buys,
        COUNT(*) FILTER (WHERE trade_type = 'SELL') as total_sells,
        COALESCE(SUM(total_amount) FILTER (WHERE trade_type = 'BUY'), 0) as total_invested,
        COALESCE(SUM(total_amount) FILTER (WHERE trade_type = 'SELL'), 0) as total_returned,
        COALESCE(SUM(brokerage), 0) as total_brokerage,
        COUNT(DISTINCT symbol) as unique_symbols,
        MIN(executed_at) as first_trade,
        MAX(executed_at) as last_trade
      FROM user_trades
      WHERE user_id = $1 ${dateFilter}
    `, params);

    const row = result.rows[0];
    const totalInvested = parseFloat(row.total_invested);
    const totalReturned = parseFloat(row.total_returned);
    const realizedPnl = totalReturned - totalInvested;

    // Per-symbol P&L breakdown
    const symbolPnl = await db.query(`
      SELECT
        symbol,
        SUM(CASE WHEN trade_type = 'BUY' THEN quantity ELSE -quantity END) as net_quantity,
        SUM(CASE WHEN trade_type = 'BUY' THEN -total_amount ELSE total_amount END) as realized_pnl,
        COUNT(*) as trade_count
      FROM user_trades
      WHERE user_id = $1 ${dateFilter}
      GROUP BY symbol
      ORDER BY realized_pnl DESC
    `, params);

    res.json({
      data: {
        ...row,
        realized_pnl: realizedPnl,
        symbol_breakdown: symbolPnl.rows,
      },
    });
  } catch (err) {
    next(err);
  }
});

// ── GET /trades/:id — Single trade detail ───────────────────
router.get('/:id', async (req, res, next) => {
  try {
    const userId = req.user.id;
    const tradeId = req.params.id;

    const result = await db.query(
      'SELECT * FROM user_trades WHERE id = $1 AND user_id = $2',
      [tradeId, userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'NOT_FOUND', message: 'Trade not found.' });
    }

    // Also fetch any journal entries linked to this trade
    const journal = await db.query(
      'SELECT * FROM user_journal WHERE trade_id = $1 AND user_id = $2 ORDER BY created_at DESC',
      [tradeId, userId]
    );

    res.json({
      data: {
        ...result.rows[0],
        journal_entries: journal.rows,
      },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
