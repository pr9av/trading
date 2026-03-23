-- ============================================================
--   Blauplug Innovation Pvt Ltd — Trading Platform
--   PostgreSQL Database Schema
--   Compatible with TimescaleDB for market_ticks table
-- ============================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
--   USERS
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username      VARCHAR(64)  NOT NULL UNIQUE,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT         NOT NULL,
    role          VARCHAR(32)  NOT NULL DEFAULT 'trader',   -- admin | trader | viewer
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email    ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);

-- ============================================================
--   PORTFOLIOS
-- ============================================================
CREATE TABLE IF NOT EXISTS portfolios (
    id             UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id        UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cash_balance   NUMERIC(18,4) NOT NULL DEFAULT 0.00,
    total_pnl      NUMERIC(18,4) NOT NULL DEFAULT 0.00,
    day_pnl        NUMERIC(18,4) NOT NULL DEFAULT 0.00,
    last_synced_at TIMESTAMPTZ,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (user_id)
);

-- ============================================================
--   PORTFOLIO HOLDINGS
-- ============================================================
CREATE TABLE IF NOT EXISTS portfolio_holdings (
    id             UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id   UUID          NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    symbol         VARCHAR(32)   NOT NULL,
    exchange       VARCHAR(16)   NOT NULL DEFAULT 'NSE',
    quantity       INTEGER       NOT NULL DEFAULT 0,
    avg_buy_price  NUMERIC(18,4) NOT NULL DEFAULT 0.00,
    current_price  NUMERIC(18,4) NOT NULL DEFAULT 0.00,
    pnl            NUMERIC(18,4) NOT NULL DEFAULT 0.00,
    updated_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    UNIQUE (portfolio_id, symbol, exchange)
);

CREATE INDEX IF NOT EXISTS idx_holdings_portfolio ON portfolio_holdings (portfolio_id);
CREATE INDEX IF NOT EXISTS idx_holdings_symbol    ON portfolio_holdings (symbol);

