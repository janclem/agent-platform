#!/usr/bin/env bash
# Adapted from Robbie-Palmer/hq (infra/work-graph/scripts/doppler-terraform-env.sh), AGPL-3.0.
# Runs a command with the Work Graph infrastructure credentials from 1Password
# (ADR 23). The HCP token comes from `terraform login`.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${WORK_GRAPH_TERRAFORM_ENV_WRAPPED:-}" != "1" ]]; then
  if ! command -v op >/dev/null 2>&1; then
    echo "Cannot run Work Graph Terraform: the 1Password CLI (op) is required." >&2
    exit 1
  fi
  export WORK_GRAPH_TERRAFORM_ENV_WRAPPED=1
  exec op run --env-file "$script_dir/../op.env" -- bash "$0" "$@"
fi

set_if_unset() {
  local name="$1"
  local value="${2:-}"
  if [[ -z "${!name:-}" && -n "$value" ]]; then
    export "$name=$value"
  fi
}

set_if_unset TF_VAR_cloudflare_account_id "${CLOUDFLARE_ACCOUNT_ID:-}"
set_if_unset TF_VAR_neon_org_id "${NEON_ORG_ID:-}"

exec "$@"
