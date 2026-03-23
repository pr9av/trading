const express = require('express');
const router = express.Router();
const db = require('../db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const SECRET_KEY = process.env.SECRET_KEY || 'default-secret-key';

router.post('/register', async (req, res) => {
    const { username, email, password } = req.body;
    
    try {
        const hashedPassword = await bcrypt.hash(password, 10);
        const query = `
            INSERT INTO users (username, email, password_hash)
            VALUES ($1, $2, $3) RETURNING id, username, email
        `;
        const result = await db.query(query, [username, email, hashedPassword]);
        res.status(201).json(result.rows[0]);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

router.post('/login', async (req, res) => {
    const { username, password } = req.body;
    
    try {
        const result = await db.query('SELECT * FROM users WHERE username = $1', [username]);
        const user = result.rows[0];
        
        if (!user || !(await bcrypt.compare(password, user.password_hash))) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        const token = jwt.sign(
            { id: user.id, username: user.username, role: user.role },
            SECRET_KEY,
            { expiresIn: '24h' }
        );
        
        res.json({ 
            access_token: token, 
            token_type: 'bearer', 
            username: user.username,
            user_id: user.id,
            role: user.role
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
