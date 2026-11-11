---
title: Keep machine secrets in Doppler and human root credentials in 1Password
status: Accepted
date: 2026-11-11
---

# 23. Keep machine secrets in Doppler and human root credentials in 1Password

Secrets that scripts generate and agents read at runtime live in Doppler. 1Password keeps the
root credentials people create and the recovery material. This amends ADR 4, which made
1Password the store for every credential.

## Context

Agents run unattended, so they can't unlock the 1Password desktop app. They would need a
1Password service account, and on individual and Families plans every service account in the
account shares
[1,000 requests per 24 hours](https://developer.1password.com/docs/service-accounts/rate-limits).
Each agent session reads its Work Graph credentials when it starts, so several agents plus CI
and Terraform runs could use the whole day's quota and lock out every service account at once.

Robbie's hq keeps these secrets in Doppler. His Terraform credential helpers, the `work-graph`
CLI's credential loading, the GitHub Actions environment sync, and token rotation all use its
API. Doppler scopes each service token to one config, read-only or read-write, which suits
handing each agent and job only what it needs.

## Decision

- **Doppler** holds machine secrets: credentials Terraform helpers generate (database URL,
  Hyperdrive ID, Access service-token pair) and anything agents, Workers deploys, or CI read at
  runtime. One Doppler project per service, with a branch config per consumer, for example
  `work-graph/prd_work_graph`.
- **1Password** (vault `agent-platform`) holds root and bootstrap credentials that people
  create, such as provider API tokens, the HCP and GitHub tokens, Doppler service tokens used
  by operators, the sops age key, and recovery codes. Local runs read them through `op run`
  with a committed file of `op://` references, never values.
- ADR 4's other rules stand: no plaintext secrets in the repository, sops and age for
  committed secrets, nothing secret in Nix, and agents never ask for secrets in chat.

## Consequences

- Agent traffic doesn't depend on 1Password's service-account quota.
- Robbie's Doppler-based tooling ports with little change.
- Doppler is one more vendor and account to protect: enable 2FA and keep its recovery codes in
  1Password. Its free Developer plan covers up to three users.
- Rotating a machine secret means updating Doppler; rotating a root credential means updating
  1Password and, where a service holds a copy, that service.
