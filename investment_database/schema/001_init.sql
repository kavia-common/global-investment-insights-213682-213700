-- 001_init.sql
-- Initial schema for Investment Database

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Profiles table (1:1 with users)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    full_name VARCHAR(255),
    country VARCHAR(100),
    risk_tolerance VARCHAR(50), -- e.g., low, medium, high
    investment_goal VARCHAR(255),
    preferences JSONB, -- additional profile fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- API Keys (per user for external integrations)
CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(100) NOT NULL, -- e.g., alpaca, zerodha, alpha_vantage
    key_id TEXT NOT NULL,
    secret_encrypted TEXT NOT NULL,
    metadata JSONB,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, provider)
);

-- Subscriptions (plan and status)
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan VARCHAR(100) NOT NULL, -- e.g., free, basic, pro
    status VARCHAR(50) NOT NULL, -- e.g., active, past_due, canceled
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    renewal_period VARCHAR(50) NOT NULL DEFAULT 'monthly', -- monthly, yearly
    price_cents INTEGER NOT NULL DEFAULT 0,
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Portfolios (owned by users)
CREATE TABLE IF NOT EXISTS portfolios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    base_currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Holdings (positions within a portfolio)
CREATE TABLE IF NOT EXISTS holdings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    portfolio_id UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    symbol VARCHAR(50) NOT NULL, -- e.g., AAPL, INFY.NS
    market VARCHAR(50) NOT NULL, -- e.g., US, IN
    quantity NUMERIC(20, 6) NOT NULL DEFAULT 0,
    avg_cost NUMERIC(20, 6) NOT NULL DEFAULT 0,
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (portfolio_id, symbol, market)
);

-- Transactions (trade history)
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    portfolio_id UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
    symbol VARCHAR(50) NOT NULL,
    market VARCHAR(50) NOT NULL,
    txn_type VARCHAR(20) NOT NULL, -- buy, sell, dividend, fee, deposit, withdrawal
    quantity NUMERIC(20, 6) NOT NULL DEFAULT 0,
    price NUMERIC(20, 6) NOT NULL DEFAULT 0,
    fees NUMERIC(20, 6) NOT NULL DEFAULT 0,
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    executed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Suggestions (investment recommendations)
CREATE TABLE IF NOT EXISTS suggestions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    portfolio_id UUID REFERENCES portfolios(id) ON DELETE SET NULL,
    symbol VARCHAR(50) NOT NULL,
    market VARCHAR(50) NOT NULL,
    action VARCHAR(20) NOT NULL, -- buy, sell, hold, rebalance
    confidence NUMERIC(5,2) NOT NULL DEFAULT 0, -- 0-100 scale
    rationale TEXT,
    constraints JSONB, -- e.g., compliance constraints or rules applied
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until TIMESTAMPTZ
);

-- Compliance logs (audit trail)
CREATE TABLE IF NOT EXISTS compliance_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL, -- e.g., suggestion_generated, trade_blocked
    entity_type VARCHAR(100),
    entity_id UUID,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Payment events (billing and payments)
CREATE TABLE IF NOT EXISTS payment_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    provider VARCHAR(100) NOT NULL, -- e.g., stripe, razorpay
    event_type VARCHAR(100) NOT NULL, -- e.g., subscription_created, invoice_paid
    amount_cents INTEGER NOT NULL DEFAULT 0,
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    external_reference VARCHAR(255),
    payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger functions to update updated_at column
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach triggers to tables with updated_at
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT table_name
        FROM information_schema.columns
        WHERE column_name = 'updated_at'
          AND table_schema = 'public'
    LOOP
        EXECUTE format('
            DO $inner$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_trigger
                    WHERE tgname = %L
                ) THEN
                    CREATE TRIGGER %I
                    BEFORE UPDATE ON %I
                    FOR EACH ROW
                    EXECUTE FUNCTION set_updated_at();
                END IF;
            END
            $inner$;
        ', r.table_name || '_set_updated_at', r.table_name || '_set_updated_at', r.table_name);
    END LOOP;
END;
$$;
