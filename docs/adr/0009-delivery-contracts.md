---
title: Define gates, evidence, and agent authority in delivery contracts
status: Accepted
date: 2026-11-07
---

# 9. Define gates, evidence, and agent authority in delivery contracts

Each repository has a delivery contract that states which checks gate a change, which
evidence proves it done, and what an agent may do without the owner.

## Context

"Done" for an agent is ambiguous: an open PR, a merge, or a verified deployment. Some
actions, such as applying infrastructure, are hard to reverse. Robbie's
`agent-coordinator-hq-delivery.md` addresses this with an explicit contract.

## Decision

Adapt that contract:

- `docs/runbooks/agent-platform-delivery.md` for this repository;
- `docs/runbooks/delivery-contract.md`, rendered from the template, for every project.

A contract lists the local checks, branch policy, production proof, rollback, and
authority. Done means merged and verified where the change runs. Agents may branch, open
and merge PRs after the gates pass, run plans, and tag releases. Without the owner's
authorization for that change, they may not:

- run `terraform apply`, a host installer, or `nixos-rebuild switch`;
- apply a plan that destroys or replaces a resource;
- bypass branch protection or expose secrets;
- move or delete published tags.

A project contract forbids deploying until its Scope names a production target.

## Consequences

- Agents can finish routine work without waiting, and stop at a named decision for
  everything else.
- Evidence such as PR, merge commit, and run URLs lives in PRs until a Work Graph exists
  to hold it.
