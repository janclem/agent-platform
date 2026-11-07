#!/usr/bin/env bash
# Check formatting and validate every Terraform root under infra/ without
# contacting HCP or provider APIs. Does nothing when the repo has no infra/.
set -euo pipefail

if [[ ! -d infra ]]; then
  echo "No infra/ directory; skipping Terraform checks."
  exit 0
fi

status=0

echo "::group::terraform fmt"
terraform fmt -check -recursive -diff infra || status=1
echo "::endgroup::"

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
