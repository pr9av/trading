const express = require('express');
const router = express.Router();
const db = require('../db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { AuthError } = require('../errors');

const SECRET_KEY = process.env.SECRET_KEY || 'default-secret-key';

// ── Schemas ─────────────────────────────────────────────────
const registerSchema = {
  body: Joi.object({
    username: Joi.string().min(3).max(64).required(),
    email: Joi.string().email().required(),
    password: Joi.string().min(6).required(),
  }),
};

const loginSchema = {
  body: Joi.object({
    username: Joi.string().required(),
    password: Joi.string().required(),
  }),
};

// ── Routes ──────────────────────────────────────────────────
router.post('/register', validate(registerSchema), async (req, res, next) => {
  try {
    const { username, email, password } = req.body;
    const hashedPassword = await bcrypt.hash(password, 10);
    const result = await db.query(
      `INSERT INTO users (username, email, password_hash)
       VALUES ($1, $2, $3) RETURNING id, username, email`,
      [username, email, hashedPassword]
    );
    res.status(201).json({ data: result.rows[0] });
  } catch (err) {
    next(err);
  }
});

router.post('/login', validate(loginSchema), async (req, res, next) => {
  try {
    const { username, password } = req.body;
    const result = await db.query('SELECT * FROM users WHERE username = $1', [username]);
    const user = result.rows[0];

    if (!user || !(await bcrypt.compare(password, user.password_hash))) {
      throw new AuthError('Invalid credentials', 401);
    }

    const token = jwt.sign(
      { id: user.id, username: user.username, role: user.role },
      SECRET_KEY,
      { expiresIn: '24h' }
    );

    res.json({
      data: {
        access_token: token,
        token_type: 'bearer',
        username: user.username,
        user_id: user.id,
        role: user.role,
      },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
