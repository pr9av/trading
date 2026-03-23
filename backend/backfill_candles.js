require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const symbols = ['RELIANCE', 'INFY', 'TCS', 'HDFCBANK', 'ICICIBANK'];
const basePrices = { RELIANCE: 2850, INFY: 1740, TCS: 3900, HDFCBANK: 1650, ICICIBANK: 1100 };

async function backfill() {
  try {
    console.log("Generating 60 minutes of historical market data...");
    for (const sym of symbols) {
      let price = basePrices[sym];
      for (let i = 60; i >= 1; i--) {
        const time = `NOW() - INTERVAL '${i} minutes'`;
        // Add random slight volatility
        price = price * (1 + (Math.random() * 0.008 - 0.004));
        
        const q = `
          INSERT INTO price_ticks (time, symbol, exchange, ltp, volume) 
          VALUES (${time}, $1, 'NSE', $2, 1000)
        `;
        await pool.query(q, [sym, price]);
      }
    }
    console.log("✅ Backfill 100% complete! Your charts will now explode with data.");
  } catch (e) {
    console.error("❌ Backfill failed:", e.message);
  } finally {
    pool.end();
  }
}

backfill();
