# Agent guide

## Repo
Personal agent automation platform. Infrastructure lives in `infra/` (Terraform, HCP workspace
`terraform-clemetson/foundation`). More areas (machines/, services/, templates/) will be added.

## Tooling
- All tools are pinned in `mise.toml`. Run `mise install` first; use tools via mise.
- Terraform runs remotely in HCP. Provider credentials live in the HCP workspace, never locally.

## Rules
- Never commit secrets. Encrypted files via `sops` only; plaintext secrets are a hard stop.
- Never run `terraform apply` yourself. Run `terraform plan`, report the summary, and stop.
- Any plan that destroys or replaces a resource must be called out explicitly.
- `main` is protected: work on a branch, open a PR with `gh pr create`, squash-merge.
- Keep config declarative. Multi-line scripts go in checked-in script files, not inline in YAML/HCL.

## Done means
Checks pass, PR merged, and the change is verified where it runs (e.g. `terraform plan` shows
no drift after apply). An open PR is not done.
