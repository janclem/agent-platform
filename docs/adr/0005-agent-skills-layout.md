---
title: Share agent skills from .agents/skills with Claude Code pointers
status: Accepted
date: 2026-11-07
---

# 5. Share agent skills from `.agents/skills`

Shared agent skills live in `.agents/skills/`, with thin pointer files in
`.claude/skills/`, following `hq`.

## Context

Both Codex and Claude Code work in these repositories. Codex reads `.agents/skills/`;
Claude Code reads `.claude/skills/`. A first attempt shipped the skills as a Claude Code
plugin, which only Claude Code could load.

## Decision

Keep each skill once, in `.agents/skills/<name>/`. Add a pointer in `.claude/skills/` for
every skill. `check-skills.sh` fails CI when a pointer is missing or broken. `CLAUDE.md`
imports `AGENTS.md`, so both agents share one rule set.

## Alternatives

- **A Claude Code plugin:** versioned installs, but invisible to Codex.

## Consequences

- One source per skill, readable by both agents.
- Project repositories get copies through the template, not a live link, so skill fixes
  reach them only through `copier update`.
