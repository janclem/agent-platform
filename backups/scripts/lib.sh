# shellcheck shell=bash
# Adapted from Robbie-Palmer/hq (backups/scripts), AGPL-3.0.
# Shared helpers for the Work Graph backup and restore-drill scripts. Source it.
# PostgreSQL 17.10 client tools from the official image, pinned by digest, to
# match the Neon project's major version.
postgres_image="postgres@sha256:742f40ea20b9ff2ff31db5458d127452988a2164df9e17441e191f3b72252193"

require_env() {
  local name
  for name in "$@"; do
    if [[ -z "${!name:-}" ]]; then
      echo "Missing required environment variable: $name" >&2
      exit 1
    fi
  done
}

require_command() {
  local name
  for name in "$@"; do
    if ! command -v "$name" >/dev/null 2>&1; then
      echo "Missing required command: $name" >&2
      exit 1
    fi
  done
}

file_size() {
  wc -c <"$1" | tr -d '[:space:]'
}

# Runs psql in the pinned image. The connection string travels in PGURL, never
# in process arguments. Extra arguments go to psql.
psql_url() {
  local url="$1"
  shift
  PGURL="$url" docker run --rm --interactive --env PGURL ${drill_network:+--network "$drill_network"} \
    "$postgres_image" sh -c 'exec psql "$PGURL" -v ON_ERROR_STOP=1 -X -q -At "$@"' sh "$@"
}

# Starts an empty PostgreSQL 17 container for a restore drill and sets
# scratch_url. Call stop_scratch_database from an EXIT trap.
start_scratch_database() {
  drill_name="work-graph-restore-drill-$$"
  drill_network="$drill_name"
  local password
  password=$(openssl rand -hex 24)
  docker network create "$drill_network" >/dev/null
  docker run --detach --name "$drill_name" --network "$drill_network" \
    --env POSTGRES_PASSWORD="$password" --env POSTGRES_DB=work_graph \
    "$postgres_image" >/dev/null
  scratch_url="postgresql://postgres:${password}@${drill_name}:5432/work_graph"
  local _
  for _ in $(seq 1 30); do
    if docker exec "$drill_name" pg_isready -U postgres -d work_graph -q 2>/dev/null \
      && psql_url "$scratch_url" -c 'select 1' >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "Scratch PostgreSQL did not become ready." >&2
  return 1
}

stop_scratch_database() {
  if [[ -n "${drill_name:-}" ]]; then
    docker rm --force "$drill_name" >/dev/null 2>&1 || true
    docker network rm "$drill_network" >/dev/null 2>&1 || true
  fi
}

# Prints "schema.table rows" for every base table, sorted, as drill evidence.
table_row_counts() {
  psql_url "$1" <<'SQL'
select format('select %L || '' '' || count(*) from %I.%I;', table_schema || '.' || table_name, table_schema, table_name)
from information_schema.tables
where table_type = 'BASE TABLE' and table_schema not in ('pg_catalog', 'information_schema')
order by table_schema, table_name
\gexec
SQL
}

migration_count() {
  psql_url "$1" -c 'select count(*) from drizzle.__drizzle_migrations'
}

# Checks a restored scratch database against counts taken from production
# before the dump: every table and migration must be present, and the
# append-only event log must not have shrunk.
check_restore() {
  local scratch="$1" expected_tables="$2" expected_migrations="$3" expected_events="$4"
  local restored_tables restored_migrations restored_events missing

  restored_tables=$(table_row_counts "$scratch")
  printf '%s\n' "$restored_tables" | sed 's/^/  /'
  missing=$(comm -23 <(printf '%s\n' "$expected_tables" | sort) \
    <(printf '%s\n' "$restored_tables" | cut -d' ' -f1 | sort))
  if [[ -n "$missing" ]]; then
    echo "Restore is missing tables: $missing" >&2
    return 1
  fi

  restored_migrations=$(migration_count "$scratch")
  if ((restored_migrations == 0 || restored_migrations < expected_migrations)); then
    echo "Restore has $restored_migrations migrations; production had $expected_migrations." >&2
    return 1
  fi

  restored_events=$(psql_url "$scratch" -c 'select count(*) from public.events')
  if ((restored_events < expected_events)); then
    echo "Restore has $restored_events events; production had $expected_events." >&2
    return 1
  fi
  echo "Restore check passed: $(printf '%s\n' "$restored_tables" | wc -l | tr -d ' ') tables, $restored_migrations migrations, $restored_events events."
}

production_tables() {
  psql_url "$1" -c "select table_schema || '.' || table_name from information_schema.tables where table_type = 'BASE TABLE' and table_schema not in ('pg_catalog', 'information_schema') order by 1"
}
