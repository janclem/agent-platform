#!/usr/bin/env bash
# Render the Copier template into a temporary repo and run the platform checks on it.
set -euo pipefail

root=$(pwd)
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

copier copy --trust --defaults --quiet --vcs-ref HEAD \
  --data project_name=template-smoke-test \
  --data description="Rendered by scripts/test-template.sh" \
  "$root" "$out"

cd "$out"
git init --quiet

status=0
fail() { echo "::error::$1"; status=1; }

for f in AGENTS.md CLAUDE.md README.md mise.toml renovate.json t3.json .copier-answers.yml \
  .github/workflows/ci.yml .github/workflows/security.yml .claude/settings.json \
  docs/runbooks/delivery-contract.md; do
  [[ -f "$f" ]] || fail "rendered project is missing $f"
done

# Skills must arrive as real files, not symlinks back into the template.
for dir in .agents .claude/skills; do
  [[ -d "$dir" && ! -L "$dir" ]] || fail "$dir must be a real directory in the rendered project"
done
[[ -z "$(find .agents .claude -type l)" ]] || fail "rendered project contains symlinks"
diff -r "$root/.agents/skills" .agents/skills >/dev/null || fail ".agents/skills differs from the platform"

grep -q '^# template-smoke-test$' README.md || fail "README.md did not render project_name"
grep -q 'repos/janclem/template-smoke-test/rulesets' docs/runbooks/delivery-contract.md \
  || fail "delivery-contract.md did not render project_name"
grep -qE 'checks.yml@[0-9a-f]{40} # v1' .github/workflows/ci.yml || fail "ci.yml must call checks.yml pinned to a v1 commit"

"$root/.github/actions/check-skills/check-skills.sh" || status=1
jactionlint || status=1

exit "$status"
