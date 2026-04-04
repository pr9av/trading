require('dotenv').config();
const { KiteConnect } = require('kiteconnect');

const apiKey = process.env.ZERODHA_API_KEY;
const apiSecret = process.env.ZERODHA_API_SECRET;
const requestToken = process.argv[2];

if (!apiKey || !apiSecret) {
    console.error("❌ Error: Missing ZERODHA_API_KEY or ZERODHA_API_SECRET in backend/.env");
    process.exit(1);
}

if (!requestToken) {
    console.error("❌ Error: Missing request token.");
    console.log("\nUsage: node generate_token.js <YOUR_REQUEST_TOKEN>");
    process.exit(1);
}

const kite = new KiteConnect({ api_key: apiKey });

async function generateToken() {
    try {
        console.log("Generating access token...");
        const response = await kite.generateSession(requestToken, apiSecret);
        
        console.log("\n✅ Success! Here is your daily access token:\n");
        console.log("=====================================================");
        console.log(response.access_token);
        console.log("=====================================================\n");
        console.log("👉 Copy and paste this into your backend/.env file as ZERODHA_ACCESS_TOKEN");
        
    } catch (err) {
        console.error("❌ Failed to generate token. The request token might be expired (they only last a few minutes) or invalid.");
        console.error(err.message);
    }
}

generateToken();
