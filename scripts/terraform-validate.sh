#!/usr/bin/env bash
# Validate every Terraform root under infra/ without contacting HCP or providers' APIs.
set -euo pipefail
status=0
for dir in infra/*/; do
  [[ -n "$(find "$dir" -maxdepth 1 -name '*.tf' -print -quit)" ]] || continue
  echo "::group::terraform validate ${dir}"
  if ! terraform -chdir="$dir" init -backend=false -input=false -no-color >/dev/null \
    || ! terraform -chdir="$dir" validate -no-color; then
    status=1
  fi
  echo "::endgroup::"
done
exit "$status"
