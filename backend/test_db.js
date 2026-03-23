require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function checkDB() {
  try {
    const resCandles = await pool.query('SELECT COUNT(*) FROM price_candles');
    const resTicks = await pool.query('SELECT COUNT(*) FROM price_ticks');
    console.log("✅ PostgreSQL Connection SUCCESS!");
    console.log("📊 Total Rows in price_candles: " + resCandles.rows[0].count);
    console.log("📊 Total Rows in price_ticks: " + resTicks.rows[0].count);
  } catch (err) {
    console.error("❌ PostgreSQL Connection FAILED:", err.message);
  } finally {
    pool.end();
  }
}

checkDB();
