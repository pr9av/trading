const express = require('express');
const router = express.Router();
const { GoogleGenerativeAI } = require('@google/generative-ai');
const Joi = require('joi');
const validate = require('../middleware/validate');
const db = require('../db');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');
// Based on the verified model list, use gemini-1.5-flash for performance and cost
const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });

// In-memory cache for stock analysis (TTL: 10 mins)
const analysisCache = new Map();
const CACHE_TTL = 10 * 60 * 1000;

// ── Schemas ─────────────────────────────────────────────────
const chatSchema = {
    body: Joi.object({
        message: Joi.string().required(),
        history: Joi.array().items(Joi.object({
            role: Joi.string().valid('user', 'model').required(),
            parts: Joi.array().items(Joi.object({
                text: Joi.string().required()
            })).required()
        })).optional()
    })
};

const analyzeSchema = {
  body: Joi.object({
    symbol: Joi.string().required(),
    price: Joi.number().allow(null).default(0),
    trend: Joi.string().optional()
  }),
};

// ── Routes ──────────────────────────────────────────────────

// POST /ai/chat
router.post('/chat', validate(chatSchema), async (req, res, next) => {
    try {
        if (!process.env.GEMINI_API_KEY) {
            return res.json({ message: "Gemini API Key missing in backend .env. Please add GEMINI_API_KEY to enable AI chat." });
        }

        const { message, history } = req.body;
        const chat = model.startChat({ history: history || [] });
        const result = await chat.sendMessage(message);
        const response = await result.response;
        res.json({ message: response.text() });
    } catch (err) {
        if (err.status === 429) {
            console.error(`[AI CHAT] Rate Limit Exceeded (429)`);
            return res.status(429).json({ message: "AI chat is currently unavailable (API Quota Exceeded). Please try again later." });
        }
        console.error('[AI CHAT ERROR]', err);
        res.status(500).json({ message: `AI Service error: ${err.message}` });
    }
});

// POST /ai/analyze
router.post('/analyze', validate(analyzeSchema), async (req, res, next) => {
    try {
        if (!process.env.GEMINI_API_KEY) {
            return res.json({ analysis: "AI Analysis offline: GEMINI_API_KEY not configured." });
        }

        const { symbol, price: currentPrice, trend } = req.body;
        const now = Date.now();

        // 1. Check Cache (10 min TTL)
        const cached = analysisCache.get(symbol);
        if (cached && (now - cached.timestamp < CACHE_TTL)) {
            return res.json({ analysis: cached.data });
        }

        // 2. Fetch Multi-Period Trends (1D, 1W, 1M)
        const periods = [
            { label: '1D', interval: '1 day' },
            { label: '1W', interval: '7 days' },
            { label: '1M', interval: '30 days' }
        ];

        const trends = {};
        for (const p of periods) {
            const result = await db.query(`
                SELECT close 
                FROM price_candles 
                WHERE symbol = $1 
                  AND time <= NOW() - INTERVAL '${p.interval}'
                ORDER BY time DESC 
                LIMIT 1
            `, [symbol]);
            
            if (result.rows.length > 0) {
                const prevPrice = parseFloat(result.rows[0].close);
                const ltp = currentPrice || 0;
                // If currentPrice is 0 (from optimized frontend), get latest from DB
                const effectiveLtp = ltp > 0 ? ltp : await getLatestPrice(symbol);
                
                const change = ((effectiveLtp - prevPrice) / prevPrice) * 100;
                trends[p.label] = `${change >= 0 ? '+' : ''}${change.toFixed(2)}% (from ₹${prevPrice.toFixed(2)})`;
            } else {
                trends[p.label] = "Data insufficient";
            }
        }

        const prompt = `You are a professional market analyst for Blauplug.
            Analyze ${symbol} across three timeframes:
            - **1 Day Trend**: ${trends['1D']}
            - **1 Week Trend**: ${trends['1W']}
            - **1 Month Trend**: ${trends['1M']}
            
            Current Price: ₹${currentPrice || 'Loading...'}.
            
            Provide a technical outlook for EACH timeframe (1D, 1W, 1M) and a final combined sentiment.
            Keep it strictly under 250 words. Format with Markdown. Use bold headers for sections.`;

        const result = await model.generateContent(prompt);
        const response = await result.response;
        const text = response.text();

        // 3. Store in Cache
        analysisCache.set(symbol, {
            data: text,
            timestamp: now
        });

        res.json({ analysis: text });
    } catch (err) {
        if (err.status === 429) {
            console.error(`[AI ANALYZE] Rate Limit Exceeded (429) for ${req.body.symbol}`);
            return res.status(200).json({ analysis: "AI Quota Exceeded. Please try again later." });
        }
        console.error('[AI ANALYZE ERROR]', err);
        res.status(500).json({ analysis: `AI Service error: ${err.message}` });
    }
});

/**
 * Helper to get the latest known price for a symbol
 */
async function getLatestPrice(symbol) {
    const res = await db.query(`
        SELECT close FROM price_candles 
        WHERE symbol = $1 
        ORDER BY time DESC LIMIT 1
    `, [symbol]);
    return res.rows.length > 0 ? parseFloat(res.rows[0].close) : 0;
}

module.exports = router;
