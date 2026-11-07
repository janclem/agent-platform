#!/usr/bin/env bash
set -euo pipefail
version="$(<"$MISE_VERSION_FILE")"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "::error::mise-version.txt must contain one mise version"
  exit 1
fi
printf 'value=%s\n' "$version" >> "$GITHUB_OUTPUT"
