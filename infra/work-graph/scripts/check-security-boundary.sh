#!/usr/bin/env bash
# Adapted from Robbie-Palmer/hq (infra/work-graph/scripts/check-security-boundary.sh), AGPL-3.0.
# Static checks that generated credentials stay out of Terraform configuration.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

for script in scripts/*.sh; do
  bash -n "$script"
done

forbidden_resource='resource[[:space:]]+"(neon_project|cloudflare_hyperdrive_config|cloudflare_(zero_trust_)?access_service_token|cloudflare_workers?_secret)"'
if grep -nE "$forbidden_resource" ./*.tf; then
  echo "Credential-bearing provider resources are forbidden in the Work Graph Terraform root." >&2
  exit 1
fi

if grep -nE 'database_password|connection_uri|client_secret[[:space:]]*=' ./*.tf; then
  echo "A credential-bearing Terraform expression crossed the Work Graph state boundary." >&2
  exit 1
fi

if grep -rnE -- '--arg[[:space:]]+(password|database_url|client_id|client_secret)' scripts; then
  echo "Generated credentials must reach jq through protected files, not process arguments." >&2
  exit 1
fi

if grep -rnE '^(database_password|database_url|service_token_client_id|service_token_secret)=' scripts; then
  echo "Generated credentials must not be retained in shell variables." >&2
  exit 1
fi

if grep -vE '^(#|$|[A-Z_]+=op://)' op.env; then
  echo "op.env may contain only 1Password references." >&2
  exit 1
fi

echo "Work Graph infrastructure keeps generated credentials outside Terraform configuration."
