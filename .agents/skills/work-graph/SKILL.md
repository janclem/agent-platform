---
name: work-graph
description: Use the deployed Work Graph to find, claim, update, prioritize, or finish tickets from any project repository. Do not use merely because a task changes Work Graph code.
---

<!-- Adapted from Robbie-Palmer/hq (.agents/skills/work-graph), AGPL-3.0. -->

# Work Graph

The Work Graph is the shared queue and record of work for every project built on
`janclem/agent-platform`. Use the `work-graph` CLI as the agent interface. Start
with `work-graph prime` when the available commands or local setup are unclear.

## Setup

Install or update the CLI from an `agent-platform` checkout with
`mise run work-graph-cli:install`; afterwards `work-graph self-update` from that
checkout rebuilds it. `pr attach` also needs an authenticated `gh`.

Credentials load automatically. When `WORK_GRAPH_API_URL` is not set, the CLI
re-runs itself under `doppler run` with the `work-graph/prd_work_graph_agents`
config, which holds only the Access service-token pair, the API URL and the
allowed origins. Locally that resolves through the operator's Doppler login;
elsewhere set `DOPPLER_TOKEN` to a read-only service token for that config.
Never print, copy, or persist the Access values.

Codex thread IDs and Claude Code session IDs become the worker identity
automatically. `WORK_GRAPH_WORKER_ID` overrides them; other clients must set it
to use the implicit active-lease workflow.

## Compact invocations

Treat an explicit `$work-graph` invocation as a request to select or identify the
ticket, claim it, and carry it through its normal implementation and verification
workflow. A user can narrow or override that scope in the rest of the prompt.
Do not infer permission to merge, deploy, or release without the usual authority
and evidence in the repository's delivery contract.

- `$work-graph <ticket-id>` targets that exact ticket. Inspect it before claiming.
  If it cannot be claimed, report why instead of substituting another ticket.
- `$work-graph project <project-id>` selects the highest-priority ready ticket in
  that project, then claims and executes it.
- `$work-graph initiative <initiative-id>` does the same within an initiative.
- `$work-graph next` selects the highest-priority ready ticket without a scope
  filter.
- `$work-graph no-conflicts` selects a ready ticket that is unlikely to overlap
  active work. Inspect active tickets, their notes and metadata, relevant
  dependencies, current worktrees, and likely files before claiming. Prefer the
  highest-priority candidate with no expected code or operational overlap.
- Selection arguments can be combined, for example `$work-graph project
  work-graph no-conflicts`. Apply the scope filter before comparing candidates
  for overlap.

Conflict avoidance is a best-effort judgment, not a guarantee. If every useful
candidate has material overlap or the available evidence is too weak, stop and
report the candidates and risks instead of claiming one.

## Normal loop

1. Run `work-graph ready`. Inspect a candidate with `work-graph show <ticket>`.
2. Run `work-graph claim [ticket]`. With no ticket, the server chooses the
   highest-priority ready item that has never been claimed. Use repeatable
   `--exclude-project` or `--exclude-initiative` to avoid scopes. Specify the
   ticket ID to continue work after resolved attention or to recover a stale lease.
3. As soon as the pull request exists, link it:
   `work-graph pr attach <ticket> <pr-url> --role implementation`. The GitHub
   observer attaches CI and deployment evidence only through this explicit link,
   never by branch name, title, or timing.
4. Record durable findings or a handoff with
   `work-graph note <ticket> --content "..."`. The CLI finds the active lease
   and fencing epoch. Run `work-graph touch <ticket>` before a lease expires.
5. After merging, finish the ticket as described in the next section before
   ending the turn.

## Finish after merge

Never end a turn holding a lease on finished work. A blocking attention request
is the only sanctioned way to stop with the work unfinished. Decide each step
from command output, not from judgement:

1. Keep the lease alive: `work-graph touch <ticket>` before every wait, and
   between waits if one may outlast the lease (`--lease-duration-seconds`
   lengthens it, default 900).
2. Find what must pass. Get the merge commit with
   `gh pr view <pr> --json mergeCommit,files`. The changed paths select targets
   in `.work-graph/delivery-targets.yaml`; each names `required_ci_names` and
   `production_environments`. Without that file, use the delivery contract.
3. Wait for each required run at the merge commit:
   `gh run list --commit <sha> --json databaseId,name,status,conclusion`, then
   `gh run watch <id> --exit-status`. Confirm each environment deployed it:
   `gh api "repos/<owner>/<repo>/deployments?sha=<sha>&environment=<env>"`,
   then `gh api <statuses_url> --jq '.[0] | .state, .url'` must print `success`
   and the status URL used as deployment evidence.
