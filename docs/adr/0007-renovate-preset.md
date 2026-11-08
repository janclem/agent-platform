---
title: Keep dependencies current with a shared Renovate preset
status: Accepted
date: 2026-11-07
---

# 7. Keep dependencies current with a shared Renovate preset

A Renovate preset in `default.json` governs updates in this repository and every project,
auto-merging only what CI proves.

## Context

Pinned tools, actions, providers, flake inputs, and template versions go stale unless
something proposes updates. Reviewing every bump by hand is not sustainable for one
person.

## Decision

Use the Mend-hosted Renovate app with a preset adapted from `hq`:

- a 7-day minimum release age, dependency dashboard, and actions pinned to digests;
- major updates wait for dashboard approval;
- auto-merge GitHub Actions, mise tool minor and patch updates, the mise bootstrap
  version, and the validator image, all of which CI exercises;
- review by hand: Terraform core and providers, sops and age, and Copier template
  updates;
- `"mode": "full"` in the preset, so the app acts in every repository rather than
  scanning silently.

Projects extend it with `github>janclem/agent-platform`. CI validates the config strictly.

## Consequences

- Most updates merge without attention once required checks pass, using GitHub
  auto-merge.
- Anything that changes real infrastructure or shared project files still gets a human
  review.
- A preset mistake reaches every project at once; strict validation in CI reduces the
  risk.
