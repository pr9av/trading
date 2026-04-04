/**
 * Cron Job Runner — Standalone entry point
 * 
 * Run with: node src/jobs/index.js
 * 
 * This runs the background cron jobs as a separate process,
 * isolated from the Express HTTP server.
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });

console.log('[JOBS] Starting background job runner...');
require('./fetchCandles');

if (process.env.ACTIVE_BROKER === 'zerodha') {
    require('./zerodhaTicker');
}

console.log('[JOBS] All jobs registered. Waiting for schedules...');
