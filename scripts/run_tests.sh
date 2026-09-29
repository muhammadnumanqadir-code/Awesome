#!/usr/bin/env bash
# Rebuild a scratch database from migrations + seed and run the RLS tests.
#   scripts/run_tests.sh --supabase   # against `supabase start` (db reset, port 54322)
#   scripts/run_tests.sh              # against plain Postgres, with the Supabase shim
#                                     # (defaults: 127.0.0.1, user/password postgres; override via PG* env)
set -euo pipefail
cd "$(dirname "$0")/../supabase"
if [[ "${1:-}" == "--supabase" ]]; then
  npx supabase db reset
  export PGHOST=127.0.0.1 PGPORT=54322 PGUSER=postgres PGPASSWORD=postgres PGDATABASE=postgres
else
  DB=crm_test
  export PGHOST=${PGHOST:-127.0.0.1} PGUSER=${PGUSER:-postgres} PGPASSWORD=${PGPASSWORD:-postgres}
  psql -v ON_ERROR_STOP=1 -q -d postgres -c "drop database if exists $DB" -c "create database $DB"
  export PGDATABASE=$DB
  psql -v ON_ERROR_STOP=1 -q -f tests/00_local_shim.sql
fi
psql -v ON_ERROR_STOP=1 -q -f migrations/0001_schema.sql
psql -v ON_ERROR_STOP=1 -q -f migrations/0002_rls.sql
if [[ "${1:-}" != "--supabase" ]]; then psql -v ON_ERROR_STOP=1 -q -f seed.sql; fi
psql -v ON_ERROR_STOP=1 -q -f tests/rls_tests.sql
