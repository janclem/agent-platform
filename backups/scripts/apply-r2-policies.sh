#!/usr/bin/env bash
# Applies the backup bucket's lifecycle and lock rules from backups/r2-*.json.
# The Cloudflare Terraform provider v4 cannot manage them (ADR 21). Uses the
# Work Graph infrastructure token from 1Password (infra/work-graph/op.env), and
# replaces the bucket's rules wholesale, so re-running it is safe.
set +x
set -euo pipefail
script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
repo_root="$(cd "$(dirname "$script_path")/../.." && pwd)"
bucket="${R2_DATABASE_BACKUPS_BUCKET_NAME:-work-graph-database-backups}"

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
  if [[ "${WORK_GRAPH_OP_WRAPPED:-}" == "1" ]]; then
    echo "CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID are required." >&2
    exit 1
  fi
  export WORK_GRAPH_OP_WRAPPED=1
  exec op run --env-file "${repo_root}/infra/work-graph/op.env" -- bash "$script_path"
fi

wrangler() {
  pnpm --dir "${repo_root}/services/work-graph-api" exec wrangler "$@"
}
wrangler r2 bucket lifecycle set "$bucket" --file "${repo_root}/backups/r2-lifecycle.json" --force
wrangler r2 bucket lock set "$bucket" --file "${repo_root}/backups/r2-lock.json" --force
wrangler r2 bucket lifecycle list "$bucket"
wrangler r2 bucket lock list "$bucket"
