# Antigravity Prompt: Virtual Stock Trading App (Flutter + Zerodha Kite API + Gemini AI)

## Project Overview
Build a **Flutter mobile application** for virtual stock trading with:
- Real-time market data from **Zerodha Kite Connect API**
- Local storage via **Hive** (portfolio, holdings, transactions — offline-first)
- Price history & analytics via **TimescaleDB** (backend, candlestick/OHLC data)
- Backend API via **Node.js + Express** (bridges Flutter ↔ TimescaleDB)
- AI insights via **Gemini API**
- Starting virtual balance of ₹10,00,000

### Architecture Overview
```
Flutter App
├── Hive (local)         → portfolio state, holdings, transactions, watchlist (offline-first)
└── REST API calls       → Node.js/Express backend
                              └── TimescaleDB (PostgreSQL + timescaledb extension)
                                      → price_candles table (OHLC, 1-min buckets)
                                      → price_ticks table (raw tick data from Kite)
                                      → analytics views (daily P&L, volume trends)
```

**Rule**: Never store portfolio or trading data in TimescaleDB. Never store time-series price history in Hive. Each database does only what it's best at.

---

## API Keys & Config Required
- **Kite Connect API credentials**: API Key, API Secret, Access Token
- **Gemini API Key**: for AI features
- **PostgreSQL/TimescaleDB connection string**: for backend

> ⚠️ Store Flutter keys in `lib/config/api_config.dart` — add to `.gitignore`
> ⚠️ Store backend secrets in `backend/.env` — add to `.gitignore`
> ⚠️ Kite Connect Access Tokens expire daily — implement manual token refresh for demo purposes

---

## Part A: Backend (Node.js + TimescaleDB)

### A1. Backend Project Setup

Create a `backend/` folder at the project root with:

```
backend/
├── .env                     # DB connection string, port
├── package.json
├── src/
│   ├── index.js             # Express app entry point
│   ├── db.js                # PostgreSQL pool (pg library)
│   ├── routes/
│   │   ├── candles.js       # GET /candles/:symbol?interval=1min&from=&to=
│   │   ├── ticks.js         # POST /ticks (ingest tick from Kite websocket)
│   │   └── analytics.js     # GET /analytics/pnl, /analytics/volume
│   └── jobs/
│       └── fetchCandles.js  # Cron job: fetch OHLC from Kite every minute
```

Install dependencies:
```bash
npm install express pg dotenv node-cron
```

### A2. TimescaleDB Schema

Run these SQL migrations on your TimescaleDB instance:

```sql
-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Raw tick data (every price update from Kite websocket)
CREATE TABLE price_ticks (
  time        TIMESTAMPTZ NOT NULL,
  symbol      TEXT        NOT NULL,
  exchange    TEXT        NOT NULL,
  ltp         NUMERIC     NOT NULL,  -- last traded price
  volume      BIGINT,
  bid         NUMERIC,
  ask         NUMERIC
);
SELECT create_hypertable('price_ticks', 'time');
CREATE INDEX ON price_ticks (symbol, time DESC);

-- 1-minute OHLC candles (materialized from ticks or fetched from Kite)
CREATE TABLE price_candles (
  time        TIMESTAMPTZ NOT NULL,
  symbol      TEXT        NOT NULL,
  exchange    TEXT        NOT NULL,
  open        NUMERIC     NOT NULL,
  high        NUMERIC     NOT NULL,
  low         NUMERIC     NOT NULL,
  close       NUMERIC     NOT NULL,
  volume      BIGINT
);
SELECT create_hypertable('price_candles', 'time');
CREATE INDEX ON price_candles (symbol, time DESC);

-- Continuous aggregate: 5-minute candles auto-derived from 1-min candles
CREATE MATERIALIZED VIEW candles_5min
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('5 minutes', time) AS bucket,
  symbol,
  exchange,
  first(open,  time) AS open,
  max(high)          AS high,
  min(low)           AS low,
  last(close,  time) AS close,
  sum(volume)        AS volume
FROM price_candles
GROUP BY bucket, symbol, exchange;
```

### A3. Key Backend Endpoints

**`GET /candles/:symbol`**
Query params: `interval` (1min/5min/15min/1hr/1day), `from` (ISO timestamp), `to` (ISO timestamp)
- For `1min`: query `price_candles` directly
- For `5min`: query `candles_5min` materialized view
- For `1day`: use `time_bucket('1 day', time)` on `price_candles`
- Returns: `[{ time, open, high, low, close, volume }]`

**`POST /ticks`**
Body: `{ symbol, exchange, ltp, volume, bid, ask }`
- Insert into `price_ticks`
- Used by the Kite WebSocket listener running on the backend

**`GET /analytics/pnl`**
Query params: `symbol`, `from`, `to`
- Returns daily P&L trend using TimescaleDB `time_bucket` aggregation

**`GET /analytics/volume`**
- Returns top traded symbols by volume for the day

### A4. Cron Job: Fetch Candles from Kite
In `fetchCandles.js`, run every minute during market hours (9:15 AM – 3:30 PM IST):
- Call Kite's historical data API for each watched symbol
- Upsert OHLC data into `price_candles`
- Use `ON CONFLICT DO NOTHING` to avoid duplicates

