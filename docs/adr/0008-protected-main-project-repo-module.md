---
title: Protect main with squash-only pull requests gated by platform checks
status: Accepted
date: 2026-11-07
---

# 8. Protect `main` with squash-only pull requests gated by platform checks

Every managed repository gets the same `main` ruleset and merge settings from one
Terraform module, `infra/foundation/modules/project-repo`.

## Context

Agents merge their own PRs, so the merge gate must be enforced by GitHub, not by
instructions. With one person there is no second reviewer, so required approvals would
block every merge. The policy was first written for this repository alone; repeating it
per project would let projects drift. This builds on Terraform on HCP Terraform (ADR 2).

## Decision

The module creates a repository with:

- a ruleset on the default branch that requires a pull request (zero approvals), requires
  `platform / checks`, requires linear history, and blocks deletion and force pushes;
- squash merge only, branch deletion on merge, and auto-merge enabled for Renovate;
- vulnerability alerts and Dependabot security updates, plus secret scanning and push
  protection for public repositories;
- `prevent_destroy`, so removing an entry cannot delete a repository;
- an initial commit, so all later content arrives by pull request.

Repositories are entries in `local.repositories` in `infra/foundation/github.tf`.
Branches need not be up to date with `main` before merging, so sequential PRs avoid
rebases.

## Consequences

- Required checks are the only gate. Their quality is the merge quality until an AI review
  service adds a second signal.
- One change to the module updates every repository's policy.
- Secret scanning is unavailable for private repositories on the free plan.
