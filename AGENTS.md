# Agent guide

## Repo
Personal agent automation platform. Infrastructure lives in `infra/` (Terraform, HCP workspace
`terraform-clemetson/foundation`). Shared agent skills live in `.agents/skills/` (read by Codex),
with thin pointers in `.claude/skills/` (read by Claude Code); project repos get copies from the
Copier template. More areas (machines/, services/, templates/) will be added.

## Tooling
- All tools are pinned in `mise.toml`. Run `mise install` first; use tools via mise.
- Terraform runs remotely in HCP. Provider credentials live in the HCP workspace, never locally.

## Rules
- Never commit secrets. Encrypted files via `sops` only; plaintext secrets are a hard stop.
- Never run `terraform apply` yourself. Run `terraform plan`, report the summary, and stop.
- Any plan that destroys or replaces a resource must be called out explicitly.
- `main` is protected: work on a branch, open a PR with `gh pr create`, squash-merge.
- Edit a skill in `.agents/skills/`. Add a `.claude/skills/` pointer for every new skill;
  `.github/actions/check-skills/check-skills.sh` enforces this.
- `.github/workflows/checks.yml` and `scans.yml` are reusable workflows that project repos call at
  `@v1`, together with the composite actions in `.github/actions/`. Keep changes backward
  compatible within v1; after merging one, move the `v1` tag to the new `main` commit.
- Keep config declarative. Multi-line scripts go in checked-in script files, not inline in YAML/HCL;
  scripts a composite action needs live next to its `action.yml`.

## Done means
Checks pass, PR merged, and the change is verified where it runs (e.g. `terraform plan` shows
no drift after apply). An open PR is not done.
