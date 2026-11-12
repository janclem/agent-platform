#!/usr/bin/env bash
# Adapted from Robbie-Palmer/hq (backups/scripts/backup-neon-to-r2.sh), AGPL-3.0.
# Nightly Work Graph backup (ADR 21): pg_dump from Neon's direct endpoint is
# streamed once to two places, age encryption (the only thing uploaded) and
# pg_restore into a throwaway PostgreSQL, which is then checked against
# production. The archive goes to daily/; the first of each ISO week and month
# is copied to weekly/ and monthly/. Values come from Doppler
# work-graph/prd_work_graph_backup when they are not already set.
set +x
set -euo pipefail
umask 077
script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
# shellcheck source=backups/scripts/lib.sh
source "$(dirname "$script_path")/lib.sh"

backup_secrets=(AGE_RECIPIENT CLOUDFLARE_ACCOUNT_ID NEON_DATABASE_URL_UNPOOLED R2_ACCESS_KEY_ID
  R2_SECRET_ACCESS_KEY R2_DATABASE_BACKUPS_BUCKET_NAME)
missing=false
for name in "${backup_secrets[@]}"; do
  [[ -n "${!name:-}" ]] || missing=true
done
if [[ "$missing" == true && "${WORK_GRAPH_DOPPLER_WRAPPED:-}" != "1" ]] && command -v doppler >/dev/null 2>&1; then
  export WORK_GRAPH_DOPPLER_WRAPPED=1
  exec doppler run \
    --project "${DOPPLER_PROJECT:-work-graph}" \
    --config "${DOPPLER_WORK_GRAPH_BACKUP_CONFIG:-prd_work_graph_backup}" \
    --only-secrets "$(IFS=,; echo "${backup_secrets[*]}"),DATABASE_BACKUP_LABEL" \
    --preserve-env=WORK_GRAPH_DOPPLER_WRAPPED \
    -- bash "$script_path"
fi
require_env "${backup_secrets[@]}"
require_command age aws docker jq openssl sha256sum

label="${DATABASE_BACKUP_LABEL:-work-graph}"
if [[ ! "$label" =~ ^[a-z0-9][a-z0-9-]{0,62}$ ]]; then
  echo "DATABASE_BACKUP_LABEL must contain lowercase letters, digits, and hyphens." >&2
  exit 1
fi
if [[ "$NEON_DATABASE_URL_UNPOOLED" == *"-pooler."* ]]; then
  echo "NEON_DATABASE_URL_UNPOOLED points at a pooled Neon endpoint; pg_dump needs the direct one." >&2
  exit 1
fi
if [[ ! "$NEON_DATABASE_URL_UNPOOLED" =~ [?\&]sslmode=verify-full(\&|$) ]] \
  && ! { [[ "$NEON_DATABASE_URL_UNPOOLED" =~ [?\&]sslmode=require(\&|$) ]] \
    && [[ "$NEON_DATABASE_URL_UNPOOLED" =~ [?\&]channel_binding=require(\&|$) ]]; }; then
  echo "NEON_DATABASE_URL_UNPOOLED must use sslmode=verify-full, or sslmode=require with channel_binding=require." >&2
  exit 1
fi

export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION=auto
export AWS_EC2_METADATA_DISABLED=true
endpoint="https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com"
bucket="$R2_DATABASE_BACKUPS_BUCKET_NAME"

timestamp=$(date -u +%Y-%m-%dT%H-%M-%SZ)
year="${timestamp:0:4}"
month="${timestamp:5:2}"
iso_week=$(date -u +%G/W%V)
basename="${label}-${timestamp}.dump.age"
daily_key="daily/${year}/${month}/${basename}"

work_dir=$(mktemp -d)
archive_path="${work_dir}/${basename}"
checksum_path="${archive_path}.sha256"
cleanup() {
  stop_scratch_database
  rm -rf "$work_dir"
}
trap cleanup EXIT INT TERM

object_size() {
  local key="$1" size
  if ! size=$(aws s3api head-object --bucket "$bucket" --key "$key" --endpoint-url "$endpoint" \
    --query ContentLength --output text); then
    echo "Failed to read object metadata: $key" >&2
    return 1
  fi
  if [[ ! "$size" =~ ^[1-9][0-9]*$ ]]; then
    echo "Object is empty or has an invalid size: key=$key size=$size" >&2
    return 1
  fi
  printf '%s\n' "$size"
}

