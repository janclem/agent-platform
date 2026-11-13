---
title: Run coding agents on a NixOS host through T3 Code, as an unprivileged user
status: Proposed
date: 2026-11-13
---

# 25. Run coding agents on a NixOS host through T3 Code, as an unprivileged user

Coding agents run on an always-on NixOS host, in a T3 Code server that runs as a dedicated
user without sudo. The owner drives them from T3 Code on other devices over the tailnet.

## Context

Agents so far ran on the owner's laptop. Work Graph leases, handoffs and automatic release
assume workers that keep running; a laptop sleeps, and its 1Password prompts need the owner
at the keyboard. The coordinator, next on the roadmap, needs a host that is always there.

[T3 Code](https://github.com/pingdotgg/t3code) runs headless on Linux as a systemd user
service and accepts clients that pair with it. A client and server must speak the same
protocol version, and a server can be updated remotely from a client.

The operator's login on the host is in `wheel` with passwordless sudo. An agent running as
that user could change or rebuild the host.

## Decision

- **Host.** A NixOS host imports `homelab/modules/agent-host.nix`, which adds:
  - a dedicated user with no sudo, lingering so its user services start at boot;
  - rootless Docker, so the Docker socket does not grant root;
  - `nix-ld`, so prebuilt Linux binaries such as T3 Code and Claude Code run;
  - permission for that user to run `tailscale serve`.
- **T3 Code.** It is installed with T3 Code's own installer as that user's background service,
  at the version the owner's client runs, and updated from the client. Pinning it through
  nixpkgs would refuse every connection whenever the client updates first, and nixpkgs lags
  upstream. This departs from ADR 3: the running version is recorded on the host, not in Git.
- **Access.** The server listens only on the host, and Tailscale Serve publishes it over HTTPS
  to the tailnet. There is no T3 Connect relay, no LAN listener and no open port.
- **Credentials,** all set on the host and none in Git or the Nix store:
  - GitHub as the owner's account, through a fine-grained token limited to the owner's
    repositories and to contents, pull requests and workflows, with an expiry;
  - a read-only Doppler service token for `work-graph/prd_work_graph_agents`, so the
    `work-graph` CLI works unattended;
  - Claude Code and Codex signed in on the host by the owner.
- **No 1Password on the host.** Root credentials stay on the owner's devices behind 1Password
  approval, so agents on the host cannot run Terraform applies or host rebuilds. The rule that
  the owner authorizes every apply then holds by construction.

## Consequences

- Agents keep working while the owner's devices sleep, and several can run at once within the
  host's CPU and memory.
- Agent commits and pull requests appear as the owner's. The Work Graph lease, not the GitHub
  author, records which agent did the work.
- Updating T3 Code is an owner action from the client; a mismatch shows as a refused
  connection, not a silent failure.
- Changes that need root credentials still run from the owner's device; agents on the host
  stop and raise a Work Graph attention request for them.
- Tokens on the host are readable by every agent there. Each is scoped to what agents need and
  expires.