4. Check release state with `work-graph show <ticket>`: `lifecycle` and
   `completionCandidate` show whether the completion policy released it. If it
   is still open, release it yourself with the PR URL and the successful
   deployment status URL:
   `work-graph release <ticket> --merge-evidence <pr-url> --deployment-evidence <status-url>`.
5. Confirm with `work-graph metadata releases <ticket>`, which lists the release
   event, its actor and time. Only then end the turn.

If a required run or deployment fails, read it with `gh run view <id>
--log-failed` and fix forward: a new PR linked to the same ticket as
`implementation`, then repeat these steps for its merge. If fixing forward needs
authority, access or a decision you lack, raise `work-graph attention request
<ticket> --kind <kind> --question "..."` naming the single decision, and stop.

The observer's lease-expiry sweep releases a completion candidate whose lease
has lapsed. It is a safety net for agents that crash or lose their session, not
the release path.

What counts as deployed, and which CI and environments must pass, comes from the
repository's `.work-graph/delivery-targets.yaml` and its delivery contract.
For changes to the `work-graph` CLI itself, installing the merged client is part
of deployment: pull the merged revision, run `work-graph self-update` from that
checkout, and verify the changed command before releasing the ticket.

`note`, `touch`, `decompose`, `attention request`, `release`, and `cancel` use
the ticket's active lease. Pass `--lease-id` and `--epoch` together only when a
script already has both values.

`ready` and other ordinary commands already write JSON to stdout. Do not
append a bare `--json`. The `--json` option normally requires a complete input
object, for example `work-graph ready --json '{"limit":10}'`. The one exception is
`work-graph critical-path --json`, where the bare option selects the full JSON
projection instead of the human-readable summary.

## Plan with the critical path

Run `work-graph critical-path` for the global plan. Narrow an owner review with
repeatable `--initiative <initiative>` or `--project <project>`. Use
`--root-work-item-id <ticket>` to explain one exact outcome. Do not combine a
root filter with any inclusion or exclusion filter.

`ready`, `queue`, implicit `claim`, and `critical-path` accept repeatable
`--project`, `--exclude-project`, `--initiative`, and `--exclude-initiative`.
Each occurrence adds one literal ID. Inclusions use OR within one kind and AND
across project and initiative kinds. Exclusions take precedence. An explicit
ticket claim rejects selection flags. Complete JSON input uses
`includeProjectIds`, `excludeProjectIds`, `includeInitiativeIds`, and
`excludeInitiativeIds`.

Read a blocking path from its priority outcome to the unresolved leaf. Paths
can cross decomposition and dependency edges. `ready` leaves can start now,
`active` work already has a lease, `stale` work can be reclaimed, and
`needs_attention` requires the recorded human response. Parallel branches are
claimable leaves that can advance independently. Prefer the highest-priority
branch that fits the requested scope.

Use `work-graph critical-path --json` for the full projection. Consume `nodes`
and `edges` as the deduplicated graph, `targetOutcomeIds` as the selected
outcomes, `blockingPaths` as the explanations, and `readyLeafIds` and
`parallelBranches` as work-selection inputs. `blockingAttentionIds` lists
items that need a human response. Inspect `inclusionReasons` when an item's
presence is surprising.

The result is a live structural projection. It does not estimate duration or
delivery dates. Verify a surprising path with `work-graph show <ticket>`,
`work-graph metadata dependencies <ticket>`, and `work-graph metadata
decompositions <ticket>`. Revise stored graph state with the commands below,
then rerun the projection.

## Changes to the plan

- Reorder a ticket with `work-graph priority move <ticket> --above <ticket>` or
  `--below <ticket>`. Ticket order is local to its scheduling project.
- Remove a project or initiative from active scheduling with `work-graph scope
  archive <scope> --reason "..."`. Use `scope restore` to return it at the
  median active rank and `scope list --all` to audit archived scopes.
- Add a blocking edge with
  `work-graph dependency add <dependent> <blocker>`.
- Use `work-graph expedite <ticket> --reason "..."` only for an explicit
  interruption. An expedite temporarily donates urgency to unresolved blockers.
- Use `work-graph attention request` when progress needs a decision, authority,
  access, review, or help. A blocking request ends the lease.
- `cancel` means the outcome is no longer wanted. It is not a way to return
  unfinished work to the queue.

Prefer the short commands above. Use `metadata`, explicit lease fields, and
complete `--json '<object>'` input only for audits, recovery, or automation
that needs fields unavailable as ordinary flags.