upload() {
  local path="$1" key="$2" remote
  shift 2
  aws s3 cp "$path" "s3://${bucket}/${key}" --endpoint-url "$endpoint" --no-progress --only-show-errors "$@"
  remote=$(object_size "$key")
  if [[ "$(file_size "$path")" != "$remote" ]]; then
    echo "Uploaded size mismatch: $key" >&2
    return 1
  fi
}

copy_object() {
  local source="$1" destination="$2" before after
  before=$(object_size "$source")
  aws s3 cp "s3://${bucket}/${source}" "s3://${bucket}/${destination}" \
    --endpoint-url "$endpoint" --no-progress --only-show-errors
  after=$(object_size "$destination")
  if [[ "$before" != "$after" ]]; then
    echo "Copied size mismatch: $source -> $destination" >&2
    return 1
  fi
}

# Copies this run's archive and checksum into prefix unless that period already
# has a complete pair. Repairs a pair whose checksum copy failed last time.
# Concurrency in the workflow serializes runs, so check-then-copy is safe.
promote() {
  local prefix="$1" listing keys count archives existing existing_name existing_ts
  listing=$(aws s3api list-objects-v2 --bucket "$bucket" --prefix "$prefix" \
    --endpoint-url "$endpoint" --output json)
  keys=$(jq -c '(.Contents // []) | map(.Key)' <<<"$listing")
  count=$(jq length <<<"$keys")
  archives=$(jq '[.[] | select(endswith(".sha256") | not)] | length' <<<"$keys")

  if ((count == 0)); then
    echo "Promoting to ${prefix}"
    copy_object "$daily_key" "${prefix}${basename}"
    copy_object "${daily_key}.sha256" "${prefix}${basename}.sha256"
  elif ((archives == 1 && count == 2)) \
    && jq -e '(map(select(endswith(".sha256") | not))[0] + ".sha256") as $sum | index($sum) != null' <<<"$keys" >/dev/null; then
    echo "${prefix} already has its archive; skipping."
  elif ((archives == 1 && count == 1)); then
    existing=$(jq -r '.[0]' <<<"$keys")
    existing_name="${existing##*/}"
    existing_ts="${existing_name#"${label}-"}"
    echo "Repairing missing checksum for ${existing}"
    copy_object "daily/${existing_ts:0:4}/${existing_ts:5:2}/${existing_name}.sha256" "${existing}.sha256"
  else
    echo "${prefix} holds an unexpected set of objects: $keys" >&2
    return 1
  fi
}

echo "Reading production shape before the dump"
expected_tables=$(production_tables "$NEON_DATABASE_URL_UNPOOLED")
expected_migrations=$(migration_count "$NEON_DATABASE_URL_UNPOOLED")
expected_events=$(psql_url "$NEON_DATABASE_URL_UNPOOLED" -c 'select count(*) from public.events')

echo "Starting a scratch PostgreSQL for the restore drill"
start_scratch_database

echo "Dumping once: encrypting with age and restoring into scratch"
mkfifo "${work_dir}/dump"
age --recipient "$AGE_RECIPIENT" --output "$archive_path" <"${work_dir}/dump" &
age_pid=$!
PGAPPNAME="github-actions-${label}-database-backup" PGURL="$NEON_DATABASE_URL_UNPOOLED" \
  docker run --rm --env PGURL --env PGAPPNAME "$postgres_image" \
  sh -c 'exec pg_dump --dbname "$PGURL" --format=custom --compress=gzip:6 --lock-wait-timeout=30s --no-password' \
  | tee "${work_dir}/dump" \
  | PGURL="$scratch_url" docker run --rm --interactive --env PGURL --network "$drill_network" "$postgres_image" \
    sh -c 'exec pg_restore --exit-on-error --no-owner --no-privileges --dbname "$PGURL"'
wait "$age_pid"

echo "Checking the restored copy"
check_restore "$scratch_url" "$expected_tables" "$expected_migrations" "$expected_events"

(cd "$work_dir" && sha256sum "$basename" >"${basename}.sha256")

echo "Uploading s3://${bucket}/${daily_key}"
upload "$archive_path" "$daily_key"
upload "$checksum_path" "${daily_key}.sha256" --content-type text/plain

promote "weekly/${iso_week}/"
promote "monthly/${year}/${month}/"

echo "Backup completed: ${daily_key} ($(file_size "$archive_path") bytes)"
