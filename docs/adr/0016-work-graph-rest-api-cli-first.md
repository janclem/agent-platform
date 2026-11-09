---
title: Expose the Work Graph through a governed REST API and CLI before MCP
status: Accepted
date: 2026-11-09
---

# 16. Expose the Work Graph through a governed REST API and CLI before MCP

A Hono REST API with a committed, linted OpenAPI contract is the Work Graph's only
application boundary. A TypeScript CLI comes first, and MCP is added later as a thin adapter.

## Context

Agents from several tools and machines, and the people working with them, need one
predictable way to inspect the queue, claim, edit the graph, add notes, and change state.
MCP could reach some agents, but scripts, CI, and ordinary terminals still need a stable API.
The platform is built for many agents working together, so the contract must be checked
rather than trusted. Robbie's [ADR 003](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/work-graph/adrs/003-rest-api-and-cli-first.mdx) and
[ADR 012](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/work-graph/adrs/012-separate-ticket-discovery-from-queue-selection.mdx) set this boundary.

## Decision

- **API:** noun-based resources under an unversioned `/api` prefix, implemented with Hono.
  Routes and bounded request and response schemas are declared with Zod-backed OpenAPI.
- **Contract governance:**
  - commit the generated OpenAPI document and test that runtime routes match it;
  - lint it with Spectral using OpenAPI and OWASP API security rules;
  - gate breaking changes with `oasdiff`;
  - generate client types for the CLI from the contract.
- **Versioning:** defer until an independent client cannot update with the server. The missing
  URL version marks the contract as pre-stable.
- **CLI first:** an installable TypeScript CLI against the contract is the agent and operator
  interface. A skill in the Copier template teaches project agents to use it.
- **MCP later:** a thin adapter over the same application layer, using MCP's Streamable HTTP
  transport, added once the CLI proves the operations.
- **Search:** finding related work before creating items is a separate, read-only
  `QUERY /api/work-items/search` operation ordered by relevance
  ([RFC 10008](https://www.rfc-editor.org/rfc/rfc10008.html)). It is kept apart from the
  priority-ordered list and queue. It runs in PostgreSQL, and its generated client needs an
  OpenAPI 3.2 contract.

## Consequences

- Every agent, script, and person gets the same behavior, and the contract is machine-readable
  and checked in CI.
- HTTP handlers must stay thin so REST and MCP cannot drift into separate implementations.
- During the pre-stable period, breaking changes must update the server, contract, and CLI
  together, and `oasdiff` makes each one visible.
- MCP-only clients wait for the adapter.
