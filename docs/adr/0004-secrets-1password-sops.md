---
title: Keep secrets in 1Password and service secret stores, encrypted with sops when committed
status: Accepted
date: 2026-11-07
---

# 4. Keep secrets in 1Password and service secret stores

> Amended by [ADR 23](0023-doppler-for-machine-secrets.md): machine secrets live in Doppler.

Secrets live in 1Password (vault `agent-platform`) and in each service's own secret
store. A secret is committed only when encrypted with sops and age.

## Context

The repository is public and agents read it freely. Agents also run commands and write
transcripts, so a secret that reaches a prompt, a log, or the Nix store should be treated
as exposed.

## Decision

- 1Password holds the authoritative copy of every credential and recovery code.
- Services receive credentials through their own stores, such as HCP sensitive
  variables.
- A secret that must live in the repository is encrypted with sops and age. A plaintext
  secret is a hard stop.
- Never put a secret in a Nix expression, because the Nix store is world-readable. Hosts
  receive secrets at install time or from files outside the store.
- Agent tool settings deny access to secret files, and gitleaks scans every PR and the
  full history.
- Owners enter secrets themselves; agents never ask for them in chat.

## Consequences

- Leaks are blocked at several layers: agent permissions, review, gitleaks, and GitHub
  push protection.
- Setting up a new service includes a manual step to create its token and store it.
- Renovate updates to sops and age are reviewed by hand, because no CI job proves them.
