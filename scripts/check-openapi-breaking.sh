#!/usr/bin/env bash
# Fail when an OpenAPI contract breaks compatibility with main without a deliberate
# version bump (ADR 16). Usage: check-openapi-breaking.sh <path/to/openapi.json>
set -euo pipefail

contract=$1
base_dir=$(mktemp -d)
trap 'rm -rf "$base_dir"' EXIT

# CI checks out one commit without credentials; the repository is public.
if ! git rev-parse --verify --quiet origin/main >/dev/null; then
  git fetch --quiet --depth=1 origin main
fi
if ! git cat-file -e "origin/main:$contract" 2>/dev/null; then
  echo "$contract is not on main yet; nothing to compare."
  exit 0
fi
git show "origin/main:$contract" > "$base_dir/base.json"

version() { jq -r '.info.version' "$1"; }

if oasdiff breaking "$base_dir/base.json" "$contract" --fail-on ERR; then
  echo "No breaking changes in $contract."
  exit 0
fi

if [[ "$(version "$base_dir/base.json")" != "$(version "$contract")" ]]; then
  echo "::warning::$contract has breaking changes, declared by info.version $(version "$base_dir/base.json") -> $(version "$contract"). Update the server, contract, and CLI together."
  exit 0
fi

echo "::error::$contract breaks compatibility with main. Keep the change compatible, or bump info.version to make the break deliberate."
exit 1
