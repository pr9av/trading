# Blauplug Trading Platform V2

Blauplug V2 is a production-ready, real-time virtual trading platform and market analytics suite. It integrates with the Zerodha Kite Connect API for live market data and utilizes Google Gemini AI for advanced multi-period technical analysis.

## 🚀 Features

*   **Real-Time Dashboard**: Live data streaming of NSE instruments via Zerodha WebSocket.
*   **AI-Powered Insights**: Professional technical analysis across 1D, 1W, and 1M timeframes using Gemini 2.0 Flash.
*   **Historical Charting**: High-performance OHLC candlestick charts with custom range selection.
*   **Portfolio Management**: Secure per-user trade journal, watchlist, and behavioral analytics.
*   **Market State Aware**: Automatic switching between Live and Historical modes based on NSE market hours.
*   **Resilient Backend**: In-memory caching, rate limiting, and robust error handling.

## 🛠️ Tech Stack

*   **Frontend**: Flutter (Riverpod for state management, Candlesticks for charting).
*   **Backend**: Node.js, Express.
*   **Database**: PostgreSQL (Relational data), Redis (Pub/Sub & Caching).
*   **APIs**: Zerodha Kite Connect, Google Gemini AI.

## 📦 Installation & Setup

### Prerequisites
*   Flutter SDK
*   Node.js (v18+)
*   PostgreSQL & Redis
*   Zerodha Developer API Key & Secret

### 1. Database Setup
Create a PostgreSQL database and run the initial migrations (or let the app sync instruments on startup).

### 2. Backend Configuration
Navigate to the `backend/` directory and create a `.env` file:
```env
PORT=8000
DATABASE_URL=postgres://user:password@localhost:5432/blauplug
REDIS_URL=redis://localhost:6379
ZERODHA_API_KEY=your_kite_key
ZERODHA_API_SECRET=your_kite_secret
ZERODHA_ACCESS_TOKEN=your_refreshed_token
GEMINI_API_KEY=your_gemini_key
JWT_SECRET=your_jwt_secret
```
Run `npm install` and then `npm start`.

### 3. Frontend Configuration
Navigate to the `frontend/` directory. Ensure `lib/config/api_config.dart` points to your backend URL.
Run `flutter pub get` and then `flutter run`.

## 🤖 AI Multi-Period Analysis
The platform features a custom-built AI engine that gathers historical trends (Short, Medium, and Long term) and summarizes them into a single actionable report per stock. Results are cached for 10 minutes to optimize API usage.

## 📄 License
Proprietary — Blauplug Innovation Pvt Ltd.
