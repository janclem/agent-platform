---
title: Pin developer and CI tools with mise
status: Accepted
date: 2026-11-07
---

# 3. Pin developer and CI tools with mise

Every tool the repository and CI run is pinned to an exact version in `mise.toml`.

## Context

Agents run checks locally before CI runs them again. Different tool versions on a laptop,
in an agent's worktree, and in CI produce different results and noisy failures.

## Decision

Pin Terraform, linters, scanners, Copier, sops, age, and runtimes in `mise.toml`, and run
them through mise. CI installs the same versions with the `setup-mise` composite action,
whose mise version is itself pinned and tracked by Renovate. T3 Code trusts and installs
the tools when it creates a worktree (`t3.json`).

Use [jactionlint](https://github.com/jdx/jactionlint), the maintained fork of
actionlint, because mise deprecated actionlint and the fork understands the
self-repository (`$/`) action references the reusable workflows rely on.

## Consequences

- Local runs, agent worktrees, and CI agree on versions.
- Renovate can update tools, and CI exercises each update before it merges.
- mise is one more tool every machine and runner must bootstrap.
