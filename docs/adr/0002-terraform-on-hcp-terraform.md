---
title: Manage GitHub settings with Terraform on HCP Terraform
status: Accepted
date: 2026-11-07
---

# 2. Manage GitHub settings with Terraform on HCP Terraform

Repository settings and branch rules are declared in Terraform under `infra/` and run
remotely in the HCP Terraform workspace `terraform-clemetson/foundation`.

## Context

Branch protection and repository settings decide what an agent can merge, so they must be
reviewable and reproducible rather than clicked in a web UI. Agents should be able to
propose and preview these changes without holding the credentials to make them.

## Decision

Declare GitHub repositories, rulesets, and security settings with the
`integrations/github` provider. Use an HCP Terraform workspace with CLI-driven runs for
state and execution. Provider credentials live only as sensitive workspace variables, so
plans and applies run in HCP and nothing secret exists on a laptop or in CI.

Agents may run `terraform plan`. Applying is reserved for the owner, as the delivery
contracts decision defines.

## Alternatives

- **State in the repository or a local backend:** no locking and secrets in state on
  disk.
- **Plain `gh api` scripts:** no plan or drift detection.

## Consequences

- Every settings change is a PR with a plan, and a follow-up plan proves there is no
  drift.
- HCP's CLI-driven runs upload only the root module's directory, so local modules live
  under `infra/foundation/`.
- HCP Terraform is an external dependency with free-tier limits; see
  [HCP Terraform pricing](https://www.hashicorp.com/products/terraform/pricing).
