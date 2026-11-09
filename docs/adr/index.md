# Architecture decision records

Each record captures one decision and why it fit at the time. Records are not edited
after acceptance; a later record supersedes them. See the `adr-writing` skill.

| ADR | Decision | Status |
|---|---|---|
| [1](0001-public-agpl-platform-adapted-from-hq.md) | Build the platform as a public AGPL repository adapted from hq | Accepted |
| [2](0002-terraform-on-hcp-terraform.md) | Manage GitHub settings with Terraform on HCP Terraform | Accepted |
| [3](0003-pin-tools-with-mise.md) | Pin developer and CI tools with mise | Accepted |
| [4](0004-secrets-1password-sops.md) | Keep secrets in 1Password and service secret stores, encrypted with sops when committed | Accepted |
| [5](0005-agent-skills-layout.md) | Share agent skills from `.agents/skills` with Claude Code pointers | Accepted |
| [6](0006-reusable-workflows-copier-releases.md) | Distribute shared CI and files through reusable workflows, a Copier template, and exact release tags | Accepted |
| [7](0007-renovate-preset.md) | Keep dependencies current with a shared Renovate preset | Accepted |
| [8](0008-protected-main-project-repo-module.md) | Protect `main` with squash-only pull requests gated by platform checks | Accepted |
| [9](0009-delivery-contracts.md) | Define gates, evidence, and agent authority in delivery contracts | Accepted |
| [10](0010-nixos-hosts-flake.md) | Declare self-hosted machines as a NixOS flake installed with disko | Accepted |
| [11](0011-tailscale-host-access.md) | Reach self-hosted machines over Tailscale | Accepted |
| [12](0012-secure-boot-lanzaboote.md) | Use Secure Boot on NixOS hosts with Lanzaboote and machine-owned keys | Accepted |
| [13](0013-cloudflare-workers-and-neon-for-services.md) | Host always-on platform services on Cloudflare Workers and Neon PostgreSQL | Accepted |
| [14](0014-work-graph-flexible-item-graph.md) | Model agent work as a flexible graph of work items with explicit termination | Accepted |
| [15](0015-work-graph-postgres-fenced-leases.md) | Coordinate Work Graph claims and graph edits in PostgreSQL with fenced leases | Accepted |
| [16](0016-work-graph-rest-api-cli-first.md) | Expose the Work Graph through a governed REST API and CLI before MCP | Accepted |
| [17](0017-work-graph-access-service-tokens.md) | Authenticate Work Graph clients with Cloudflare Access service tokens, and add Cedar with the first read-only client | Accepted |
| [18](0018-work-graph-contextual-stack-ranking.md) | Rank Work Graph items with contextual stacks fused by reciprocal rank | Accepted |
| [19](0019-work-graph-github-evidence-app.md) | Observe delivery evidence with a dedicated read-only GitHub App and queued webhooks | Accepted |
| [20](0020-work-graph-immutable-events.md) | Record every Work Graph state change as an immutable event, and defer analytics | Accepted |
| [21](0021-work-graph-backups-r2.md) | Back up the Work Graph database nightly to R2 with restore drills | Accepted |
