---
title: Record every Work Graph state change as an immutable event, and defer analytics
status: Accepted
date: 2026-11-09
---

# 20. Record every Work Graph state change as an immutable event

Every Work Graph state change is appended to an immutable, sequenced event log from the first
release. Analytics on that history are deferred.

## Context

Reports on recurring waits, attention requests, stale leases, and failed handoffs will show
where agents struggle. Robbie builds them in
[ADR 010](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/work-graph/adrs/010-private-lake-analytics.mdx) and ADR 011 by exporting events to Parquet in R2
and modeling them with DuckDB and dbt. That pipeline isn't needed yet, and its cost case is
unmeasured even in his setup. History that was never recorded can't be rebuilt later.

## Decision

- Write an immutable event in the same transaction as every change to a work item, lease,
  dependency, attention request, rank, or evidence record. Each event has a monotonically
  increasing sequence, actor, time, and payload.
- Never update or delete events. Current state lives in tables. Events are the history.
- Keep worker telemetry, prompts, model calls, and private logs out of events.
- **Deferred:** export to R2, Parquet, DuckDB, and dbt. Revisit when a specific report is
  needed, or when querying history from PostgreSQL becomes costly. The sequence column is the
  export cursor Robbie's design uses.

## Consequences

- Any later analytics can replay full history from day one.
- Events add one insert per change and grow without bound. Storage use must be watched
  against Neon's free limits.
- Reports wait until the export pipeline is built.
