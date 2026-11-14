#!/usr/bin/env bash
# Validate the coordinator's admission policy (ADR 26), so a malformed edit fails CI
# instead of confusing the controller thread that reads it on every event.
#   check-coordinator-policy.sh <policy.json>              validate one policy file
#   check-coordinator-policy.sh --self-test <policy.json>  also prove malformed variants fail
set -euo pipefail

# Prints one line per problem; prints nothing for a valid policy.
read -r -d '' rules <<'JQ' || true
def keys_exactly($want; $where):
  (keys - $want | map("\($where): unknown key \(.)")) +
  ($want - keys | map("\($where): missing key \(.)"));
def str: type == "string" and length > 0;

if type != "object" then ["policy: must be a JSON object"] else
  keys_exactly(["schemaVersion", "policyId", "revision", "decisionRecord", "repository",
    "author", "trigger", "excludedPathPrefixes", "concurrency", "workItem"]; "policy")
  + (if .schemaVersion == 1 then [] else ["schemaVersion: must be 1"] end)
  + (if .policyId == "agent-coordinator:renovate-repair" then []
     else ["policyId: must be agent-coordinator:renovate-repair"] end)
  + (if (.revision | type) == "number" and .revision >= 1 and .revision == (.revision | floor) then []
     else ["revision: must be a positive integer"] end)
  + (if (.decisionRecord | str) and (.decisionRecord | test("^docs/adr/[0-9]{4}-[a-z0-9-]+\\.md$")) then []
     else ["decisionRecord: must be a docs/adr/NNNN-*.md path"] end)
  + (if (.repository | str) and (.repository | test("^[a-z0-9_.-]+/[a-z0-9_.-]+$")) then []
     else ["repository: must be a lower-case owner/name"] end)
  + (if (.author | type) != "object" then ["author: must be an object"] else
      (.author | keys_exactly(["login", "type"]; "author"))
      + (if .author.login | str then [] else ["author.login: must be a non-empty string"] end)
      + (if .author.type == "Bot" then [] else ["author.type: must be Bot"] end)
    end)
  + (if (.trigger | type) != "object" then ["trigger: must be an object"] else
      (.trigger | keys_exactly(["webhookEvent", "webhookAction", "webhookConclusions",
        "pullRequestState", "requiredCheckBuckets"]; "trigger"))
      + (if .trigger.webhookEvent == "workflow_run" then [] else ["trigger.webhookEvent: must be workflow_run"] end)
      + (if .trigger.webhookAction == "completed" then [] else ["trigger.webhookAction: must be completed"] end)
      + (if .trigger.webhookConclusions == ["failure"] then [] else ["trigger.webhookConclusions: must be [\"failure\"]"] end)
      + (if .trigger.pullRequestState == "open" then [] else ["trigger.pullRequestState: must be open"] end)
      + (if .trigger.requiredCheckBuckets == ["fail"] then [] else ["trigger.requiredCheckBuckets: must be [\"fail\"]"] end)
    end)
  + (if (.excludedPathPrefixes | type) != "array" then ["excludedPathPrefixes: must be an array"] else
      (.excludedPathPrefixes | map(select((str | not) or (test("^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*/$") | not)))
        | map("excludedPathPrefixes: \(tojson) must be a relative directory ending in /"))
      + (if (.excludedPathPrefixes | length) == (.excludedPathPrefixes | unique | length) then []
         else ["excludedPathPrefixes: entries must be unique"] end)
      + (["homelab/", "infra/"] - .excludedPathPrefixes
         | map("excludedPathPrefixes: must include \(.) (ADR 26)"))
    end)
  + (if (.concurrency | type) != "object" then ["concurrency: must be an object"] else
      (.concurrency | keys_exactly(["maximumActiveWorkers"]; "concurrency"))
      + (if .concurrency.maximumActiveWorkers == 1 then []
         else ["concurrency.maximumActiveWorkers: must be 1 (ADR 26)"] end)
    end)
  + (if (.workItem | type) != "object" then ["workItem: must be an object"] else
      (.workItem | keys_exactly(["idPrefix", "idTemplate"]; "workItem"))
      + (if (.workItem.idPrefix | str) and (.workItem.idPrefix | test("^[a-z][a-z0-9-]*-$")) then []
         else ["workItem.idPrefix: must be lower-case and end in -"] end)
      + (if (.workItem.idTemplate | str)
            and (.workItem.idTemplate == "\(.workItem.idPrefix){repositoryName}-{pullRequestNumber}") then []
         else ["workItem.idTemplate: must be <idPrefix>{repositoryName}-{pullRequestNumber}"] end)
    end)
end | .[]
JQ

# Prints the policy's problems and returns non-zero when there are any.
check() {
  local problems
  if ! problems=$(jq -r "$rules" "$1" 2>&1); then
    echo "$1: not valid JSON: $problems"
    return 1
  fi
  [[ -z "$problems" ]] && return 0
  while IFS= read -r line; do echo "$1: $line"; done <<<"$problems"
  return 1
}

self_test=false
if [[ "${1:-}" == "--self-test" ]]; then self_test=true; shift; fi
[[ $# -eq 1 ]] || { echo "usage: $0 [--self-test] <policy.json>" >&2; exit 2; }
policy=$1

status=0
if check "$policy"; then
  record=$(jq -r .decisionRecord "$policy")
  [[ -f "$record" ]] || { echo "$policy: decisionRecord $record does not exist"; status=1; }
else
  echo "::error file=$policy::coordinator policy is invalid"
  status=1
fi

if $self_test; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  # Each mutation of the valid policy must be rejected.
  mutations=(
    'del(.repository)'
    '.extra = true'
    '.excludedPathPrefixes -= ["infra/"]'
    '.excludedPathPrefixes += ["/etc/"]'
    '.concurrency.maximumActiveWorkers = 2'
    '.trigger.requiredCheckBuckets = ["pending"]'
    '.author.login = ""'
    '.workItem.idTemplate = "renovate-repair-{pullRequestNumber}"'
    '.revision = "1"'
  )
  for m in "${mutations[@]}"; do
    jq "$m" "$policy" >"$tmp/policy.json"
    if check "$tmp/policy.json" >/dev/null; then
      echo "::error::self-test: mutation '$m' was accepted"
      status=1
    fi
  done
  printf '{"schemaVersion": 1,' >"$tmp/policy.json"
  if check "$tmp/policy.json" >/dev/null; then
    echo "::error::self-test: truncated JSON was accepted"
    status=1
  fi
  [[ $status -eq 0 ]] && echo "self-test: ${#mutations[@]} malformed policies and truncated JSON rejected"
fi

[[ $status -eq 0 ]] && echo "$policy: valid"
exit "$status"
