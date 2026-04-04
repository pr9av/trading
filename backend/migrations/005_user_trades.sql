-- ============================================================
--   Migration 005 — User Trade Journal
--   Per-user trade tracking and journaling.
--   Senior's requirement: "We want to maintain the trade
--   history. We want to maintain the journal of the user."
-- ============================================================

-- Enable extensions (needed for uuid_generate_v4)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Trade ledger: every BUY/SELL the user executes
CREATE TABLE IF NOT EXISTS user_trades (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  symbol VARCHAR(20) NOT NULL,
  exchange VARCHAR(10) DEFAULT 'NSE',
  trade_type VARCHAR(4) NOT NULL CHECK (trade_type IN ('BUY', 'SELL')),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  price NUMERIC(12,2) NOT NULL CHECK (price > 0),
  total_amount NUMERIC(14,2) NOT NULL,
  brokerage NUMERIC(10,2) DEFAULT 0,
  order_type VARCHAR(10) DEFAULT 'MARKET',
  notes TEXT,
  executed_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User journal: notes, analysis, sentiment per trade or standalone
CREATE TABLE IF NOT EXISTS user_journal (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  trade_id UUID REFERENCES user_trades(id) ON DELETE SET NULL,
  entry TEXT NOT NULL,
  tags TEXT[] DEFAULT '{}',
  sentiment VARCHAR(10) CHECK (sentiment IN ('bullish', 'bearish', 'neutral')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast per-user lookups
CREATE INDEX IF NOT EXISTS idx_user_trades_user_id ON user_trades(user_id);
CREATE INDEX IF NOT EXISTS idx_user_trades_symbol ON user_trades(user_id, symbol);
CREATE INDEX IF NOT EXISTS idx_user_trades_executed ON user_trades(user_id, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_journal_user_id ON user_journal(user_id);
CREATE INDEX IF NOT EXISTS idx_user_journal_trade ON user_journal(trade_id);
