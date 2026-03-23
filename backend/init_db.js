require('dotenv').config();
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function initDB() {
  try {
    const schemaPath = path.join(__dirname, '../database/schema.sql');
    const sql = fs.readFileSync(schemaPath, 'utf8');
    console.log("Applying schema...");
    await pool.query(sql);
    console.log("✅ Schema successfully applied!");
  } catch (err) {
    console.error("❌ Schema application failed:", err.message);
  } finally {
    pool.end();
  }
}

initDB();
