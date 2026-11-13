#!/usr/bin/env bash
# Publishes .work-graph/delivery-targets.yaml to the Work Graph API. Missing
# values are read from Doppler work-graph/prd_work_graph (ADR 23): locally through
# the operator's login, in CD through the environment's read-only service token.
set +x
set -euo pipefail
script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
cd "$(dirname "$script_path")/.."

publish_secrets=(CF_ACCESS_CLIENT_ID CF_ACCESS_CLIENT_SECRET WORK_GRAPH_API_URL WORK_GRAPH_CF_ACCESS_ALLOWED_ORIGINS)
missing=false
for name in "${publish_secrets[@]}"; do
  [[ -n "${!name:-}" ]] || missing=true
done
if [[ "$missing" == true && "${WORK_GRAPH_DOPPLER_WRAPPED:-}" != "1" ]] && command -v doppler >/dev/null 2>&1; then
  export WORK_GRAPH_DOPPLER_WRAPPED=1
  exec doppler run \
    --project "${DOPPLER_PROJECT:-work-graph}" \
    --config "${DOPPLER_WORK_GRAPH_CONFIG:-prd_work_graph}" \
    --only-secrets "$(IFS=,; echo "${publish_secrets[*]}")" \
    --preserve-env=WORK_GRAPH_DOPPLER_WRAPPED \
    -- bash "$script_path"
fi

pnpm exec tsx scripts/publish-delivery-targets.ts
