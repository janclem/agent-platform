#!/usr/bin/env bash
# Adapted from Robbie-Palmer/hq (workers/work-graph-api/scripts/deploy.sh), AGPL-3.0.
# Deploys the Worker with the Terraform-managed Hyperdrive ID. Locally, the
# Cloudflare deploy token comes from 1Password (op.env) and the Hyperdrive ID
# from Doppler (ADR 23); CI passes all three as environment variables.
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

if [[ "$dry_run" != true ]]; then
  if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
    if [[ "${WORK_GRAPH_OP_WRAPPED:-}" == "1" ]] || ! command -v op >/dev/null 2>&1; then
      echo "Cannot deploy Work Graph: CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID are required." >&2
      exit 1
    fi
    export WORK_GRAPH_OP_WRAPPED=1
    exec op run --env-file op.env -- bash "$script_path"
  fi
  if [[ -z "${WORK_GRAPH_HYPERDRIVE_ID:-}" ]]; then
    if [[ "${WORK_GRAPH_DOPPLER_WRAPPED:-}" == "1" ]] || ! command -v doppler >/dev/null 2>&1; then
      echo "Cannot deploy Work Graph: WORK_GRAPH_HYPERDRIVE_ID is required." >&2
      exit 1
    fi
    export WORK_GRAPH_DOPPLER_WRAPPED=1
    exec doppler run \
      --project "${DOPPLER_PROJECT:-work-graph}" \
      --config "${DOPPLER_WORK_GRAPH_CONFIG:-prd_work_graph}" \
      --only-secrets WORK_GRAPH_HYPERDRIVE_ID \
      --preserve-env=CLOUDFLARE_API_TOKEN,CLOUDFLARE_ACCOUNT_ID,WORK_GRAPH_OP_WRAPPED,WORK_GRAPH_DOPPLER_WRAPPED \
      -- bash "$script_path"
  fi
fi

hyperdrive_id="${WORK_GRAPH_HYPERDRIVE_ID:-00000000000000000000000000000000}"
if [[ ! "$hyperdrive_id" =~ ^[0-9a-f]{32}$ ]]; then
  echo "Cannot deploy Work Graph: WORK_GRAPH_HYPERDRIVE_ID must be a 32-character lowercase hexadecimal ID." >&2
  exit 1
fi
if [[ "$dry_run" != true && "$hyperdrive_id" == "00000000000000000000000000000000" ]]; then
  echo "Cannot deploy Work Graph with the placeholder Hyperdrive ID." >&2
  exit 1
fi

generated_config="$(mktemp ./.wrangler.work-graph.XXXXXX.toml)"
bundle_dir=""
# shellcheck disable=SC2329 # invoked by the trap below
cleanup() {
  unlink "$generated_config" 2>/dev/null || true
  if [[ -n "$bundle_dir" && -d "$bundle_dir" ]]; then
    find "$bundle_dir" -type f -exec unlink {} + 2>/dev/null || true
    find "$bundle_dir" -depth -type d -empty -delete 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

sed "s/00000000000000000000000000000000/$hyperdrive_id/" wrangler.toml >"$generated_config"
chmod 600 "$generated_config"

args=(deploy --config "$generated_config")
if [[ "$dry_run" == true ]]; then
  bundle_dir="$(mktemp -d "${TMPDIR:-/tmp}/work-graph-worker-bundle.XXXXXX")"
  args+=(--dry-run --outdir "$bundle_dir")
fi
pnpm exec wrangler "${args[@]}"
