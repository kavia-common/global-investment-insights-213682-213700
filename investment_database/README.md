# Investment Database

PostgreSQL schema and migration tooling for the Global Investment Insights app.

## Connection defaults

Unless overridden by files or environment, database connection uses:
- Host: localhost
- Port: 5000
- Database: myapp
- User: appuser
- Password: dbuser123

The startup script writes:
- db_connection.txt: a psql connection command
- db_visualizer/postgres.env: POSTGRES_* variables for the DB viewer

## Files

- startup.sh: Starts PostgreSQL, creates DB/user, writes connection info, and runs migrations.
- migrate.sh: Applies SQL files in `schema/` in lexical order using psql.
- schema/001_init.sql: Creates core tables and trigger to maintain updated_at.
- schema/002_indexes.sql: Adds indexes, extensions, and constraints.
- schema/003_seed.sql: Inserts minimal demo data for a working demo.

## Migration behavior

Order of precedence for connection:
1. db_connection.txt (either a psql command line or a `psql postgresql://...` form)
2. db_visualizer/postgres.env (exports POSTGRES_* variables)
3. Defaults in this README

migrate.sh validates connectivity and applies:
```
schema/001_init.sql
schema/002_indexes.sql
schema/003_seed.sql
```
with `-v ON_ERROR_STOP=1` so it stops on errors.

## Schema overview

- users: accounts with email, password_hash, is_active, timestamps.
- profiles: user profile and onboarding preferences (1:1 with users).
- api_keys: external API credentials per provider for a user.
- subscriptions: plan, status, billing info.
- portfolios: named collections of holdings for a user.
- holdings: current positions (symbol, market, quantity, avg_cost).
- transactions: ledger of trades/activities.
- suggestions: investment recommendations and metadata.
- compliance_logs: audit trail for compliance related actions.
- payment_events: billing and payment records.

Common patterns:
- UUID primary keys (gen_random_uuid via pgcrypto).
- updated_at managed by trigger.
- JSONB for flexible metadata.

## Running locally

1) Start PostgreSQL and initialize:
```
./startup.sh
```

2) If you need to re-run migrations:
```
./migrate.sh
```

3) Connect:
```
source db_visualizer/postgres.env
psql -h localhost -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB"
```

## Notes

- Migrations are idempotent given IF NOT EXISTS usage and constraints designed to avoid duplicate inserts for seed data.
- Ensure pgcrypto extension exists; scripts create it if missing.
