-- ============================================================
-- Blauplug Trading Platform — Phase 3 Migration
-- ============================================================

-- 1. Fundamentals table for stock P/E, P/B, Revenue, Market Cap
CREATE TABLE IF NOT EXISTS fundamentals (
    symbol VARCHAR(32) PRIMARY KEY,
    company_name VARCHAR(128),
    sector VARCHAR(64),
    industry VARCHAR(64),
    pe_ratio NUMERIC,
    pb_ratio NUMERIC,
    eps NUMERIC,
    revenue NUMERIC,
    market_cap NUMERIC,
    dividend_yield NUMERIC,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Seed sample data for testing/demo
INSERT INTO fundamentals (symbol, company_name, sector, industry, pe_ratio, pb_ratio, eps, revenue, market_cap, dividend_yield)
VALUES
  ('RELIANCE', 'Reliance Industries Ltd', 'Energy', 'Oil & Gas', 28.5, 2.1, 95.2, 924000, 1970000, 0.3),
  ('TCS', 'Tata Consultancy Services', 'Technology', 'IT Services', 32.1, 14.2, 126.3, 252000, 1480000, 1.2),
  ('HDFCBANK', 'HDFC Bank Ltd', 'Financial Services', 'Banking', 19.8, 3.4, 85.6, 270000, 1250000, 1.1),
  ('INFY', 'Infosys Ltd', 'Technology', 'IT Services', 27.3, 8.9, 63.4, 189000, 750000, 2.5),
  ('ICICIBANK', 'ICICI Bank Ltd', 'Financial Services', 'Banking', 17.2, 3.1, 58.9, 210000, 820000, 0.8)
ON CONFLICT (symbol) DO UPDATE SET
  company_name = EXCLUDED.company_name,
  sector = EXCLUDED.sector,
  industry = EXCLUDED.industry,
  pe_ratio = EXCLUDED.pe_ratio,
  pb_ratio = EXCLUDED.pb_ratio,
  eps = EXCLUDED.eps,
  revenue = EXCLUDED.revenue,
  market_cap = EXCLUDED.market_cap,
  dividend_yield = EXCLUDED.dividend_yield,
  updated_at = now();

-- ============================================================
-- 3. TimescaleDB Preparation (DO NOT RUN until scale requires it)
-- 
-- Uncomment the following when:
--   a) You have 5M+ rows in price_ticks
--   b) Your DB instance supports TimescaleDB extension
--
-- CREATE EXTENSION IF NOT EXISTS timescaledb;
-- SELECT create_hypertable('price_ticks', 'time', if_not_exists => TRUE);
-- SELECT create_hypertable('price_candles', 'time', if_not_exists => TRUE);
--
-- Continuous aggregate for hourly OHLC:
-- CREATE MATERIALIZED VIEW candles_1h
-- WITH (timescaledb.continuous) AS
-- SELECT
--   time_bucket('1 hour', time) AS bucket,
--   symbol,
--   first(ltp, time) AS open,
--   max(ltp) AS high,
--   min(ltp) AS low,
--   last(ltp, time) AS close,
--   sum(volume) AS volume
-- FROM price_ticks
-- GROUP BY bucket, symbol;
-- ============================================================
