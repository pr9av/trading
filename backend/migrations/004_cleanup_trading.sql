-- ============================================================
--   Migration 004 — Cleanup Trading & Portfolio Logic
--   Removing tables no longer needed for data analytics app.
-- ============================================================

DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS trades CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS portfolio_holdings CASCADE;
DROP TABLE IF EXISTS portfolios CASCADE;

-- We keep:
--  - users (for authentication)
--  - price_ticks (core analytics data)
--  - price_candles (core analytics data)
--  - fundamentals (core analytics data)
--  - ai_signals (analytics output)
--  - audit_logs (security)
