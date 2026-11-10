---
title: Run the Work Graph API on Workers Free until requests exceed its CPU limit
status: Accepted
date: 2026-11-10
---

# 22. Run the Work Graph API on Workers Free until requests exceed its CPU limit

The Work Graph API starts on the Cloudflare Workers Free plan and moves to Workers Paid when
the Worker records its first request that exceeded the CPU limit.

## Context

The Workers Free plan allows
[10 ms of CPU per request](https://developers.cloudflare.com/workers/platform/limits). Time
spent waiting on the database doesn't count. Robbie runs his Work Graph on Workers Paid
($5 a month) because queue reads and critical-path projections exceeded 10 ms once his graph
held several hundred tickets. Our graph starts empty, so that cost buys nothing yet.

Custom CPU limits (`[limits] cpu_ms` in `wrangler.toml`) are only available on Workers Paid,
so hq's explicit 5-second ceiling can't be kept on Free.

## Decision

- Deploy on Workers Free without a `[limits]` block.
- **Trigger:** move to Workers Paid when the Worker's observability logs show any request with
  an `exceededCpu` outcome, or a client receives Cloudflare error 1102 ("Worker exceeded
  resource limits"). These come from Cloudflare, not from an agent's report.
- When upgrading, restore `[limits] cpu_ms = 5_000` so runaway graph work still stops at an
  explicit ceiling.

## Consequences

- No Cloudflare spend until the graph is large enough to need it.
- The first failures will reach agents as 1102 errors on queue or critical-path reads. Claims,
  notes and other writes use little CPU and should keep working, so the impact is contained
  but real until the plan changes.
- Free also caps Workers at
  [100,000 requests a day](https://developers.cloudflare.com/workers/platform/limits). Agent
  polling counts toward it, so hitting it is a second trigger.
