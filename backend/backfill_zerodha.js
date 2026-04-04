require('dotenv').config();
const { KiteConnect } = require('kiteconnect');
const db = require('./src/db'); 

const apiKey = process.env.ZERODHA_API_KEY;
const accessToken = process.env.ZERODHA_ACCESS_TOKEN;

if (!apiKey || !accessToken) {
    console.error("❌ Missing Zerodha API Key or Access Token in .env");
    process.exit(1);
}

const kite = new KiteConnect({ api_key: apiKey });
// The Kite Connect SDK requires the access token to be set explicitly
kite.setAccessToken(accessToken);

const symbol = process.argv[2];
const days = parseInt(process.argv[3]) || 1;

if (!symbol) {
    console.log(`
    🔴 Usage: node backfill_zerodha.js <SYMBOL> <DAYS_AGO>
    Example: node backfill_zerodha.js RELIANCE 3
    `);
    process.exit(1);
}

async function backfill() {
    try {
        console.log(`\n🔍 Connecting to Zerodha to search for: ${symbol.toUpperCase()}...`);
        
        // 1. Fetch all instruments mapped on NSE
        // The SDK downloads and parses a massive list of all trading symbols
        const instruments = await kite.getInstruments("NSE");
        
        // 2. Search for the exact symbol (e.g., RELIANCE)
        const instrument = instruments.find(i => i.tradingsymbol === symbol.toUpperCase());
        
        if (!instrument) {
            console.error(`\n❌ Could not find exact symbol "${symbol.toUpperCase()}" on NSE.`);
            
            // Helpful dynamic search recommendation
            const suggestions = instruments
                .filter(i => i.tradingsymbol.includes(symbol.toUpperCase()))
                .slice(0, 8)
                .map(i => i.tradingsymbol);
                
            if (suggestions.length > 0) {
                console.log(`\n💡 Did you mean one of these?`);
                suggestions.forEach(s => console.log(`   - ${s}`));
            }
            process.exit(1);
        }
        
        console.log(`✅ Found! mapped "${instrument.tradingsymbol}" to instrument token: ${instrument.instrument_token}`);
        
        // 3. Calculate Date Range
        const toDate = new Date();
        const fromDate = new Date();
        fromDate.setDate(toDate.getDate() - days);
        
        console.log(`📅 Fetching 1-minute historical candles from ${fromDate.toISOString().split('T')[0]} to ${toDate.toISOString().split('T')[0]}...`);

        // 4. Fetch History
        const historicalData = await kite.getHistoricalData(
            instrument.instrument_token.toString(),
            "minute",
            fromDate,
            toDate,
            false 
        );

        if (!historicalData || historicalData.length === 0) {
            console.log("\n⚠️ Zerodha returned 0 candles. Either the market was closed on these dates, or your Historical API subscription is not active.");
            process.exit(0);
        }

        console.log(`📥 Downloaded ${historicalData.length} minute candles. Inserting into database...`);

        // 5. Insert into Postgres
        let insertedRows = 0;
        for (const candle of historicalData) {
            const result = await db.query(`
                INSERT INTO price_candles (time, symbol, exchange, open, high, low, close, volume)
                SELECT $1, $2, 'NSE', $3, $4, $5, $6, $7
                WHERE NOT EXISTS (
                    SELECT 1 FROM price_candles WHERE time = $1 AND symbol = $2
                )
            `, [
                candle.date,
                instrument.tradingsymbol,
                candle.open,
                candle.high,
                candle.low,
                candle.close,
                candle.volume
            ]);

            // rowCount is 1 if inserted, 0 if it was skipped
            if (result.rowCount > 0) insertedRows++;
        }

        console.log(`\n🎉 Success! Inserted ${insertedRows} new historical candles for ${instrument.tradingsymbol}.`);
        console.log(`Your Flutter Analytics charts will instantly reflect this data! 📈`);
    } catch (err) {
        console.error("\n❌ Failed to backfill data.");
        if (err.message) console.error(err.message);
    } finally {
        process.exit(0);
    }
}

backfill();
