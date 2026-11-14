---
title: Coordinate agents from a T3 Code controller thread woken by GitHub webhooks, starting with Renovate repair
status: Accepted
date: 2026-11-13
---

# 26. Coordinate agents from a T3 Code controller thread, starting with Renovate repair

The agent coordinator is a persistent T3 Code controller thread, woken by a signed GitHub
webhook, that admits events under a checked-in policy and launches one worker thread per
outcome. The Work Graph records each outcome; it is not a launch queue. The first workflow
repairs Renovate pull requests whose checks fail in this repository.

## Context

The agent host (ADR 25) keeps T3 Code running, and the roadmap's next step is a coordinator
that starts agent work without the owner asking for it each time.

Robbie built two generations of this. His first
([PDR 000](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/agent-coordinator/pdrs/000-advisory-work-graph-routing.mdx))
polled ready Work Graph tickets and matched them to agents through custom provider and
session adapters. Its pilot eagerly picked up architecture, prose and UX tickets that still
needed human judgement, and turned agent capacity into a review queue for the owner
([project index](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/agent-coordinator/index.mdx)).
His second generation
([ADR 001](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/agent-coordinator/adrs/001-t3-code-orchestration-control-plane.mdx),
[ADR 002](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/agent-coordinator/adrs/002-event-driven-incident-ledger.mdx),
[PDR 001](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/agent-coordinator/pdrs/001-severe-vulnerability-resolution.mdx))
drops the adapters and the polling: T3 Code is the execution control plane, a webhook starts
a controller thread, and the first workflow is one with a machine-checkable end state.

T3 Code 0.1.9, pinned on the host, already provides what the first generation built by hand:
- provider-backed threads and top-level thread launch with T3-managed worktrees
  ([orchestrator MCP server](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/orchestration-v2/orchestrator-mcp-server.md));
