<!-- Adapted from Robbie-Palmer/hq (.agents/skills/complete-pr-review-loop/references/review-loop.md), AGPL-3.0. -->

# Complete the PR review loop

Prepare completed work, publish a draft PR, and stay with it until it is
settled. Merge only when the user or the repository's `AGENTS.md` authorizes
you to; otherwise leave it ready for human review.

## Before opening the PR

Do not use the PR as the first test run.

1. Sync with the intended base and inspect the full diff.
2. Match tests to the changed behavior. Use unit tests for isolated logic,
   integration tests for boundaries, and browser tests for workflows that
   lower-level tests cannot cover.
3. Run the relevant local tasks from `AGENTS.md`, including any coverage
   requirement it sets. Match CI locally where possible: the repository pins
   its tools with mise, so `mise exec -- <tool>` runs the same versions CI
   does.
4. Fix local failures. If infrastructure prevents a check from running, record
   the limitation. Do not open a PR to discover a predictable lint, test, or
   coverage failure.

Commit only the intended work, push it, and open or reuse a draft PR. Include
an accurate summary, validation results, and any specific QA need. If the
change touches Terraform, include the plan summary and call out every destroy
or replace.

## Write PR descriptions from files

Write the PR description as a Markdown file, then pass it to GitHub with
`gh pr create --body-file <path>` or `gh pr edit --body-file <path>`. Do not
put a multiline description in an inline shell argument. Markdown backticks
can run as command substitutions, and `\n` inside an ordinary quoted argument
can reach GitHub as literal text.

If `gh pr edit` fails while querying deprecated Projects Classic metadata, use
`gh api --method PATCH repos/<owner>/<repo>/pulls/<number> -F body=@<path>`.
This fallback also reads the body from the file without shell interpolation.

After creating or editing a PR, fetch the stored body once with `gh pr view`
and inspect the rendered text. Fix literal `\n` sequences, ANSI control
characters, captured command output, or damaged Markdown before starting the
review cycle.

## Review cycle

After a push or PR state change, wait for results instead of live-polling. If
the host can watch the PR and wake you on check or review changes, use that.
Otherwise wait roughly 3 to 5 minutes before taking one current-state snapshot.

Inspect:

- CI failures and expected skips, including the required `ci` check;
- review comments, change requests, and unresolved threads;
- code scanning alerts raised on the PR (gitleaks, zizmor); and
- rolling bot comments that may have changed in place.

Treat results as stale after a push. Trust GitHub's association between checks
and the PR head unless recent changes or conflicting evidence create a real
staleness risk.

Classify each finding as a true issue, worthwhile nit, stale or duplicate, or
false positive. Fix true issues, add regression coverage, and give concise
evidence when rejecting a finding. Batch coherent fixes, rerun local checks,
push, and repeat the cycle. Avoid code churn for reviewer preference alone.

Reply to each review thread with its disposition and evidence before resolving
it. Keep legitimate unfinished findings open.

## Draft and ready phases

Keep the PR in draft until required checks pass, expected skips are
understood, draft-visible reviews are settled, and all fixes are pushed.
Refresh once for late feedback, then mark it ready for review.

Wait for any ready-only reviewers, then repeat the review cycle.

## Completion gate

Finish when the PR is ready for review and:

- required checks pass;
- no true reviewer or scanner finding remains;
- remaining nits and false positives have explicit dispositions; and
- no fix is uncommitted or unpushed.

If you are authorized to merge, squash-merge, sync the base branch locally,
and run any post-merge step `AGENTS.md` requires, such as a Terraform apply.
The work is done when the change is merged and verified, not when the PR is
open.

Report the PR URL, final commit, validation status, review rounds, and
material limitations.
