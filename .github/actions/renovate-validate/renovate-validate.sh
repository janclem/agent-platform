#!/usr/bin/env bash
# Validate whichever Renovate config files the repo has. Does nothing when it has none.
set -euo pipefail

files=()
for f in renovate.json default.json; do
  [[ -f "$f" ]] && files+=("$f")
done

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No Renovate config; skipping validation."
  exit 0
fi

docker run --rm \
  --volume "${PWD}:/workspace" \
  --workdir /workspace \
  --entrypoint renovate-config-validator \
  "$RENOVATE_IMAGE" \
  --strict "${files[@]}"