- native pull-request watching;
- [subscription-limit tracking](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/user/usage.md#track-subscription-limits),
  with snooze and resume when a limit resets;
- [continuation after an update or restart](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/user/updating.md#before-you-update);
- [webhook automations](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/user/project-settings.md#webhook-automations)
  (present since 0.1.7): a scheduled task with an **On webhook** trigger, bound to a thread,
  with GitHub's `x-hub-signature-256` HMAC check, filters, a duplicate-request key kept for
  seven days, and a coalesce window of 10–3600 s that survives a restart. Request values
  reach the agent wrapped and marked untrusted, which the docs say does not guarantee the
  agent ignores them.

Two 0.1.9 facts constrain the design. Environments
[settle threads after seven days of inactivity](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/user/thread-sidebar.md#settle-finished-work)
by default, so a quiet controller would be settled. A public webhook URL needs T3 Connect;
how GitHub reaches the host is a separate decision.

Renovate already proposes dependency updates here, and the shared preset automerges many of
them once checks pass. The ones that fail sit open until the owner looks. Repairing them has
a clear trigger, a bounded change and an objective end: the delivery contract (ADR 9) and the
observer's evidence (ADR 19) already say what done means.

## Decision

- **Control plane.** T3 Code is the execution control plane: threads, worktrees, provider
  sessions, PR watching, limit resume and restart recovery. The coordinator adds only what
  T3 Code lacks: admission policy, correlation with Work Graph items, and the workflow's
  outcome rules. No polling of `work-graph ready`, no custom provider or session adapters,
  and no OpenRouter or other model routing in the coordinator.
- **Controller.** One persistent controller thread per workflow. It makes short decisions and
  does no implementation in its own checkout. Its auto-settle behaviour is set to **Never**,
  and it keeps no state that matters only in its history: after a restart or a lost thread
  it rebuilds from GitHub and the Work Graph.
- **Trigger.** A GitHub repository webhook calls a T3 webhook task bound to the controller
  thread. The task:
  - requires the `x-hub-signature-256` signature;
  - filters on event type, action and conclusion, so only failed workflow runs start
    anything;
  - uses `{{headers.x-github-delivery}}` as its duplicate-request key;
  - coalesces bursts for the same head commit.

  The prompt passes only identity fields (delivery ID, event, repository, run ID, head SHA,
  PR number), which the controller treats as untrusted. Before acting it re-fetches the PR,
  its author, changed files and check state from GitHub with its own credentials.
- **Workers.** For each admitted outcome the controller launches one top-level worker thread
  with a T3-managed worktree. The worker owns the outcome until it is released or blocked on
  attention, and may start focused research or review threads under it.
- **Work Graph as the record.** The controller creates one Work Graph item per outcome, with
  an ID derived deterministically from the repository and PR number, and writes it only on
  transitions: admitted, worker launched (with its thread), attention raised, released. The
  worker claims it, links its PR as `implementation`, and releases it with evidence under
  the `work-graph` skill. The observer supplies CI and deployment evidence (ADR 19). A repeat
  event for the same PR finds the existing item instead of creating a second one.
- **First workflow: repair failing Renovate PRs in `janclem/agent-platform`.**
  - Admitted: an open PR authored by Renovate in this repository whose required checks failed.
  - Excluded, left for the owner: any PR that changes a path under `homelab/` (including the
    agent-host tool bumps in `homelab/agent-host/`) or under `infra/`.
  - The worker fixes the code so the update ships, or concludes it cannot ship and raises a
    Work Graph attention request that names the decision needed.
  - Done means checks green, PR squash-merged, deployed per `.work-graph/delivery-targets.yaml`,
    and the ticket released.
  - One worker at a time. While one runs, the controller admits nothing new; when it ends, the
    controller re-reads GitHub for any other failing Renovate PR before admitting the next.
- **Admission policy.** A plain, checked-in policy file lists the repository, the PR author,
  the excluded paths and the concurrency limit, and the controller reads it on every event.
  Cedar (ADR 24), as Robbie uses for his controller, is the later option once policies need
  profiles or prohibitions a plain file cannot express clearly.
- **Later workflows,** in order: failed post-merge runs on `main`, then Dependabot alerts.
  Each widens the policy file and the webhook filters; none adds a launch queue.

## Alternatives

- **Poll ready Work Graph tickets (hq's first generation).** Reuses the queue and needs no
  webhook, but adds idle Neon reads and latency, and the pilot showed it turns judgement-heavy
  tickets into a review queue. Rejected.
- **Custom provider and session adapters.** Gives full control over models and sessions, at
  the cost of rebuilding and maintaining what T3 Code ships. Rejected while T3 Code covers it.
- **An unbound webhook task, one fresh thread per delivery.** Simpler, but related check
  failures for one PR would each start a session; a bound controller deduplicates and
  correlates first.
- **Start with Dependabot alerts, as hq does.** Higher value per incident, but alerts need
  severity policy and production validation. Failing Renovate PRs exercise the same loop with
  a smaller, already-defined end state.

## Consequences

- Agents start on failing updates without the owner noticing them first, and each outcome has
  a Work Graph item with linked PR, CI and deployment evidence.
- T3 Code becomes a runtime dependency of the coordinator. A regression in its webhooks,
  threads, worktrees or PR watching stops the workflow; the reviewed version pin (ADR 25)
  limits that to deliberate upgrades.
- Workers merge their own PRs within branch protection. A bad fix lands on `main`, and the
  delivery contract's rollback (revert through the same gates) applies.
- Webhook payloads carry text any GitHub user can write. Passing identity fields only and
  re-fetching state keeps that text out of the prompt, though the worker still reads PR and
  log content while it works.
- Two records hold related identities, T3 threads and Work Graph items. A missing mapping must
  stop automatic routing, not be guessed.
- If no webhook arrives, nothing runs. Missed deliveries are redelivered from GitHub by hand
  until a low-frequency reconciliation is added; revisit if misses are seen.
- Revisit when the workflow has handled real failures: widen admission, raise concurrency, or
  add the next workflow only once outcomes are trustworthy.
