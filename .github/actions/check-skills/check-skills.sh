#!/usr/bin/env bash
# Every skill in .agents/skills (read by Codex) needs a .claude/skills pointer
# (read by Claude Code), and every relative link in a pointer must resolve.
set -euo pipefail
shopt -s nullglob

if [[ ! -d .agents/skills && ! -d .claude/skills ]]; then
  echo "No agent skills; skipping layout check."
  exit 0
fi

status=0

for dir in .agents/skills/*/; do
  name=$(basename "$dir")
  [[ -f "$dir/SKILL.md" ]] || { echo "::error::$dir has no SKILL.md"; status=1; }
  [[ -f ".claude/skills/$name/SKILL.md" ]] || { echo "::error::.claude/skills/$name/SKILL.md is missing"; status=1; }
done

for pointer in .claude/skills/*/SKILL.md; do
  name=$(basename "$(dirname "$pointer")")
  [[ -d ".agents/skills/$name" ]] || { echo "::error::$pointer has no .agents/skills/$name"; status=1; }
  while IFS= read -r link; do
    target="$(dirname "$pointer")/$link"
    [[ -e "$target" ]] || { echo "::error file=$pointer::link $link does not resolve"; status=1; }
  done < <(grep -oE '\]\([^)#]+\)' "$pointer" | sed -E 's/^\]\(//; s/\)$//' | grep -vE '^[a-z]+://' || true)
done

exit "$status"
