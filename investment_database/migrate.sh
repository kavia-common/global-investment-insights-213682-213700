#!/bin/bash
set -euo pipefail

# Migration script: applies all schema/*.sql files in lexical order
# Connection precedence:
# 1) db_connection.txt (expects: a single line psql connection string or full psql command)
# 2) db_visualizer/postgres.env (POSTGRES_* variables)
# 3) Defaults per notes: host localhost, port 5000, DB myapp, user appuser, password dbuser123

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_DIR="${BASE_DIR}/schema"

DEFAULT_HOST="localhost"
DEFAULT_PORT="5000"
DEFAULT_DB="myapp"
DEFAULT_USER="appuser"
DEFAULT_PASSWORD="dbuser123"

PSQL_CMD=""

# Helper to echo section header
section() { echo -e "\n== $1 =="; }

# Detect connection via db_connection.txt
if [[ -f "${BASE_DIR}/db_connection.txt" ]]; then
  LINE="$(cat "${BASE_DIR}/db_connection.txt" | tr -d '\n' | tr -d '\r')"
  if [[ "$LINE" == psql* ]]; then
    PSQL_CMD="$LINE"
  else
    # If line is just a URL, wrap it
    PSQL_CMD="psql ${LINE}"
  fi
fi

# Load env from db_visualizer/postgres.env if present
if [[ -z "${PSQL_CMD}" && -f "${BASE_DIR}/db_visualizer/postgres.env" ]]; then
  # shellcheck disable=SC1091
  source "${BASE_DIR}/db_visualizer/postgres.env"
fi

# Build PSQL from env or defaults if still empty
if [[ -z "${PSQL_CMD}" ]]; then
  HOST="${POSTGRES_HOST:-$DEFAULT_HOST}"
  PORT="${POSTGRES_PORT:-$DEFAULT_PORT}"
  DB="${POSTGRES_DB:-$DEFAULT_DB}"
  USER="${POSTGRES_USER:-$DEFAULT_USER}"
  PASSWORD="${POSTGRES_PASSWORD:-$DEFAULT_PASSWORD}"
  export PGPASSWORD="${PASSWORD}"
  PSQL_CMD="psql -h ${HOST} -p ${PORT} -U ${USER} -d ${DB}"
else
  # If using URL form, try to export password from URL for pgcrypto or future clients
  if [[ "$PSQL_CMD" =~ postgresql://([^:]+):([^@]+)@([^:/]+):([0-9]+)/([^[:space:]]+) ]]; then
    export PGPASSWORD="${BASH_REMATCH[2]}"
  fi
fi

section "Using connection"
echo "$PSQL_CMD" | sed 's/\(postgresql:\/\/[^:]\{1,\}:\)[^@]\{1,\}\(@.*\)/\1********\2/' || true

# Verify connectivity
section "Checking database connectivity"
if ! echo "\echo Connected OK" | ${PSQL_CMD} > /dev/null 2>&1; then
  echo "Error: Cannot connect to PostgreSQL with provided credentials."
  echo "Checked db_connection.txt, db_visualizer/postgres.env, and defaults."
  exit 1
fi
echo "✓ Connection successful"

# Ensure pgcrypto extension exists (for gen_random_uuid)
section "Ensuring required extensions"
echo "CREATE EXTENSION IF NOT EXISTS pgcrypto;" | ${PSQL_CMD}

# Apply migrations
section "Applying migrations"
if [[ ! -d "${SCHEMA_DIR}" ]]; then
  echo "No schema directory found at ${SCHEMA_DIR}"
  exit 1
fi

APPLIED=0
for file in $(ls "${SCHEMA_DIR}"/*.sql | sort); do
  fname="$(basename "$file")"
  echo "--> Applying ${fname}"
  ${PSQL_CMD} -v ON_ERROR_STOP=1 -f "$file"
  echo "    ✓ ${fname} applied"
  APPLIED=$((APPLIED+1))
done

echo -e "\nMigrations complete. Files applied: ${APPLIED}"
