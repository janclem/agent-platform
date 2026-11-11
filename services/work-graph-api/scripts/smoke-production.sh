#!/usr/bin/env bash
# Adapted from Robbie-Palmer/hq (workers/work-graph-api/scripts/smoke-production.sh), AGPL-3.0.
# Reads the production queue through Cloudflare Access with the agents' service
# token from Doppler (ADR 23).
set +x
set -euo pipefail
umask 077

if [[ "${WORK_GRAPH_DOPPLER_WRAPPED:-}" != "1" ]]; then
  missing=false
  for name in CF_ACCESS_CLIENT_ID CF_ACCESS_CLIENT_SECRET WORK_GRAPH_API_URL; do
    if [[ -z "${!name:-}" ]]; then
      missing=true
    fi
  done
  if [[ "$missing" == true ]]; then
    if ! command -v doppler >/dev/null 2>&1; then
      echo "Cannot smoke-test Work Graph: required values are missing and doppler is unavailable." >&2
      exit 1
    fi
    export WORK_GRAPH_DOPPLER_WRAPPED=1
    exec doppler run \
      --project "${DOPPLER_PROJECT:-work-graph}" \
      --config "${DOPPLER_WORK_GRAPH_CONFIG:-prd_work_graph}" \
      --only-secrets CF_ACCESS_CLIENT_ID,CF_ACCESS_CLIENT_SECRET,WORK_GRAPH_API_URL \
      --preserve-env=WORK_GRAPH_DOPPLER_WRAPPED \
      -- bash "$0"
  fi
fi

: "${CF_ACCESS_CLIENT_ID:?CF_ACCESS_CLIENT_ID is required}"
: "${CF_ACCESS_CLIENT_SECRET:?CF_ACCESS_CLIENT_SECRET is required}"
: "${WORK_GRAPH_API_URL:?WORK_GRAPH_API_URL is required}"
approved_origin="https://work-graph.clemetson.me"
if [[ "$WORK_GRAPH_API_URL" != "$approved_origin" ]]; then
  echo "Cannot smoke-test Work Graph: WORK_GRAPH_API_URL is not the approved production origin." >&2
  exit 1
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/work-graph-smoke.XXXXXX")"
chmod 700 "$work_dir"
# shellcheck disable=SC2329 # invoked by the trap below
cleanup() {
  find "$work_dir" -type f -exec unlink {} + 2>/dev/null || true
  rmdir "$work_dir" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

printf 'header = "CF-Access-Client-Id: %s"\nheader = "CF-Access-Client-Secret: %s"\n' \
  "$CF_ACCESS_CLIENT_ID" "$CF_ACCESS_CLIENT_SECRET" >"$work_dir/access.curl"
curl_http_status_format='%{http_code}'

status=$(curl --disable --connect-timeout 10 --max-time 30 --silent --show-error \
  --output /dev/null --write-out "$curl_http_status_format" \
  "$WORK_GRAPH_API_URL/api/work-items?limit=1") || status="000"
if [[ "$status" != "403" ]]; then
  echo "Work Graph production must reject requests without an Access token; got HTTP $status." >&2
  exit 1
fi

status="000"
healthy=false
for attempt in 1 2 3 4 5; do
  status=$(curl --disable \
    --config "$work_dir/access.curl" \
    --connect-timeout 10 \
    --max-time 30 \
    --silent \
    --show-error \
    --output "$work_dir/response.json" \
    --write-out "$curl_http_status_format" \
    "$WORK_GRAPH_API_URL/api/work-items?limit=1") || status="000"
  if [[ "$status" == "200" ]] && jq -e '.items | type == "array"' "$work_dir/response.json" >/dev/null; then
    healthy=true
    break
  fi
  sleep "$attempt"
done

if [[ "$healthy" != true ]]; then
  echo "Work Graph production smoke test failed with HTTP $status." >&2
  exit 1
fi

status=$(curl --disable \
  --config "$work_dir/access.curl" \
  --connect-timeout 10 \
  --max-time 30 \
  --silent \
  --show-error \
  --output "$work_dir/scoped.json" \
  --write-out "$curl_http_status_format" \
  "$WORK_GRAPH_API_URL/api/work-items?projectId=work-graph&limit=100")
if [[ "$status" != "200" ]] || ! jq -e \
  '.items | type == "array"' \
  "$work_dir/scoped.json" >/dev/null; then
  echo "Work Graph production scoped queue verification failed with HTTP $status." >&2
  exit 1
fi

echo "Work Graph production rejects anonymous requests, and queue and project scope reads are healthy."
