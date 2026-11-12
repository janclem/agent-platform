#!/usr/bin/env bash
# Adapted from Robbie-Palmer/hq (workers/work-graph-observer/scripts/deploy.sh), AGPL-3.0.
# Installs the observer's runtime secrets and deploys it with the
# Terraform-managed Hyperdrive ID. Missing values are read from Doppler
# work-graph/prd_work_graph (ADR 23), locally through the operator's login and in
# CI through a read-only service token. --dry-run builds without credentials.
set +x
set -euo pipefail
umask 077
script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
cd "$(dirname "$script_path")/.."

dry_run=false
if [[ "${1:-}" == "--dry-run" && $# -eq 1 ]]; then
  dry_run=true
elif (($# > 0)); then
  echo "Usage: deploy.sh [--dry-run]" >&2
  exit 2
fi

runtime_secrets=(GITHUB_WEBHOOK_SECRET GITHUB_APP_ID GITHUB_APP_PRIVATE_KEY GITHUB_ALLOWED_INSTALLATION_IDS
  GITHUB_ALLOWED_REPOSITORIES)
deploy_secrets=(CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID WORK_GRAPH_HYPERDRIVE_ID "${runtime_secrets[@]}")
if [[ "$dry_run" != true ]]; then
  missing=false
  for name in "${deploy_secrets[@]}"; do
    if [[ -z "${!name:-}" ]]; then
      missing=true
    fi
  done
  if [[ "$missing" == true ]]; then
    if [[ "${WORK_GRAPH_DOPPLER_WRAPPED:-}" == "1" ]] || ! command -v doppler >/dev/null 2>&1; then
      echo "Cannot deploy the observer: ${deploy_secrets[*]} are required." >&2
      exit 1
    fi
    export WORK_GRAPH_DOPPLER_WRAPPED=1
    exec doppler run \
      --project "${DOPPLER_PROJECT:-work-graph}" \
      --config "${DOPPLER_WORK_GRAPH_CONFIG:-prd_work_graph}" \
      --only-secrets "$(IFS=,; echo "${deploy_secrets[*]}")" \
      --preserve-env=WORK_GRAPH_DOPPLER_WRAPPED \
      -- bash "$script_path"
  fi
fi

hyperdrive_id="${WORK_GRAPH_HYPERDRIVE_ID:-00000000000000000000000000000000}"
if [[ ! "$hyperdrive_id" =~ ^[0-9a-f]{32}$ ]]; then
  echo "Cannot deploy the observer: WORK_GRAPH_HYPERDRIVE_ID must be a 32-character lowercase hexadecimal ID." >&2
  exit 1
fi
if [[ "$dry_run" != true && "$hyperdrive_id" == "00000000000000000000000000000000" ]]; then
  echo "Cannot deploy the observer with the placeholder Hyperdrive ID." >&2
  exit 1
fi

generated_config="$(mktemp ./.wrangler.work-graph.XXXXXX.toml)"
bundle_dir=""
secret_file=""
# shellcheck disable=SC2329 # invoked by the trap below
cleanup() {
  unlink "$generated_config" 2>/dev/null || true
  [[ -z "$secret_file" ]] || unlink "$secret_file" 2>/dev/null || true
  if [[ -n "$bundle_dir" && -d "$bundle_dir" ]]; then
    find "$bundle_dir" -type f -exec unlink {} + 2>/dev/null || true
    find "$bundle_dir" -depth -type d -empty -delete 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

sed "s/00000000000000000000000000000000/$hyperdrive_id/" wrangler.toml >"$generated_config"
chmod 600 "$generated_config"

if [[ "$dry_run" == true ]]; then
  bundle_dir="$(mktemp -d "${TMPDIR:-/tmp}/work-graph-observer-bundle.XXXXXX")"
  pnpm exec wrangler deploy --config "$generated_config" --dry-run --outdir "$bundle_dir"
  exit
fi

secret_file="$(mktemp "${TMPDIR:-/tmp}/work-graph-observer-secrets.XXXXXX")"
jq -n '{GITHUB_WEBHOOK_SECRET: env.GITHUB_WEBHOOK_SECRET, GITHUB_APP_ID: env.GITHUB_APP_ID,
  GITHUB_APP_PRIVATE_KEY: env.GITHUB_APP_PRIVATE_KEY,
  GITHUB_ALLOWED_INSTALLATION_IDS: env.GITHUB_ALLOWED_INSTALLATION_IDS,
  GITHUB_ALLOWED_REPOSITORIES: env.GITHUB_ALLOWED_REPOSITORIES}' >"$secret_file"
pnpm exec wrangler secret bulk "$secret_file" --config "$generated_config"
pnpm exec wrangler deploy --config "$generated_config"
