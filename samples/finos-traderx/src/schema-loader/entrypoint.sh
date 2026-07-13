#!/bin/sh
set -eu

# Applies the TraderX schema and seed data to the provisioned Azure PostgreSQL
# database. Azure ignores the postgreSqlDatabases `initSql`, so the schema must
# be loaded explicitly. The SQL is idempotent (DROP TABLE IF EXISTS ... first),
# so re-running is safe.

: "${PGHOST:?PGHOST is required}"
: "${PGPORT:=5432}"
: "${PGDATABASE:?PGDATABASE is required}"
: "${PGUSER:?PGUSER is required}"
: "${PGPASSWORD:?PGPASSWORD is required}"
: "${PGSSLMODE:=require}"

export PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD PGSSLMODE

echo "schema-loader: waiting for PostgreSQL at ${PGHOST}:${PGPORT} (sslmode=${PGSSLMODE})..."
until pg_isready -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" >/dev/null 2>&1; do
  echo "schema-loader: database not ready yet, retrying in 5s..."
  sleep 5
done

echo "schema-loader: database reachable, applying schema..."
until psql -v ON_ERROR_STOP=1 -f /schema-loader/schema.sql; do
  echo "schema-loader: schema apply failed, retrying in 5s..."
  sleep 5
done

echo "SCHEMA_LOAD_COMPLETE"

# Stay alive so the container stays Ready as a long-running resource.
exec sleep infinity
