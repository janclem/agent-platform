---
title: Rank Work Graph items with contextual stacks fused by reciprocal rank
status: Accepted
date: 2026-11-09
---

# 18. Rank Work Graph items with contextual stacks

Priority comes from separate ordinal stacks for initiatives, projects, and tickets, fused into
one queue with reciprocal-rank fusion, plus reason-bearing expedites.

## Context

Agents across several projects draw from one queue. Ranking every item against every other
doesn't scale, and a single global list can't express "this project matters more than that
one" without reordering every ticket. Priority must also flow through decomposition and
dependencies. Robbie's [ADR 006](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/work-graph/adrs/006-contextual-stack-ranking.mdx) defines this policy.

His initiatives and projects mirror pages in a knowledge graph. This platform has no
knowledge graph yet; one is planned for a later phase.

## Decision

Adopt Robbie's ranking:

- **Stacks:** initiatives rank against initiatives, projects against projects, and tickets
  only against tickets in the same scheduling project. New entries start at the median.
  Relative move commands update one stack, which the service may renormalize.
- **Scheduling scope:** each priority-owning ticket stores one scheduling project and, when
  needed, one initiative. The initiative is inferred when the project has exactly one.
  Decomposed work inherits its owner's position.
- **Fusion:** `score = 1/(10 + initiative rank) + 1/(10 + project rank) + 1/(10 + ticket rank)`,
  higher first. Missing dimensions use the stack's median. Ties break by structural child
  rank, then stable ID.
- **Expedite:** stored separately from rank, with a required reason. Expedited tickets sort
  first, and their urgency is projected onto unresolved blockers with the source recorded.
- **Scopes until the knowledge graph exists:** initiatives and projects are non-executable
  scope records with stable IDs owned by the Work Graph. When the knowledge graph arrives,
  they become mirrors of its pages, keeping their IDs.

## Consequences

- The API accepts relative moves and does not expose the fusion score. Read models include the
  three source positions and expedite provenance so clients can explain the order.
- The queue can move when any surrounding stack changes. Fixture tests must protect the offset,
  missing-rank handling, and tie-break order.
- Scope records owned here must migrate to knowledge-graph mirrors later. Stable IDs make that
  a change of owner, not of identity.
