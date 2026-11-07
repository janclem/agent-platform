<!-- Adapted from Robbie-Palmer/hq (docs/runbooks/agent-coordinator-hq-delivery.md), AGPL-3.0. -->

# `agent-platform` delivery contract

This contract says what an agent may deliver in `janclem/agent-platform` on its own,
which evidence proves a change is done, and when it must stop and ask.

## Scope

Changes to this repo: Terraform in `infra/`, the reusable workflows and composite
actions, the Renovate preset, agent skills, the Copier template, and docs. Production
effects are the GitHub settings Terraform manages (HCP workspace
`terraform-clemetson/foundation`) and the releases project repos consume.

## Delivery gates

### Local checks

Run from a clean worktree before publishing or updating the pull request:

```bash
mise run ci                                   # renders and checks the Copier template
mise exec -- jactionlint
mise exec -- zizmor .
.github/actions/check-skills/check-skills.sh
mise exec -- .github/actions/terraform-check/terraform-check.sh
```

For Terraform changes, also run `terraform -chdir=infra/foundation plan` and put the
summary in the PR. Call out every destroy or replace.

### Branch and review policy

`main` requires a pull request and `platform / checks`, blocks deletion and
non-fast-forward updates, requires linear history, and allows only squash merges with
zero approvals. An agent may merge once every triggered check has passed and every
actionable review finding is resolved. Read the live rules first:

```bash
gh api repos/janclem/agent-platform/rulesets/26760181
```

Never use an administrator bypass, change the ruleset outside a reviewed Terraform
PR, dismiss a review, or mark a check successful.

## Production proof

- **Terraform**: after merge, `terraform apply` runs from `main` only, and only when
  the owner has authorized it for that change (see Authority). Evidence: the HCP run
  URL with `0 to destroy` (unless the destroy was approved), and a follow-up
  `terraform plan` showing no changes.
- **Releases**: after merging a change to the reusable workflows, actions, or
  template, tag an exact `vX.Y.Z` on the merge commit. Evidence: `copier copy` from
  `gh:janclem/agent-platform` records that tag as `_commit`.
- **Everything else**: the merged `main` run of `platform / checks` passed.

Record the PR URL, merged revision, and evidence in the PR (the Work Graph once it
exists).

## Rollback

Revert the squash commit in a new PR through the same gates; for Terraform, apply the
revert under the same authorization. Never delete or move a published release tag:
tag a new patch release instead.

## Authority and attention

An agent may branch, open and update PRs, respond to review, squash-merge after the
gates pass, run `terraform plan`, and tag releases.

It may not run `terraform apply` without the owner's authorization for that change,
apply any plan that destroys or replaces a resource without explicit approval, bypass
branch protection, read or expose secrets, or delete published tags.

Request attention, naming the single decision needed, for an apply, a destructive
plan, a policy conflict, or a check that cannot run.
