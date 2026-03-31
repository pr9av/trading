-- ============================================================
--   Blauplug Innovation Pvt Ltd — Analytics Platform
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
    role          VARCHAR(32)  NOT NULL DEFAULT 'analyst', -- admin | analyst | viewer
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email    ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);

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
-- ============================================================
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

CREATE INDEX IF NOT EXISTS idx_price_candles_symbol_time ON price_candles (symbol, time DESC);

-- ============================================================
--   FUNDAMENTALS (Sector & Company Info)
-- ============================================================
CREATE TABLE IF NOT EXISTS fundamentals (
    symbol      VARCHAR(32) PRIMARY KEY,
    company_name VARCHAR(255),
    sector      VARCHAR(64),
    industry    VARCHAR(128),
    market_cap  BIGINT,
    pe_ratio    NUMERIC(10,2),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--   AI SIGNALS
-- ============================================================
CREATE TABLE IF NOT EXISTS ai_signals (
    id         UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol     VARCHAR(32)   NOT NULL,
    signal     VARCHAR(16)   NOT NULL,       -- BUY | SELL | HOLD (Analytic signals)
    confidence NUMERIC(5,4)  NOT NULL,       -- 0.0000 to 1.0000
    model_name VARCHAR(64)   NOT NULL,
    features   JSONB,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_signals_symbol       ON ai_signals (symbol);
CREATE INDEX IF NOT EXISTS idx_ai_signals_generated_at ON ai_signals (generated_at DESC);

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