-- ============================================================
--   ORDERS
-- ============================================================
CREATE TABLE IF NOT EXISTS orders (
    id              UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID          NOT NULL REFERENCES users(id),
    broker_order_id VARCHAR(128),                            -- Zerodha/Upstox native order ID
    symbol          VARCHAR(32)   NOT NULL,
    exchange        VARCHAR(16)   NOT NULL DEFAULT 'NSE',
    order_type      VARCHAR(16)   NOT NULL,                  -- MARKET | LIMIT | SL | SL-M
    side            VARCHAR(8)    NOT NULL,                  -- BUY | SELL
    product         VARCHAR(16)   NOT NULL DEFAULT 'MIS',    -- MIS | CNC | NRML
    quantity        INTEGER       NOT NULL,
    price           NUMERIC(18,4) DEFAULT 0.00,
    trigger_price   NUMERIC(18,4) DEFAULT 0.00,
    status          VARCHAR(32)   NOT NULL DEFAULT 'created', -- created | validated | placed | executed | rejected | cancelled
    filled_quantity INTEGER       NOT NULL DEFAULT 0,
    avg_fill_price  NUMERIC(18,4),
    rejection_reason TEXT,
    broker          VARCHAR(32)   NOT NULL DEFAULT 'simulated',
    placed_at       TIMESTAMPTZ,
    executed_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders (user_id);
CREATE INDEX IF NOT EXISTS idx_orders_symbol  ON orders (symbol);
CREATE INDEX IF NOT EXISTS idx_orders_status  ON orders (status);
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders (created_at DESC);

-- ============================================================
--   TRADES
-- ============================================================
CREATE TABLE IF NOT EXISTS trades (
    id              UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id        UUID          NOT NULL REFERENCES orders(id),
    user_id         UUID          NOT NULL REFERENCES users(id),
    broker_trade_id VARCHAR(128),
    symbol          VARCHAR(32)   NOT NULL,
    exchange        VARCHAR(16)   NOT NULL DEFAULT 'NSE',
    side            VARCHAR(8)    NOT NULL,
    quantity        INTEGER       NOT NULL,
    price           NUMERIC(18,4) NOT NULL,
    value           NUMERIC(18,4) NOT NULL,
    brokerage       NUMERIC(18,4) NOT NULL DEFAULT 0.00,
    taxes           NUMERIC(18,4) NOT NULL DEFAULT 0.00,
    net_value       NUMERIC(18,4) NOT NULL,
    executed_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trades_user_id    ON trades (user_id);
CREATE INDEX IF NOT EXISTS idx_trades_order_id   ON trades (order_id);
CREATE INDEX IF NOT EXISTS idx_trades_symbol     ON trades (symbol);
CREATE INDEX IF NOT EXISTS idx_trades_executed_at ON trades (executed_at DESC);

-- ============================================================
--   TRANSACTIONS (cash ledger)
-- ============================================================
CREATE TABLE IF NOT EXISTS transactions (
    id              UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID          NOT NULL REFERENCES users(id),
    trade_id        UUID          REFERENCES trades(id),
    type            VARCHAR(32)   NOT NULL, -- CREDIT | DEBIT | BROKERAGE | TAX | DIVIDEND
    amount          NUMERIC(18,4) NOT NULL,
    balance_after   NUMERIC(18,4) NOT NULL,
    description     TEXT,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_user_id   ON transactions (user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions (created_at DESC);

-- ============================================================
--   AUDIT LOGS
-- ============================================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID        REFERENCES users(id),
    service     VARCHAR(64) NOT NULL,
    action      VARCHAR(128) NOT NULL,
    entity_type VARCHAR(64),
    entity_id   UUID,
    ip_address  VARCHAR(45),
    user_agent  TEXT,
    payload     JSONB,
    result      VARCHAR(16), -- success | failure
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id    ON audit_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_service    ON audit_logs (service);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs (created_at DESC);

-- ============================================================
--   PRICE TICKS (TimescaleDB Hypertable)
-- ============================================================
CREATE TABLE IF NOT EXISTS price_ticks (
    time            TIMESTAMPTZ   NOT NULL,
    symbol          VARCHAR(32)   NOT NULL,
    exchange        VARCHAR(16)   NOT NULL DEFAULT 'NSE',
    ltp             NUMERIC(18,4) NOT NULL,  -- Last Traded Price
    open            NUMERIC(18,4),
    high            NUMERIC(18,4),
    low             NUMERIC(18,4),
    close           NUMERIC(18,4),
    volume          BIGINT,
    oi              BIGINT,                  -- Open Interest
    bid             NUMERIC(18,4),
    ask             NUMERIC(18,4),
    broker_source   VARCHAR(32)
);

CREATE INDEX IF NOT EXISTS idx_price_ticks_symbol ON price_ticks (symbol, time DESC);

-- ============================================================
--   OHLC CANDLES (Aggregated Data)
-- ============================================================-- 4. 1-minute OHLC candles (materialized from ticks or fetched from Kite)
CREATE TABLE IF NOT EXISTS price_candles (
    time        TIMESTAMPTZ NOT NULL,
    symbol      TEXT        NOT NULL,
    exchange    TEXT        NOT NULL,
    open        NUMERIC     NOT NULL,
    high        NUMERIC     NOT NULL,
    low         NUMERIC     NOT NULL,
    close       NUMERIC     NOT NULL,
    volume      BIGINT
);

-- Fallback to standard PostgreSQL index instead of Hypertable
CREATE INDEX IF NOT EXISTS idx_price_candles_symbol_time ON price_candles (symbol, time DESC);

-- Removed api_logs to resolve Neon deployment collision.

-- ============================================================
--   AI SIGNALS
-- ============================================================
CREATE TABLE IF NOT EXISTS ai_signals (
    id         UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol     VARCHAR(32)   NOT NULL,
    signal     VARCHAR(16)   NOT NULL,       -- BUY | SELL | HOLD
    confidence NUMERIC(5,4)  NOT NULL,       -- 0.0000 to 1.0000
    model_name VARCHAR(64)   NOT NULL,
    features   JSONB,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_signals_symbol       ON ai_signals (symbol);
CREATE INDEX IF NOT EXISTS idx_ai_signals_generated_at ON ai_signals (generated_at DESC);

-- ============================================================
--   SEED: Default Admin User
--   Password: Admin@1234 (bcrypt hash)
-- ============================================================
INSERT INTO users (username, email, password_hash, role)
VALUES (
    'admin',
    'admin@blauplug.in',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TqzneflfijxivzsGGdnqKDmkBJCa',
    'admin'
) ON CONFLICT DO NOTHING;

INSERT INTO portfolios (user_id, cash_balance)
SELECT id, 1000000.00 FROM users WHERE username = 'admin'
ON CONFLICT DO NOTHING;