---

## Part B: Flutter App

### B1. Dependencies — update `pubspec.yaml`

```yaml
dependencies:
  flutter_riverpod: ^2.x
  hive_flutter: ^1.x
  hive: ^2.x
  http: ^1.x
  fl_chart: ^0.x
  intl: ^0.x
  shimmer: ^3.x
  google_generative_ai: ^0.x
  flutter_local_notifications: ^17.x
  share_plus: ^10.x
  path_provider: ^2.x
  connectivity_plus: ^6.x
  candlesticks: ^2.x        # Candlestick chart widget for OHLC data

dev_dependencies:
  hive_generator: ^2.x
  build_runner: ^2.x
```

### B2. Folder Structure

```
lib/
├── main.dart                      # App entry point — Hive init + Riverpod ProviderScope
├── config/
│   ├── api_config.dart            # Kite + Gemini keys (gitignored)
│   └── backend_config.dart        # Backend base URL (e.g. http://localhost:3000)
├── core/
│   ├── theme/
│   │   └── app_theme.dart
│   ├── constants/
│   │   └── app_constants.dart
│   └── utils/
│       ├── formatters.dart
│       └── extensions.dart
├── data/
│   ├── models/
│   │   ├── hive/                  # LOCAL — Hive models only
│   │   │   ├── user_portfolio.dart
│   │   │   ├── holding.dart
│   │   │   ├── transaction.dart
│   │   │   └── watchlist_item.dart
│   │   └── api/                   # REMOTE — plain Dart models (no Hive)
│   │       ├── stock_quote.dart
│   │       ├── candle.dart        # OHLC candle from TimescaleDB backend
│   │       └── analytics_pnl.dart
│   ├── repositories/
│   │   ├── portfolio_repository.dart   # Reads/writes Hive only
│   │   ├── price_history_repository.dart  # Calls backend /candles endpoint
│   │   └── analytics_repository.dart   # Calls backend /analytics endpoints
│   └── services/
│       ├── kite_api_service.dart
│       ├── gemini_service.dart
│       └── backend_service.dart        # HTTP client for Node.js backend
├── providers/
│   ├── portfolio_provider.dart
│   ├── market_provider.dart
│   ├── candle_provider.dart            # Fetches OHLC from backend
│   └── analytics_provider.dart
├── screens/
│   ├── main_screen.dart
│   ├── home_screen.dart
│   ├── markets_screen.dart
│   ├── portfolio_screen.dart
│   ├── orders_screen.dart
│   ├── watchlist_screen.dart
│   ├── stock_detail_screen.dart        # Now includes candlestick chart
│   └── analytics_screen.dart          # NEW — powered by TimescaleDB
└── widgets/
    ├── stock_card.dart
    ├── portfolio_chart.dart
    ├── candlestick_chart_widget.dart   # NEW — wraps `candlesticks` package
    ├── order_dialog.dart
    ├── index_card.dart
    └── loading_shimmer.dart
```

### B3. Hive Models (unchanged — local only)

**`user_portfolio.dart`**: `virtualBalance`, `totalInvested`, `createdDate`, `initialBalance` (₹10,00,000)

**`holding.dart`**: `symbol`, `tradingSymbol`, `exchange`, `quantity`, `averagePrice`, `lastTransactionDate`

**`transaction.dart`**: `id`, `transactionType` (BUY/SELL), `symbol`, `quantity`, `price`, `totalAmount`, `timestamp`, `orderType`, `brokerage`

**`watchlist_item.dart`**: `symbol`, `exchange`, `addedDate`

### B4. New: `candle.dart` (API model)

```dart
class Candle {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;
}
```

### B5. `backend_service.dart`

```dart
class BackendService {
  final String baseUrl = BackendConfig.baseUrl;

  Future<List<Candle>> getCandles(String symbol, {
    String interval = '1min',
    DateTime? from,
    DateTime? to,
  }) async {
    // GET $baseUrl/candles/$symbol?interval=$interval&from=...&to=...
    // Parse response into List<Candle>
  }

  Future<List<AnalyticsPnl>> getDailyPnl(String symbol) async {
    // GET $baseUrl/analytics/pnl?symbol=$symbol
  }
}
```

### B6. Services

**`kite_api_service.dart`** — same as before:
- Fetch NIFTY/SENSEX indices, stock quotes, search stocks
- Handle token expiry with mock data fallback

**`gemini_service.dart`** — enhanced:
- Stock analysis with portfolio context
- Pass recent price trend (from TimescaleDB candles) as additional context
- Trading suggestions and market sentiment

---

## Phase 3: Business Logic Layer (unchanged)

**`trading_provider.dart`**:
- Execute BUY: validate balance → deduct → update Hive holdings
- Execute SELL: validate holdings → add proceeds → update Hive holdings
- Brokerage: 0.1% per transaction
- Order types: MARKET, LIMIT, SL

---

## Phase 4: UI Implementation

### `main_screen.dart`
Bottom navigation: **Home, Markets, Portfolio, Orders, Watchlist** (+ Analytics tab)

