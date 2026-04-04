const express = require('express');
const router = express.Router();
const db = require('../db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const Joi = require('joi');
const fs = require('fs');
const path = require('path');
let KiteConnect;
try {
  KiteConnect = require('kiteconnect').KiteConnect;
} catch (e) {
  console.warn("KiteConnect missing, zerodha routes may fail.");
}
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

router.get('/zerodha/login', (req, res) => {
    const apiKey = process.env.ZERODHA_API_KEY;
    if (!apiKey) return res.status(400).send("ZERODHA_API_KEY missing in .env");
    const loginUrl = `https://kite.zerodha.com/connect/login?v=3&api_key=${apiKey}`;
    res.redirect(loginUrl);
});

router.get('/zerodha/callback', async (req, res) => {
    const requestToken = req.query.request_token;
    if (!requestToken) return res.status(400).send("No request token provided");

    const apiKey = process.env.ZERODHA_API_KEY;
    const apiSecret = process.env.ZERODHA_API_SECRET;
    
    if (!KiteConnect) return res.status(500).send("KiteConnect module not installed. Run 'npm install kiteconnect'");

    try {
        const kite = new KiteConnect({ api_key: apiKey });
        const response = await kite.generateSession(requestToken, apiSecret);
        const accessToken = response.access_token;
        
        // 1. Update in-memory for the currently running server
        process.env.ZERODHA_ACCESS_TOKEN = accessToken;

        // 2. Update .env file permanently
        const envPath = path.join(__dirname, '../../.env');
        let envFile = fs.readFileSync(envPath, 'utf8');
        const regex = /^ZERODHA_ACCESS_TOKEN=.*$/m;
        
        if (regex.test(envFile)) {
            envFile = envFile.replace(regex, `ZERODHA_ACCESS_TOKEN=${accessToken}`);
        } else {
            envFile += `\nZERODHA_ACCESS_TOKEN=${accessToken}\n`;
        }
        fs.writeFileSync(envPath, envFile);

        res.send(`
            <html>
                <body style="font-family: sans-serif; padding: 40px; text-align: center; background: #111; color: #fff;">
                    <h1 style="color: #4CAF50;">✅ Zerodha Automation Successful!</h1>
                    <p style="font-size: 18px;">Your daily Access Token has been generated and saved to your .env file automatically.</p>
                    <p style="color: #888;">Your server already loaded the new token. You can close this window and return to your dashboard.</p>
                    <button onclick="window.close()" style="margin-top: 20px; padding: 12px 24px; font-size: 16px; cursor: pointer; background: #2196F3; color: white; border: none; border-radius: 4px;">Close Window</button>
                    <script>setTimeout(() => window.close(), 5000);</script>
                </body>
            </html>
        `);
    } catch (err) {
        res.status(500).send(`
            <html>
                <body style="background: #111; color: #fff; text-align: center; padding: 40px; font-family: sans-serif;">
                    <h2 style="color: #ff4d4d;">❌ Authentication Failed</h2>
                    <p>${err.message}</p>
                </body>
            </html>
        `);
    }
});

module.exports = router;
