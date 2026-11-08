---
title: Host always-on platform services on Cloudflare Workers and Neon PostgreSQL
status: Accepted
date: 2026-11-08
---

# 13. Host always-on platform services on Cloudflare Workers and Neon PostgreSQL

The Work Graph, the AI review service, and GitHub webhook intake run on Cloudflare
Workers with PostgreSQL on Neon, under the `clemetson.me` domain. Self-hosted machines run
agents and call these services as clients.

## Context

These services coordinate agents across machines and receive GitHub events, so they must
stay up when any one machine is down. Self-hosted machines can be offline for reboots,
power or ISP outages, or while the hardware is used for something else. They are also
reachable only over the tailnet (ADR 11), which GitHub webhooks cannot reach.

The Work Graph needs transactional guarantees:

- two agents must never claim the same item;
- concurrent edits must never combine into a dependency cycle.

Robbie's Work Graph meets these with PostgreSQL, using `FOR UPDATE SKIP LOCKED` claims and
recursive cycle checks under a row lock, and runs on Workers with Neon. His ADRs
considered and set aside D1, a single Durable Object, and a tailnet-hosted PostgreSQL
service.

## Decision

- **Runtime:** run service APIs on [Cloudflare Workers](https://developers.cloudflare.com/workers/),
  written in TypeScript with Hono, Zod, and Drizzle, so `hq`'s design and code carry over
  with little change.
- **Database:** use a managed PostgreSQL project on [Neon](https://neon.com/docs/introduction),
  reached from Workers through [Hyperdrive](https://developers.cloudflare.com/hyperdrive/).
- **Access:** protect APIs with [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/policies/access/).
  Expose only the verified webhook route publicly.
- **Code and configuration:** code lives in this repository under `services/` and
  `packages/`. Cloudflare and Neon resources are managed with Terraform (ADR 2), and their
  API tokens follow the secrets decision (ADR 4).

## Alternatives

- **PostgreSQL and a Node service on a self-hosted NixOS machine:** no cloud accounts or
  runtime limits, and fits Tailscale directly. Rejected because the services would be
  down whenever that machine is, and webhooks could not arrive. It remains the fallback
  if Workers or Access cost more effort than they save.
- **Cloudflare D1:** no external database, but SQLite needs a different, harder design for
  concurrent claims and cycle-safe edits.

## Consequences

- Services stay available independently of home hardware, on free plans at this scale;
  see [Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/) and
  [Neon pricing](https://neon.com/pricing).
- Code must fit the Workers runtime, which supports a subset of Node.js APIs and has CPU,
  memory, and connection limits.
- Hyperdrive does not support every PostgreSQL feature; for example, it has no advisory
  locks. Check its supported-feature list before relying on session or locking behavior.
- Three more external accounts need API tokens before the first deploy. Each token goes
  in 1Password and the relevant secret store.