### `home_screen.dart`
- Total portfolio value (cash + holdings) — from Hive
- Today's P&L and Overall P&L — from Hive
- Portfolio allocation pie chart — from Hive
- Recent transactions list — from Hive

### `markets_screen.dart`
- NIFTY/SENSEX live indices — from Kite API
- Stock list with real-time prices — from Kite API
- Search functionality

### `portfolio_screen.dart`
- Holdings list with current value and P&L — from Hive
- Portfolio performance chart (fl_chart) — from Hive
- CSV export button

### `orders_screen.dart`
- Order history with BUY/SELL labels — from Hive
- Filter by date/stock

### `watchlist_screen.dart`
- Saved stocks with live prices — watchlist from Hive, prices from Kite
- Add/remove stocks

### `stock_detail_screen.dart` ⭐ Updated
- Live price and stock info — from Kite API
- **Candlestick chart** — fetched from TimescaleDB backend via `candle_provider`
  - Interval selector: 1min / 5min / 15min / 1hr / 1day
  - Uses `candlesticks` Flutter package
- BUY/SELL order dialog
- AI assistant chat button (Gemini, with price trend context)

### `analytics_screen.dart` ⭐ New
- Daily P&L trend chart — from TimescaleDB `/analytics/pnl`
- Volume heatmap — from TimescaleDB `/analytics/volume`
- Best/worst performing symbols
- Powered entirely by TimescaleDB aggregations

### AI Assistant Chat Screen
- Floating chat interface using Gemini
- Context-aware: sends portfolio state + recent price candles with each query

---

## Phase 5: Advanced Features

- Candlestick chart with interval switching (1min/5min/1hr/1day)
- Analytics dashboard (daily P&L trend, volume, top movers) — TimescaleDB
- Portfolio reset functionality (resets to ₹10,00,000)
- CSV export for transactions
- Offline mode: Hive serves cached portfolio data, graceful error for charts
- Price alerts via local notifications

---

## Phase 6: Polish & Testing

### Manual Verification Steps

1. **Backend health check**
   - Run `node src/index.js` in `backend/`
   - Hit `GET /candles/RELIANCE?interval=1min` — confirm OHLC data returns
   - Hit `GET /analytics/pnl?symbol=RELIANCE` — confirm aggregation works

2. **Initial App Launch**
   - Run `flutter run`
   - Verify app starts with ₹10,00,000 balance
   - Confirm all navigation tabs are accessible

3. **Market Data Fetching**
   - Navigate to Markets screen
   - Verify NIFTY and SENSEX indices show live data

4. **Candlestick Chart**
   - Open any stock detail page
   - Verify candlestick chart loads from backend
   - Switch intervals (1min → 5min → 1day) — confirm chart updates

5. **Virtual Trading Flow**
   - Search "RELIANCE", place BUY order for 10 shares
   - Verify balance deducted correctly (price × 10 + 0.1% brokerage)
   - Check Portfolio screen shows holding — stored in Hive

6. **Sell Flow**
   - From Portfolio, tap a holding → execute SELL
   - Verify balance increases, holding updates — Hive only

7. **Analytics Screen**
   - Navigate to Analytics
   - Verify P&L trend chart loads from TimescaleDB backend
   - Verify volume data displays correctly

8. **Watchlist**
   - Add a stock, verify live price appears
   - Remove the stock

9. **Portfolio Reset**
   - Use reset button — confirm Hive clears, balance resets to ₹10,00,000
   - Confirm TimescaleDB data is unaffected (price history is not personal data)

10. **Offline Mode**
    - Disable network
    - Portfolio/holdings screens (Hive) should work normally
    - Charts (TimescaleDB via backend) should show graceful "no connection" state

11. **AI Assistant** *(requires Gemini API key)*
    - Ask "Should I buy RELIANCE?"
    - Verify response includes current portfolio context AND recent price trend

### Automated Tests
- Portfolio calculations (Hive layer)
- Trade execution logic
- Hive CRUD operations
- `BackendService` unit tests with mocked HTTP responses

---

## Implementation Order

1. **Backend first**: TimescaleDB schema → Express routes → test with curl
2. **Flutter project setup**: dependencies, folder structure
3. **Hive models** and initialization
4. **Kite API service** (with mock fallback)
5. **Backend service** (`backend_service.dart`) + candle provider
6. **Repositories and providers** (portfolio + price history)
7. **UI screens** one by one — start with Home, Markets, Portfolio
8. **Stock detail screen** with candlestick chart
9. **Analytics screen**
10. **AI integration** (Gemini with candle context)
11. **Advanced features**: alerts, CSV export, offline graceful handling

---

## Notes
- **Hive** = source of truth for all user portfolio data. Always offline-first.
- **TimescaleDB** = source of truth for all price history. Never store OHLC in Hive.
- Use mock data fallback when Kite API credentials are unavailable
- Kite tokens expire daily — build with manual refresh for demo
- For local development, run TimescaleDB via Docker: `docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=password timescale/timescaledb:latest-pg16`
- Use **Claude Opus 4.5 (Thinking)** model in Antigravity for best results on complex tasks
