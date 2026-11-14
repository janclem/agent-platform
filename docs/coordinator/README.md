# Agent coordinator

The coordinator admits GitHub events under a checked-in policy and launches one T3 Code
worker thread per outcome, recording each outcome as a Work Graph item. The decision is
[ADR 26](../adr/0026-agent-coordinator-on-t3-code-renovate-repair-first.md); how webhooks
reach it is [ADR 27](../adr/0027-coordinator-webhook-ingress-through-t3-connect.md).

Adapted from Robbie Palmer's second-generation coordinator in
[hq](https://github.com/Robbie-Palmer/hq) (projects/agent-coordinator ADR 001, ADR 002,
PDR 001 and its `controller-policy.json`). Differences: a plain JSON policy instead of
Cedar (ADR 24 is the later option), failing Renovate PRs instead of Dependabot alerts, and
no unattended authority beyond what a worker already has under the
[delivery contract](../runbooks/agent-platform-delivery.md).

## Workflows

| Workflow | Policy | Controller | Worker brief |
| --- | --- | --- | --- |
| Repair failing Renovate PRs | [controller-policy.json](renovate-repair/controller-policy.json) | [controller.md](renovate-repair/controller.md) | [worker-brief.md](renovate-repair/worker-brief.md) |

- **Policy**: what the controller may admit. It reads the file from `main` on every event.
- **Controller instructions**: what the persistent controller thread does with each webhook
  prompt.
- **Worker brief**: the prompt the controller fills in and hands to each worker thread.

## Validating the policy

`mise run coordinator:policy-check` (part of `mise run ci`) runs
[`scripts/check-coordinator-policy.sh`](../../scripts/check-coordinator-policy.sh). It
rejects unknown or missing keys, wrong types, and values ADR 26 fixes: the repository
shape, a `Bot` author, the `workflow_run`/`completed`/`failure` trigger, failing required
checks, the `homelab/` and `infra/` exclusions, a concurrency of 1, and the work-item ID
template. Its `--self-test` mode mutates the valid policy in several ways and fails CI if
any malformed variant is accepted.

Widening the policy (more repositories, more concurrency, fewer exclusions) is an
architectural change: record it in a new ADR, then change the policy and the check
together.

## Not here

The T3 webhook task, the GitHub webhook, T3 Connect and the controller thread itself are
configured by the owner under separate tickets. These files hold no secrets and name no
machines.
