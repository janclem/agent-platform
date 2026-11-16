# Renovate repair webhook task

How a failed Renovate workflow run reaches the [controller](controller.md): GitHub posts a
signed `workflow_run` event through T3 Connect
([ADR 27](../../adr/0027-coordinator-webhook-ingress-through-t3-connect.md)) to a T3 webhook
task, which prompts the controller thread. This file records the live configuration. The
webhook URL, which contains the task's access token, and the signing secret are deliberately
left out; never add them here or anywhere else in git or the Work Graph.

## Controller thread

**Coordinator: Renovate repair controller** is a top-level T3 Code thread in the
agent-platform project root checkout. It tracks `main` and never edits. Its auto-settle
behaviour is **Never**, set by the owner in the T3 UI.

## T3 webhook task

**Renovate repair: failed workflow_run**, a webhook-triggered scheduled task in the
agent-platform project. Read the live config with `list_scheduled_tasks` (read-only); its
`webhookUrl` field holds the token, so do not copy it out.

| Setting | Value |
| --- | --- |
| Bound thread | the controller thread above |
| `freshSession` | `false`: each delivery continues the controller thread's session |
| Signature | required; header `x-hub-signature-256`, encoding `hex`, prefix `sha256=` |
| Secret | entered by the owner through a T3 secret card; the owner keeps it in 1Password |
| Maximum delivery age | none |

### Filters

A delivery prompts the controller only when all of these hold:

| Path | Operator | Value |
| --- | --- | --- |
| `headers.x-github-event` | equals | `workflow_run` |
| `body.action` | equals | `completed` |
| `body.workflow_run.conclusion` | equals | `failure` |
| `body.repository.full_name` | equals | `janclem/agent-platform` |
| `body.workflow_run.head_branch` | startsWith | `renovate/` |

The filters only cut noise. The controller still validates every value and re-fetches the
pull request from GitHub ([controller.md](controller.md) steps 2 and 3).

### Dedupe

| Key | Template | Effect |
| --- | --- | --- |
| Replay key | `{{headers.x-github-delivery}}` | a redelivered GitHub delivery ID is not run twice |
| Coalesce key | `{{body.workflow_run.head_sha}}` | failed runs for the same commit within the window become one prompt |
| Coalesce window | 300 s | |

### Prompt

A pointer line, then exactly the identity-field block from [controller.md](controller.md)
step 2:

```text
Webhook prompt for the Renovate repair controller: follow docs/coordinator/renovate-repair/controller.md.
delivery_id={{headers.x-github-delivery}}
event={{headers.x-github-event}}
action={{body.action}}
repository={{body.repository.full_name}}
run_id={{body.workflow_run.id}}
conclusion={{body.workflow_run.conclusion}}
head_sha={{body.workflow_run.head_sha}}
pull_request={{body.workflow_run.pull_requests.0.number}}
```

`.0` resolves the first array element in T3 0.1.9. If the two blocks ever differ, change
controller.md and the task together.

## GitHub webhook

The owner created the repository webhook by hand in **janclem/agent-platform → Settings →
Webhooks**:

| Setting | Value |
| --- | --- |
| Payload URL | the task's webhook URL |
| Content type | `application/json` |
| Secret | the same secret as the task |
| Events | **Let me select individual events** → only **Workflow runs** |

GitHub's ping got a 202 from the T3 relay.

### Why it is not in Terraform

The GitHub provider's `github_repository_webhook` keeps the webhook secret, and the URL with
its token, in Terraform state. [ADR 23](../../adr/0023-doppler-for-machine-secrets.md) keeps
generated credentials out of state, so the webhook stays owner-managed by hand. Bringing it
under Terraform needs an owner decision, recorded as a new ADR.

## Operating it

### Rotate the secret

1. Generate a new secret on the Mac, for example `openssl rand -hex 32`, and update the
   1Password item.
2. In T3, open the task's editor, re-enter it under **Require signature**, and save.
3. In GitHub's webhook settings, enter the same secret and save.

Deliveries between steps 2 and 3 fail signature checks; redeliver them afterwards (below).

T3's **Rotate** action replaces the webhook URL, and with it the token. After rotating, give
the new URL to GitHub's **Payload URL** straight from the T3 UI, or every delivery fails.

### Check deliveries

- **GitHub**: the webhook's **Recent Deliveries** tab lists each delivery with its response
  code and body. The T3 relay answers 202 when it accepts a delivery.
- **T3**: the task's **Deliveries** menu shows how each delivery was handled. GitHub's ping
  carries `x-github-event: ping`, so it shows as **Filtered**, not rejected. A rejected
  delivery usually means the secrets in T3 and GitHub differ.

### Redeliver after downtime

T3 Connect's **Hold webhooks while offline** is off (ADR 27), so deliveries that arrive while
the host is down are lost to T3. In GitHub's **Recent Deliveries**, open each failed
`workflow_run` delivery and choose **Redeliver**. The replay key drops any that did arrive.
Alternatively ask the controller thread for a rebuild: it finds every failing Renovate PR
from GitHub without the deliveries ([controller.md](controller.md), "After a restart").

### Pause

Either:
- disable the task in T3 (deliveries then do not prompt the controller), or
- untick **Active** on the webhook in GitHub (GitHub stops sending).

Re-enable it the same way, then request a rebuild to catch up.
