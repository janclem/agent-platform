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

## Implementation notes (2026-11-12)

- **Contents: read.** Reconciliation reads each observed repository's delivery targets and
  default-branch head through the Contents API, so the App also has read-only Contents
  access. It still has no write permission.
- **Delivery targets** live in `.work-graph/delivery-targets.yaml` in each observed
  repository, in the `catalog.records` shape of hq's platform catalog. Every target must
  name a GitHub deployment environment, so every delivery path records one:
  `production-work-graph` from Work Graph CD, `production-work-graph-infra` from
  `mise run work-graph-infra:apply` on `main`, and `production-agent-platform` from
  `ci.yml` once `main` passes its checks.
- **Catalog publishing.** hq stores the catalog only during the six-hourly
  reconciliation, so evaluations after a catalog change, or for a repository's first
  linked PR, wait up to six hours. Here Work Graph CD also publishes it on every run,
  keyed by the file's git blob SHA (the ID reconciliation uses), so changes apply on
  merge.
- See `services/work-graph-observer/README.md`.

## Implementation notes (2026-11-13)

- **Covered deployments.** Completion evaluation wants a successful deployment at each
  PR's exact merge commit, but superseded queued runs, failed `main` checks and
  infrastructure applied together leave commits without one, and their tickets could
  never complete. After each successful deployment, the CD job, `ci.yml`'s `record-main`
  and `record-deployment.sh` run `mise run work-graph:record-covered-deployments`. It
  walks `main`'s first-parent history back to the previous successful deployment to the
  environment and records a deployment for each commit whose delivery targets (resolved
  with the evaluator's own resolver, across all projects) list that environment. The
  evaluator is unchanged from hq. `--since <sha>` repairs gaps from before a mechanism
  existed.
- **Inactive deployments are ignored.** GitHub marks an earlier deployment `inactive`
  when a newer one to the same environment succeeds. hq records that as `cancelled`
  evidence, which undoes completion whenever an environment redeploys, so a ticket whose
  PR needs several environments could get stuck. On `main`'s linear history the newer
  deployment contains the older commit, so the observer stores `inactive` deliveries but
  turns none into evidence.


## Implementation notes (2026-11-13, lease-expiry sweep)

- **Re-evaluation after a lease expires.** Automatic release only runs when a delivery
  for a linked PR arrives or a PR is linked. If the last delivery arrives while the
  agent still holds its lease, the evaluation records a candidate but returns
  `active_lease`, and nothing evaluates the ticket again once the lease lapses, so
  it stays open. hq at `6c08a3b` has the same gap. Here the observer's cron also
  runs a sweep every five minutes: a bounded page of open tickets with an expired,
  unended lease, a completion policy, a merged implementation PR and no evaluation
  since the lease expired goes through the unchanged
  `evaluateCompletionCandidateAndReleaseIfConfigured`. The evaluation ID is derived
  from the lease, so repeats are idempotent. The sweep adds no release rules and is
  not ingestion: it appends no evidence and changes a lease only through the
  existing automatic release, under its `completion-policy` actor.
