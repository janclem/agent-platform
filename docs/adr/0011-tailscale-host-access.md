---
title: Reach self-hosted machines over Tailscale
status: Accepted
date: 2026-11-07
---

# 11. Reach self-hosted machines over Tailscale

Self-hosted machines join a Tailscale tailnet and are reached over it, with no ports
forwarded on the home router.

## Context

Hosts sit behind a home router and must be reachable from a laptop and other devices,
including away from home, without exposing services to the internet.

## Decision

Enable the Tailscale NixOS service on each host and enroll it by hand with
`sudo tailscale up` after install, so no auth key is stored. Trust the `tailscale0`
interface in the firewall, and open only Tailscale's UDP port otherwise. SSH accepts keys
only, for named users.

## Alternatives

- **Port forwarding or a public VPN endpoint:** exposes services to the internet and
  depends on the home IP.
- **Self-run WireGuard:** more setup and key management for the same result.

## Consequences

- Hosts are reachable by name from any enrolled device with no public exposure.
- Tailscale is an external coordination service on its free personal plan; see
  [Tailscale pricing](https://tailscale.com/pricing).
- GitHub and other internet services cannot reach anything that lives only on the
  tailnet.
