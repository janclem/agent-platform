---
title: Coordinate Work Graph claims and graph edits in PostgreSQL with fenced leases
status: Accepted
date: 2026-11-09
---

# 15. Coordinate Work Graph claims and graph edits in PostgreSQL with fenced leases

Claims, leases, and graph edits are enforced in PostgreSQL transactions. Each worker
mutation must present the current lease ID and epoch.

## Context

ADR 14 requires two guarantees under concurrency:

- two workers never claim the same item;
- concurrent edits that are each valid never combine into a cycle.

Agents also disappear through crashes, exhausted usage, closed sessions, or offline machines.
Their work must return to circulation without a delayed request from the old worker
overwriting the new one. ADR 13 places PostgreSQL on Neon behind Hyperdrive. Robbie's
[ADR 001](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/work-graph/adrs/001-postgresql-coordination-boundary.mdx) and
[ADR 002](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/work-graph/adrs/002-leases-with-fencing.mdx) solve both problems this way.

## Decision

- **Claims:** select the first eligible row with `FOR UPDATE SKIP LOCKED` and create its
  lease and event in the same transaction.
- **Graph edits:** serialize hierarchy and dependency changes by locking one well-known
  graph-mutation row `FOR UPDATE`. Check reachability with a recursive query in the same
  transaction, and apply the change only if the combined graph stays acyclic. Do not use
  advisory locks, which [Hyperdrive does not support](https://developers.cloudflare.com/hyperdrive/reference/supported-databases-and-features/).
- **Leases:** a lease has a stable worker ID, an expiry, and an epoch that increases on each
  reclaim. Workers renew while working. Every mutation on a worker's behalf presents the lease
  ID and epoch, so requests from an expired lease are rejected. Active leases are never
  pre-empted.
- **Lease history:** each lease ends with one outcome: released, cancelled, decomposed,
  attention requested, or expired. Opening a blocking attention request ends the lease. The
  history records the previous worker, so a later policy can prefer it.
- **Schema:** Drizzle defines the schema and queries, with committed migrations run directly
  against Neon rather than through Hyperdrive.

## Consequences

- Single claims and cycle-safe edits are enforced by the database, not by worker discipline.
- Every worker client must renew its lease. The expiry length trades recovery speed against
  false takeovers during long tool calls.
- Structural edits serialize across the whole graph. Revisit the lock scope if waits become
  noticeable.
- Every PostgreSQL feature these invariants rely on needs a test, and new locking or session
  behavior must be checked against Hyperdrive's supported features.
- The Workers Free plan allows
  [10 ms of CPU per request](https://developers.cloudflare.com/workers/platform/limits).
  Database waits don't count, but if graph projections exceed it, the account moves to
  Workers Paid.
