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
