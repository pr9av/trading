require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function cleanupDb() {
  try {
    console.log("Purging old V1 unused tables from the active database...");
    await pool.query('DROP TABLE IF EXISTS market_ticks CASCADE');
    await pool.query('DROP TABLE IF EXISTS ohlv_candles CASCADE');
    await pool.query('DROP TABLE IF EXISTS api_logs CASCADE');
    
    // Some older iterations also had these, we can safely drop if they exist
    await pool.query('DROP TABLE IF EXISTS candles_5min CASCADE'); 
    
    console.log("✅ Successfully dropped legacy tables: market_ticks, ohlv_candles, api_logs.");
  } catch (err) {
    console.error("❌ Cleanup failed:", err.message);
  } finally {
    pool.end();
  }
}

cleanupDb();
