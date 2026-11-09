# Agent guide

## Repo
Personal agent automation platform. Infrastructure lives in `infra/` (Terraform, HCP workspace
`terraform-clemetson/foundation`). Shared agent skills live in `.agents/skills/` (read by Codex),
with thin pointers in `.claude/skills/` (read by Claude Code); project repos get copies from the
Copier template. NixOS machines live in `homelab/` (a flake with one directory per host under
`homelab/hosts/`). TypeScript packages live in `packages/` and deployable services in `services/`, one pnpm workspace;
`mise run ts:check` lints (Biome), typechecks and tests them.
`mise run work-graph:db` checks migrations and runs the database integration tests; it needs Docker.
`mise run work-graph:api` lints the API contract (Spectral, OWASP, oasdiff), builds the CLI, starts the
Worker in workerd, and runs the HTTP integration tests. After changing a route, regenerate
`openapi.json` and the CLI client and commit both. More areas (services/) will be added.

## Tooling
- All tools are pinned in `mise.toml`. Run `mise install` first; use tools via mise.
- Terraform runs remotely in HCP. Provider credentials live in the HCP workspace, never locally.

## Rules
- Never commit secrets. Encrypted files via `sops` only; plaintext secrets are a hard stop.
- Repositories are declared in `infra/foundation/github.tf` and share the policy in
  `infra/foundation/modules/project-repo`; see `docs/runbooks/new-project.md`.
- Never run `terraform apply` yourself. Run `terraform plan`, report the summary, and stop.
- Any plan that destroys or replaces a resource must be called out explicitly.
- `main` is protected: work on a branch, open a PR with `gh pr create`, squash-merge.
- Edit a skill in `.agents/skills/`. Add a `.claude/skills/` pointer for every new skill;
  `.github/actions/check-skills/check-skills.sh` enforces this.
- `template/` (with `copier.yml`) is the Copier template for project repos. Its skills are
  symlinks to this repo's, so edit skills here only. `mise run ci` renders and checks the template.
- `.github/workflows/checks.yml` and `scans.yml` are reusable workflows that project repos call
  pinned to a release commit, together with the composite actions in `.github/actions/`.
- Releases are exact `vX.Y.Z` tags on `main` (no moving `v1` tag: Copier would record it as the
  template version). Tag a release after merging a change to the reusable workflows, actions,
  or template; keep changes backward compatible within a major version.
- `homelab/scripts/check.sh` format-checks and evaluates the flake; it needs Nix, so CI runs it.
  Never put a secret in a Nix file: it would land in the world-readable Nix store.
- Never run the installer or `nixos-rebuild switch` on a machine yourself; build, report, and stop.
- Keep config declarative. Multi-line scripts go in checked-in script files, not inline in YAML/HCL;
  scripts a composite action needs live next to its `action.yml`.

## Decisions
Architecture decisions are in [docs/adr/](docs/adr/index.md). Record a new architectural
choice there with the `adr-writing` skill; supersede rather than edit accepted records.

## Delivery
[docs/runbooks/agent-platform-delivery.md](docs/runbooks/agent-platform-delivery.md) defines the
gates, the evidence that proves a change is done, and what needs the owner's say-so.

## Done means
Checks pass, PR merged, and the change is verified where it runs (e.g. `terraform plan` shows
no drift after apply). An open PR is not done.
