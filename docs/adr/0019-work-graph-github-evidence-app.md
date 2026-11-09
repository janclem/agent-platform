---
title: Observe delivery evidence with a dedicated read-only GitHub App and queued webhooks
status: Accepted
date: 2026-11-09
---

# 19. Observe delivery evidence with a dedicated read-only GitHub App and queued webhooks

A private, read-only GitHub App sends pull-request, workflow-run, and deployment events to a
public Worker. The Worker queues them, and the Work Graph stores them as immutable evidence
used to judge whether work is complete.

## Context

Delivery contracts (ADR 9) define done as merged and verified. Agents often stop early or
report completion without the proof, so evidence that depends on the agent reporting it is
unreliable. GitHub already emits the facts deterministically. Robbie's
[ADR 008](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/work-graph/adrs/008-github-delivery-evidence-ingestion.mdx) and
[ADR 009](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/work-graph/adrs/009-observed-evidence-before-automatic-release.mdx) ingest them this way.

The API is behind Access (ADR 17), which GitHub cannot pass. GitHub expects a response within
ten seconds, may repeat deliveries, and does not guarantee order.

## Decision

- **App:** a dedicated private GitHub App with read-only pull requests, Actions, and
  deployments. It subscribes to `pull_request`, `workflow_run`, and `deployment_status`,
  and is installed only on repositories the Work Graph admits. It is separate from the AI
  review service's App, which has write access.
- **Ingress:** a dedicated public Worker hostname with one route, `POST /webhooks/github`.
  It verifies `X-Hub-Signature-256` over the raw body before parsing, rejects oversized or
  malformed payloads, enforces installation and repository allowlists, and uses
  `X-GitHub-Delivery` as the idempotency key.
- **Queue:** after verification, enqueue to Cloudflare Queues and respond. A consumer
  normalizes payloads and writes through the application layer, with bounded retries and a
  dead-letter queue. The database rejects duplicate delivery IDs.
- **Evidence:** immutable records keep provider, external ID, repository, commit SHA, kind,
  state, URL, provider and ingest times, and correlation provenance.
- **Correlation:** only explicit pull-request links and exact commit chains (PR head, merge
  commit, CI commit, deployed commit). Never infer from branch names, titles, or timing.
- **Completion candidacy:** a versioned owner policy decides when an item looks complete:
  - required PRs merged;
  - required CI passed;
  - deployment reported where the contract requires it;
  - no unfinished children;
  - no blocking attention.

  Ingestion may append evidence and recompute candidacy. It may never release or cancel an
  item, change a lease, or satisfy a dependency.
- **Release:** a worker's release must reference stored evidence. Automatic release, if added,
  is a separate operation with its own system actor.
- **Reconciliation:** an installation-token backfill repairs missed deliveries. Webhooks are
  not the only path.

## Consequences

- Evidence arrives whether or not an agent reports it, and duplicate or out-of-order events
  cannot repeat lifecycle changes.
- The webhook route is an internet-facing boundary. Its verification, body limits, secret
  rotation, retries, and dead-letter handling need tests and monitoring.
- One more App registration, webhook secret, private key, and rotation procedure to maintain.
- Queues on the Workers Free plan
  [keep messages for 24 hours](https://developers.cloudflare.com/queues/platform/limits/),
  so a consumer outage longer than that relies on reconciliation.
