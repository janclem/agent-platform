<!-- Adapted from Robbie-Palmer/hq (workers/work-graph-observer/README.md), AGPL-3.0. -->

# Work Graph observer

The Work Graph's only public ingress (ADR 19). It records GitHub's own facts about
pull requests, CI runs and deployments as delivery evidence, so completion doesn't
depend on agents reporting it.

- **Webhook:** `POST https://work-graph-observer.clemetson.me/webhooks/github`.
  It verifies `X-Hub-Signature-256` over the raw body before parsing, rejects
  oversized or malformed bodies, enforces the installation and repository
  allowlists, and queues the unchanged payload with its delivery ID and SHA-256
  digest. Responses: `202` queued, `401` bad signature, `400`/`413` invalid or
  oversized, `403` outside the allowlists.
- **Consumer:** reads `work-graph-github-deliveries` one batch at a time and writes
  through `work-graph-db` over Hyperdrive. Each message is acknowledged only after its
  transaction commits, retried up to three times, then moved to
  `work-graph-github-deliveries-dlq`. A repeated delivery ID is the idempotency key;
  the same ID with a different digest is rejected. Logs carry the delivery ID and
  disposition, never payloads.
- **Reconciliation:** every six hours (17 minutes past) it mints a short-lived
  installation token, loads each open ticket's linked implementation PR, and fetches
  the PR, its changed files, completed workflow runs and deployment statuses for the
  exact head and merge commits. These go through the same path as webhooks, with
  deterministic synthetic delivery IDs, so missed deliveries are repaired and
  repeats are harmless.

The observer has no route or binding to the Access-protected API.

## Correlation and delivery targets

Evidence attaches to a ticket only through an explicit `implementation` PR link and
an exact repository plus head or merge SHA. Branch names, titles and timing never
link anything. Shared commits that match several PRs stay unmatched.

Whether a merged PR's ticket can become a completion candidate depends on the
repository's [`.work-graph/delivery-targets.yaml`](../../.work-graph/delivery-targets.yaml),
which reconciliation reads from the default branch. Each target lists source paths,
the CI workflow names that must pass, and the GitHub deployment environments that
must report success. `tests/delivery-targets.test.ts` parses this repository's file
with the reconciler's own parser.

Ingestion never releases, cancels, claims or renews work.

## GitHub App

Register a private App from [`github-app-manifest.json`](github-app-manifest.json):
read-only Actions, Contents, Deployments, Metadata and Pull requests, subscribed to
`deployment_status`, `pull_request` and `workflow_run`. Contents is needed to read the
delivery-targets file and the default branch head; hq's App omits it.

```bash
services/work-graph-observer/scripts/register-github-app.py
```

It serves a page on `127.0.0.1:8765` that posts the manifest to GitHub, exchanges the
returned code, and writes `GITHUB_APP_ID`, `GITHUB_APP_PRIVATE_KEY`,
`GITHUB_WEBHOOK_SECRET` and `GITHUB_APP_CLIENT_SECRET` straight to Doppler
`work-graph/prd_work_graph`, printing none of them. Install the App only on the
repositories to observe, then record them as JSON arrays in
`GITHUB_ALLOWED_INSTALLATION_IDS` and `GITHUB_ALLOWED_REPOSITORIES`.

## Deploy

```bash
mise run work-graph:observer          # credential-free dry-run build (part of ci)
mise run work-graph:observer-deploy   # install secrets and deploy
```

Every merge to `main` that touches the Work Graph runs `work-graph-cd.yml`, which deploys
the observer after the API's migration, deploy and smoke test. The deploy reads the
Cloudflare deploy token, Hyperdrive ID and the five `GITHUB_*`
runtime values from Doppler, installs the runtime values as Worker secrets with
`wrangler secret bulk`, then deploys. The token needs Workers Scripts and Queues
edit. Terraform (`infra/work-graph`) owns the service name, hostname and queues.

Check a deployment by redelivering a recent event from the App's **Advanced → Recent
deliveries** page: expect `202` with the same delivery ID.

## Rotation and recovery

- **Webhook secret:** GitHub holds one at a time. Set the new value in GitHub and
  Doppler together, redeploy, then redeliver anything that failed in between.
- **Private key:** add a new key in GitHub, replace `GITHUB_APP_PRIVATE_KEY` in
  Doppler, redeploy, confirm a reconciliation run, then delete the old key.
- **Queue backlog:** on the Workers Free plan messages are kept for 24 hours, so a
  longer consumer outage relies on reconciliation. Inspect the queue and DLQ before
  retrying; redeliver from GitHub with the original delivery IDs and never edit a
  payload or invent an ID.
