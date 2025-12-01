-- 002_indexes.sql
-- Indexes and constraints

-- Ensure pgcrypto for gen_random_uuid on some systems
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Users
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);

-- Profiles
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles (user_id);

-- API Keys
CREATE INDEX IF NOT EXISTS idx_api_keys_user_provider ON api_keys (user_id, provider);

-- Subscriptions
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status ON subscriptions (user_id, status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_dates ON subscriptions (start_date, end_date);

-- Portfolios
CREATE INDEX IF NOT EXISTS idx_portfolios_user ON portfolios (user_id);

-- Holdings
CREATE INDEX IF NOT EXISTS idx_holdings_portfolio ON holdings (portfolio_id);
CREATE INDEX IF NOT EXISTS idx_holdings_symbol_market ON holdings (symbol, market);

-- Transactions
CREATE INDEX IF NOT EXISTS idx_transactions_portfolio ON transactions (portfolio_id);
CREATE INDEX IF NOT EXISTS idx_transactions_symbol_market ON transactions (symbol, market);
CREATE INDEX IF NOT EXISTS idx_transactions_executed_at ON transactions (executed_at);

-- Suggestions
CREATE INDEX IF NOT EXISTS idx_suggestions_user ON suggestions (user_id);
CREATE INDEX IF NOT EXISTS idx_suggestions_portfolio ON suggestions (portfolio_id);
CREATE INDEX IF NOT EXISTS idx_suggestions_valid_until ON suggestions (valid_until);

-- Compliance logs
CREATE INDEX IF NOT EXISTS idx_compliance_logs_user ON compliance_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_compliance_logs_created_at ON compliance_logs (created_at);

-- Payment events
CREATE INDEX IF NOT EXISTS idx_payment_events_user ON payment_events (user_id);
CREATE INDEX IF NOT EXISTS idx_payment_events_subscription ON payment_events (subscription_id);
CREATE INDEX IF NOT EXISTS idx_payment_events_provider_type ON payment_events (provider, event_type);

-- Additional sanity constraints
ALTER TABLE transactions
    ADD CONSTRAINT transactions_qty_nonneg CHECK (quantity >= 0),
    ADD CONSTRAINT transactions_price_nonneg CHECK (price >= 0),
    ADD CONSTRAINT transactions_fees_nonneg CHECK (fees >= 0);

ALTER TABLE holdings
    ADD CONSTRAINT holdings_qty_nonneg CHECK (quantity >= 0),
    ADD CONSTRAINT holdings_avg_cost_nonneg CHECK (avg_cost >= 0);

ALTER TABLE suggestions
    ADD CONSTRAINT suggestions_confidence_range CHECK (confidence >= 0 AND confidence <= 100);

ALTER TABLE subscriptions
    ADD CONSTRAINT subscriptions_price_nonneg CHECK (price_cents >= 0);
