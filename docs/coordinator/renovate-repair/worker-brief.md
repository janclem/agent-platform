# Renovate repair worker brief

The template the [controller](controller.md) fills in and hands to each worker thread
([ADR 26](../../adr/0026-agent-coordinator-on-t3-code-renovate-repair-first.md)). It also
becomes the item's Work Graph brief. Placeholders are in angle brackets; the controller
fills them from GitHub and the policy, never from the webhook body. Everything below the
line is the prompt.

---

Work Graph item `<item-id>` in `<repository>` (project `<scheduling-project>`). The
coordinator admitted it under policy revision `<policy-revision>`; you own it until you
release it or raise attention.

Renovate PR: <pr-url> (head branch `<head-ref>`, head commit `<head-sha>`). Its failing
required checks when admitted: <check names and links>. Your worktree is on `<head-ref>`.

Goal: make this update ship. Fix the code on the PR's branch so its required checks pass,
or conclude that it cannot ship and say which decision the owner must make.

Use the `work-graph` skill and follow `AGENTS.md` and
`docs/runbooks/agent-platform-delivery.md`. In order:

1. `work-graph claim <item-id>`, then read the brief and acceptance criteria with
   `work-graph context show <item-id>`. Link the PR straight away:
   `work-graph pr attach <item-id> <pr-url> --role implementation`.
2. Read the failure from GitHub: `gh pr checks <pr> --required`, then
   `gh run view <run-id> --log-failed`. Reproduce it locally with the matching `mise run`
   task.
3. Fix it with the smallest change that lets the update ship. Do not revert or pin back
   the update to make checks pass; that is the owner's decision. Do not touch `homelab/`
   or `infra/`. If the fix needs either, or needs authority, access, a new ADR, or a
   judgement the owner should make, raise
   `work-graph attention request <item-id> --kind <kind> --question "..."` naming the
   single decision needed, wake the controller (step 8), and stop.
4. Commit as `janclem` only: no `Co-authored-by` trailers and no "Generated with"
   footers. Stage files by path; never `git add -A` or `git add .`. Push to `<head-ref>`.
5. Run `work-graph touch <item-id>` before every wait. Wait in the foreground only, with
   `gh run watch <id> --exit-status`. Never end a turn on a background task, a scheduled
   wakeup or a promise to resume.
6. When every required check passes, run the skill's "Check delivery targets" step, then
   squash-merge with an explicit message that names only `janclem`:
   `gh pr merge <pr> --squash --subject "<title> (#<pr>)" --body "<one-line summary>"`.
7. Follow the skill's "Finish after merge" section: wait for the required CI runs at the
   merge commit, confirm each production environment in `.work-graph/delivery-targets.yaml`
   deployed it, and release the item with evidence:
   `work-graph release <item-id> --merge-evidence <pr-url> --deployment-evidence <status-url>`.
   Confirm with `work-graph metadata releases <item-id>`. Never end your turn holding a
   lease on finished work: release with evidence, or raise a blocking attention request.
8. Wake the controller: send its thread `<controller-thread>` exactly
   `worker ended: <item-id>`. It re-reads GitHub before admitting the next PR.

If a required run or deployment fails after merge, fix forward in a new PR linked to the
same item as `implementation`, and repeat steps 5 to 8 for its merge.

Acceptance criteria:
1. The PR's required checks pass with the update in place, or a blocking attention request
   names the decision that prevents it.
2. The PR is squash-merged as `janclem` only.
3. The merge commit's required CI runs passed and its production environments report a
   successful deployment.
4. `<item-id>` is released with merge and deployment evidence before the worker ends its
   turn, and the controller has been woken.
