#!/usr/bin/env bash
# Adapted from Robbie-Palmer/hq (backups/scripts/verify-backup.sh), AGPL-3.0.
# Full restore drill with the private age key (ADR 21): downloads an archive
# from R2 (the newest under daily/ unless a key is given), verifies its
# checksum, decrypts it straight into pg_restore on a throwaway PostgreSQL, and
# checks the result. The key comes from AGE_IDENTITY_FILE or 1Password item
# work-graph-backup-age-key; plaintext is never written to disk.
set +x
set -euo pipefail
umask 077
script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
# shellcheck source=backups/scripts/lib.sh
source "$(dirname "$script_path")/lib.sh"

if (($# > 1)); then
  echo "Usage: restore-drill.sh [object-key]" >&2
  exit 2
fi

drill_secrets=(CLOUDFLARE_ACCOUNT_ID NEON_DATABASE_URL_UNPOOLED R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY
  R2_DATABASE_BACKUPS_BUCKET_NAME)
missing=false
for name in "${drill_secrets[@]}"; do
  [[ -n "${!name:-}" ]] || missing=true
done
if [[ "$missing" == true && "${WORK_GRAPH_DOPPLER_WRAPPED:-}" != "1" ]] && command -v doppler >/dev/null 2>&1; then
  export WORK_GRAPH_DOPPLER_WRAPPED=1
  exec doppler run \
    --project "${DOPPLER_PROJECT:-work-graph}" \
    --config "${DOPPLER_WORK_GRAPH_BACKUP_CONFIG:-prd_work_graph_backup}" \
    --only-secrets "$(IFS=,; echo "${drill_secrets[*]}")" \
    --preserve-env=WORK_GRAPH_DOPPLER_WRAPPED,AGE_IDENTITY_FILE \
    -- bash "$script_path" "$@"
fi
require_env "${drill_secrets[@]}"
require_command age aws docker jq openssl sha256sum

export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION=auto
export AWS_EC2_METADATA_DISABLED=true
endpoint="https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com"
bucket="$R2_DATABASE_BACKUPS_BUCKET_NAME"

work_dir=$(mktemp -d)
cleanup() {
  stop_scratch_database
  rm -rf "$work_dir"
}
trap cleanup EXIT INT TERM

identity="${AGE_IDENTITY_FILE:-}"
if [[ -z "$identity" ]]; then
  require_command op
  identity="${work_dir}/identity.txt"
  op document get work-graph-backup-age-key --vault agent-platform --out-file "$identity" --force >/dev/null
fi

key="${1:-}"
if [[ -z "$key" ]]; then
  key=$(aws s3api list-objects-v2 --bucket "$bucket" --prefix daily/ --endpoint-url "$endpoint" --output json \
    | jq -r '[(.Contents // [])[] | select(.Key | endswith(".dump.age"))] | max_by(.LastModified) | .Key // empty')
  if [[ -z "$key" ]]; then
    echo "No archives under daily/." >&2
    exit 1
  fi
fi
name="${key##*/}"
echo "Drilling s3://${bucket}/${key}"
aws s3 cp "s3://${bucket}/${key}" "${work_dir}/${name}" --endpoint-url "$endpoint" --no-progress --only-show-errors
aws s3 cp "s3://${bucket}/${key}.sha256" "${work_dir}/${name}.sha256" --endpoint-url "$endpoint" --no-progress --only-show-errors
(cd "$work_dir" && sha256sum --check --quiet "${name}.sha256")
echo "Checksum verified"

start_scratch_database
age --decrypt --identity "$identity" "${work_dir}/${name}" \
  | PGURL="$scratch_url" docker run --rm --interactive --env PGURL --network "$drill_network" "$postgres_image" \
    sh -c 'exec pg_restore --exit-on-error --no-owner --no-privileges --dbname "$PGURL"'
echo "Decrypted and restored"

# Production may have migrated since the archive was taken; compare table sets
# only when the migration counts match.
production_migrations=$(migration_count "$NEON_DATABASE_URL_UNPOOLED")
expected_tables=""
if [[ "$(migration_count "$scratch_url")" == "$production_migrations" ]]; then
  expected_tables=$(production_tables "$NEON_DATABASE_URL_UNPOOLED")
else
  echo "Production has migrated since this archive; skipping the table-set comparison."
fi
check_restore "$scratch_url" "$expected_tables" 1 0
echo "Restore drill passed for ${key}"
