#!/usr/bin/env bash
# Records a successful Work Graph Terraform apply as a GitHub deployment to
# production-work-graph-infra, the delivery signal for infra/work-graph changes
# (ADR 19). It records only from a clean checkout of the current origin/main, so
# the deployment's commit is exactly what was applied; otherwise it explains why
# and exits 0, leaving the apply result unchanged. It then records the earlier
# main commits the apply also delivered. Uses the operator's `gh` login.
set -euo pipefail

repository="${GITHUB_REPOSITORY:-janclem/agent-platform}"
environment="production-work-graph-infra"

skip() {
  echo "Not recording a $environment deployment: $1" >&2
  exit 0
}

command -v gh >/dev/null 2>&1 || skip "gh is not installed."
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || skip "the checkout has uncommitted changes."
git fetch --quiet origin main || skip "origin/main could not be fetched."
head="$(git rev-parse HEAD)"
[[ "$head" == "$(git rev-parse origin/main)" ]] || skip "HEAD is not origin/main."

deployment_id="$(
  jq -n --arg environment "$environment" '{ref: "main", environment: $environment,
    auto_merge: false, required_contexts: [], production_environment: true,
    description: "mise run work-graph-infra:apply"}' |
    gh api "repos/$repository/deployments" --input - --jq 'select(.sha != null) | "\(.id) \(.sha)"'
)"
read -r id sha <<<"$deployment_id"
if [[ "$sha" != "$head" ]]; then
  echo "Deployment $id points at $sha, not the applied $head; marking it failed." >&2
  gh api "repos/$repository/deployments/$id/statuses" -f state=failure \
    -f description="main moved during recording" >/dev/null
  exit 1
fi
gh api "repos/$repository/deployments/$id/statuses" -f state=success \
  -f description="Terraform apply succeeded" >/dev/null
echo "Recorded $environment deployment $id for $head."

# The apply also delivered earlier main commits whose own apply never ran.
mise run work-graph:record-covered-deployments "$environment"
