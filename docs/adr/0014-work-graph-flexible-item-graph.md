---
title: Model agent work as a flexible graph of work items with explicit termination
status: Accepted
date: 2026-11-09
---

# 14. Model agent work as a flexible graph of work items with explicit termination

The Work Graph stores executable work as one recursive work-item type, with separate
containment and dependency relationships and deliberate terminal decisions. It is the
authoritative record of what should happen, in what order, and what proves it done. It is not
the process that launches agents.

## Context

Agents on several machines need one shared answer to:

- what matters most;
- what is ready now;
- what blocks what;
- who holds each item;
- what evidence would prove it complete.

Plans change as agents learn. A task can turn into several, research can unlock a design, and
work can be cancelled or replaced. Fixed types such as epic and task, or a flat backlog, hide
that structure and force rework when plans shift. Agents also stop early, so an item must not
appear finished just because its parts are.

Robbie's Work Graph solves this in
[ADR 000](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/work-graph/adrs/000-flexible-work-item-graph.mdx) and
[ADR 005](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/work-graph/adrs/005-explicit-work-item-termination.mdx). His coordinator later made it an
advisory record rather than the launch queue: agents start from events, not from polling the
graph. Services run on Cloudflare Workers and Neon (ADR 13).

## Decision

Adopt Robbie's model:

- **One work-item type:** each item has an optional single parent. Labels such as "epic" are
  data, not types.
- **Separate relationships:** containment and dependencies are stored separately. Both are
  projected into one waits-for graph, and a write is rejected if that graph would have a cycle.
  This includes a child depending on its own parent.
- **Derived readiness:** an open item is ready when it has no active lease, no unresolved
  blocking attention request, no unsatisfied dependency, and no non-terminal direct child.
  Released and cancelled blockers satisfy dependencies.
- **Atomic decomposition:** one transaction creates the children and their dependency edges,
  ends the current lease, and lets the children inherit the parent's scope and scheduling
  position.
- **Explicit termination:** `released` and `cancelled` are the only terminal states. When
  the last child terminates, the parent becomes ready again; it is not closed automatically.
  A worker must claim it and make the terminal decision.
- **Attention requests:** a worker that needs a human decision opens one. That pauses the
  item until the request is resolved.
- **Advisory role:** the Work Graph records and ranks work. Launching agents belongs to the
  coordinator, which will be decided separately.

## Consequences

- Plans can change without losing item identity. The combined cycle check prevents deadlocks
  that checking each relationship alone would miss.
- Queries must derive ready, blocked, and waiting states rather than read a stored type.
- Combined cycle checks cost more than separate ones, and decomposition couples graph writes
  to lease changes. Both need transaction tests against PostgreSQL.
- Parents need a deliberate final step, which adds one action per finished parent but stops
  work closing because its parts did.
