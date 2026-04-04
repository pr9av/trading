/**
 * User Journal API — Blauplug Trading Platform
 * 
 * Per-user trade journal entries (notes, sentiment, tags).
 * Senior: "We want to maintain the journal of the user."
 * 
 * POST /v1/journal        — Add a journal entry
 * GET  /v1/journal        — List journal entries (last 15 days default)
 * GET  /v1/journal/:id    — Single journal entry
 * DELETE /v1/journal/:id  — Delete a journal entry
 */

const express = require('express');
const router = express.Router();
const db = require('../db');
const Joi = require('joi');
const validate = require('../middleware/validate');

// ── Schemas ─────────────────────────────────────────────────
const createJournalSchema = {
  body: Joi.object({
    trade_id: Joi.string().uuid().allow(null).optional(),
    entry: Joi.string().min(1).max(5000).required(),
    tags: Joi.array().items(Joi.string().max(30)).max(10).default([]),
    sentiment: Joi.string().valid('bullish', 'bearish', 'neutral').allow(null).optional(),
  }),
};

const listJournalSchema = {
  query: Joi.object({
    days: Joi.number().integer().min(1).max(90).default(15),
    tag: Joi.string().max(30).optional(),
    sentiment: Joi.string().valid('bullish', 'bearish', 'neutral').optional(),
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(100).default(50),
  }),
};

// ── POST /journal — Add a journal entry ─────────────────────
router.post('/', validate(createJournalSchema), async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { trade_id, entry, tags, sentiment } = req.body;

    // If trade_id is provided, verify it belongs to this user
    if (trade_id) {
      const tradeCheck = await db.query(
        'SELECT id FROM user_trades WHERE id = $1 AND user_id = $2',
        [trade_id, userId]
      );
      if (tradeCheck.rows.length === 0) {
        return res.status(400).json({ error: 'VALIDATION_ERROR', message: 'Trade not found or does not belong to you.' });
      }
    }

    const result = await db.query(`
      INSERT INTO user_journal (user_id, trade_id, entry, tags, sentiment)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *
    `, [userId, trade_id || null, entry, tags, sentiment || null]);

    res.status(201).json({ data: result.rows[0] });
  } catch (err) {
    next(err);
  }
});

// ── GET /journal — List journal entries ─────────────────────
router.get('/', validate(listJournalSchema), async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { days, tag, sentiment, page, limit } = req.query;
    const offset = (page - 1) * limit;

    let query = `
      SELECT j.*, t.symbol, t.trade_type, t.quantity, t.price
      FROM user_journal j
      LEFT JOIN user_trades t ON j.trade_id = t.id
      WHERE j.user_id = $1
        AND j.created_at >= NOW() - INTERVAL '1 day' * $2
    `;
    const params = [userId, days];

    if (tag) {
      params.push(tag);
      query += ` AND $${params.length} = ANY(j.tags)`;
    }
    if (sentiment) {
      params.push(sentiment);
      query += ` AND j.sentiment = $${params.length}`;
    }

    // Count
    const countResult = await db.query(
      query.replace(/SELECT j\.\*.*FROM/, 'SELECT COUNT(*) as total FROM'),
      params
    );
    const total = parseInt(countResult.rows[0]?.total || 0);

    // Fetch page
    params.push(limit);
    query += ` ORDER BY j.created_at DESC LIMIT $${params.length}`;
    params.push(offset);
    query += ` OFFSET $${params.length}`;

    const result = await db.query(query, params);

    res.json({
      data: result.rows,
      pagination: { page, limit, total, total_pages: Math.ceil(total / limit) },
    });
  } catch (err) {
    next(err);
  }
});

// ── GET /journal/:id — Single entry ─────────────────────────
router.get('/:id', async (req, res, next) => {
  try {
    const userId = req.user.id;
    const result = await db.query(
      `SELECT j.*, t.symbol, t.trade_type, t.quantity, t.price
       FROM user_journal j
       LEFT JOIN user_trades t ON j.trade_id = t.id
       WHERE j.id = $1 AND j.user_id = $2`,
      [req.params.id, userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'NOT_FOUND', message: 'Journal entry not found.' });
    }

    res.json({ data: result.rows[0] });
  } catch (err) {
    next(err);
  }
});

// ── DELETE /journal/:id — Delete an entry ───────────────────
router.delete('/:id', async (req, res, next) => {
  try {
    const userId = req.user.id;
    const result = await db.query(
      'DELETE FROM user_journal WHERE id = $1 AND user_id = $2 RETURNING id',
      [req.params.id, userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'NOT_FOUND', message: 'Journal entry not found.' });
    }

    res.json({ data: { deleted: true, id: result.rows[0].id } });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
