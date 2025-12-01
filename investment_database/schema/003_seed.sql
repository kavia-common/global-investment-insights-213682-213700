-- 003_seed.sql
-- Minimal demo seed data

-- Create demo user
INSERT INTO users (id, email, password_hash, is_active)
VALUES (
    gen_random_uuid(),
    'demo@example.com',
    '$2b$12$abcdefghijklmnopqrstuv'::text, -- placeholder bcrypt-like hash
    TRUE
)
ON CONFLICT (email) DO NOTHING;

-- Link profile to the created/existing user
WITH u AS (
    SELECT id FROM users WHERE email = 'demo@example.com'
)
INSERT INTO profiles (user_id, full_name, country, risk_tolerance, investment_goal, preferences)
SELECT id, 'Demo User', 'US', 'medium', 'Wealth Accumulation', '{"theme":"Ocean Professional"}'::jsonb
FROM u
ON CONFLICT (user_id) DO NOTHING;

-- Create a portfolio for the demo user
WITH u AS (
    SELECT id FROM users WHERE email = 'demo@example.com'
)
INSERT INTO portfolios (user_id, name, description, base_currency)
SELECT id, 'Demo Portfolio', 'Sample portfolio for demo user', 'USD'
FROM u
ON CONFLICT DO NOTHING;

-- Add a holding
WITH p AS (
    SELECT id FROM portfolios WHERE name = 'Demo Portfolio' LIMIT 1
)
INSERT INTO holdings (portfolio_id, symbol, market, quantity, avg_cost, currency)
SELECT id, 'AAPL', 'US', 10.0, 150.00, 'USD' FROM p
ON CONFLICT DO NOTHING;

-- Add a transaction
WITH p AS (
    SELECT id FROM portfolios WHERE name = 'Demo Portfolio' LIMIT 1
)
INSERT INTO transactions (portfolio_id, symbol, market, txn_type, quantity, price, fees, currency, executed_at, metadata)
SELECT id, 'AAPL', 'US', 'buy', 10.0, 150.00, 1.00, 'USD', now() - interval '1 day', '{"source":"seed"}'::jsonb FROM p;

-- Seed a subscription
WITH u AS (
    SELECT id FROM users WHERE email = 'demo@example.com'
)
INSERT INTO subscriptions (user_id, plan, status, renewal_period, price_cents, currency)
SELECT id, 'basic', 'active', 'monthly', 999, 'USD' FROM u
ON CONFLICT DO NOTHING;

-- Seed an API key metadata (no real secrets)
WITH u AS (
    SELECT id FROM users WHERE email = 'demo@example.com'
)
INSERT INTO api_keys (user_id, provider, key_id, secret_encrypted, metadata, active)
SELECT id, 'alpha_vantage', 'DEMO_KEY', 'ENCRYPTED_SECRET_PLACEHOLDER', '{"note":"demo only"}'::jsonb, TRUE
FROM u
ON CONFLICT DO NOTHING;

-- Seed a suggestion
WITH u AS (SELECT id FROM users WHERE email = 'demo@example.com'),
     p AS (SELECT id FROM portfolios WHERE name = 'Demo Portfolio')
INSERT INTO suggestions (user_id, portfolio_id, symbol, market, action, confidence, rationale, constraints, valid_until)
SELECT u.id, p.id, 'MSFT', 'US', 'buy', 82.5, 'Strong fundamentals and momentum.', '{"rule":"demo"}'::jsonb, now() + interval '7 days'
FROM u, p
ON CONFLICT DO NOTHING;

-- Seed a compliance log
WITH u AS (SELECT id FROM users WHERE email = 'demo@example.com')
INSERT INTO compliance_logs (user_id, action, entity_type, details)
SELECT id, 'suggestion_generated', 'suggestions', '{"reason":"seed"}'::jsonb FROM u;

-- Seed a payment event
WITH u AS (SELECT id FROM users WHERE email = 'demo@example.com'),
     s AS (SELECT id FROM subscriptions WHERE user_id IN (SELECT id FROM u) LIMIT 1)
INSERT INTO payment_events (user_id, subscription_id, provider, event_type, amount_cents, currency, external_reference, payload)
SELECT u.id, s.id, 'stripe', 'invoice_paid', 999, 'USD', 'inv_demo_001', '{"status":"paid"}'::jsonb
FROM u, s
ON CONFLICT DO NOTHING;
