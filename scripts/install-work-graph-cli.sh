#!/usr/bin/env bash
# Build, pack, and globally install the Work Graph CLI from this checkout.
# Adapted from Robbie-Palmer/hq (packages/work-graph-cli/mise.toml), AGPL-3.0.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../packages/work-graph-cli"
pnpm build

archive_directory="$(mktemp -d)"
trap 'rm -rf "$archive_directory"' EXIT

pnpm pack --pack-destination "$archive_directory"
archive_path="$(find "$archive_directory" -maxdepth 1 -name 'work-graph-cli-*.tgz' -print -quit)"
if [ -z "$archive_path" ]; then
  echo "Work Graph CLI package archive was not created." >&2
  exit 1
fi

npm install --global "$archive_path"
