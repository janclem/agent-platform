# Work Graph API

This Cloudflare Worker serves the Work Graph REST contract in `openapi.json` (ADR 16).
Production runs at `https://work-graph.clemetson.me` behind Cloudflare Access with a
Service Auth policy (ADR 17). `infra/work-graph` owns the service name, domain, Access app,
and Hyperdrive; Wrangler owns application versions. The Wrangler config disables
`workers.dev` and preview URLs.

## Deploying

Every merge to `main` that touches the API, its packages, the lockfile or `mise.toml` runs
[`work-graph-cd.yml`](../../.github/workflows/work-graph-cd.yml): migrate, deploy, then
smoke-test, in the `production-work-graph` environment (deployable only from `main`). Its
one secret, `DOPPLER_TOKEN`, is a read-only service token for `work-graph/prd_work_graph`
that expires 2027-11-12. Rerun it with `gh workflow run work-graph-cd.yml`. The same tasks
work locally with your Doppler login:

```bash
mise run work-graph:migrate            # migrations against Neon directly, DATABASE_URL from Doppler
mise run work-graph:deploy             # deploy token, account ID and Hyperdrive ID from Doppler
mise run work-graph:smoke-production   # Access rejects anonymous requests; queue reads work
```

All three read from Doppler `work-graph/prd_work_graph` (ADR 23) and take only the values
they need.

Migrate before deploying, since new code may need the new schema. `scripts/deploy.sh`
substitutes the Hyperdrive ID into a private temporary copy of `wrangler.toml`; the
committed file keeps a placeholder. `mise run work-graph:api` runs a credential-free
`deploy.sh --dry-run` build.

## Checks

`mise run work-graph:api` runs everything below, and `mise run ci` includes it:

- `openapi.json` matches the routes, and Spectral passes it with the shared rules in
  `api-governance/` plus the OWASP ruleset;
- `oasdiff` finds no breaking change against `main`, unless `info.version` was bumped to
  make the break deliberate;
- the CLI's generated client matches the contract, and the CLI builds and packs;
- the bundled Worker starts in workerd;
- HTTP integration tests run against a throwaway PostgreSQL. They need Docker.

After changing a route, run `pnpm --filter work-graph-api openapi:generate` and
`pnpm --filter work-graph-cli openapi:generate`, then commit both outputs.

## Request limits

The Worker starts on the Workers Free plan (ADR 22). Queue reads and
critical-path projections process the dependency graph in the Worker, and hq
found they exceed the Free plan's 10 ms CPU limit once the graph holds several
hundred tickets. Cloudflare then answers with error 1102 and the Worker's
observability logs record an `exceededCpu` outcome. That outcome is the trigger
to move to Workers Paid and restore an explicit `[limits] cpu_ms` ceiling in
`wrangler.toml`, which Free accounts can't set.

The database migration sets a 5-second lock timeout, 15-second statement
timeout, and 10-second idle-in-transaction timeout on the dedicated
`work_graph_owner` role for the Work Graph database. On PostgreSQL 17 and later,
it also sets a 20-second transaction timeout. These limits sit below the CLI's
30-second request timeout. They give the Worker time to roll back an aborted
transaction and return HTTP 503 with `Retry-After: 1` instead of holding a
Hyperdrive connection until the client disconnects.

The Worker also maps transient connection capacity to HTTP 503. This includes
PostgreSQL `too_many_connections` and `cannot_connect_now`, plus Hyperdrive's
documented pool-acquisition and temporary infrastructure failures. Each 503
includes `Retry-After: 1`, an `X-Request-Id` correlation header, and the same
request ID in the JSON error. The Worker logs that ID with the request method,
path, and stable error code. It does not log database error text.

Lease claims are intentionally not replayable. If a transient database failure
occurs after a claim may have been committed, the Worker returns
`claim_outcome_uncertain` without `Retry-After` and tells the caller to inspect
the work item before claiming again.

## Routes

`GET /api/work-items` accepts `initiativeId`, `projectId`, and `parentId`
filters. `POST /api/leases` accepts the same filters when it selects the next
ticket. The service computes global priority first, then filters that order.
`PUT /api/work-items/{workItemId}/scheduling-scope` assigns an existing root
ticket to an initiative and project; descendants inherit the assignment.
`PUT /api/work-items/{workItemId}/parent` replaces the ticket's parent. Send a
null `parentId` to detach it to the graph root. The operation preserves the
ticket and its history, and rejects cycles across hierarchy and dependency
edges.

`GET /api/work-items/{workItemId}/evidence` returns immutable delivery-evidence
observations correlated through the ticket's pull requests. Records include
provider identity, kind, state, commit, environment, source URL, provider and
ingestion times, correlation fields, and a `current` marker. Use
`currentOnly=true` for the current projection and `nextCursor` for the next
page. `GET /api/work-items/{workItemId}/completion-candidate` returns the latest
evaluation with its policy revision, or null before the first evaluation.
Current evidence also appears after the normal records in claim context.

Knowledge-scope lists and relationship lists return active scopes by default.
Pass `includeArchived=true` for an audit view. Send `POST` to
`/api/knowledge-scopes/{knowledgeScopeId}/archival` to archive a scope with a
reason after checking that it schedules no open work. `DELETE` on the same URL
restores it at the median active rank. Source snapshot updates preserve the
Work Graph-owned lifecycle.

## Note history

`POST /api/work-items/{workItemId}/notes` records lease-fenced notes while work
is active. `POST /api/work-items/{workItemId}/comments` appends attributed
discussion only after release. Both forms are append-only and appear in the
notes collection. A comment does not change the work-item row, the release
event or its evidence, or any lease. Cloudflare Access rejects unauthenticated
and unauthorized requests before they reach the Worker with HTTP 401 or 403.

## Note history

`POST /api/work-items/{workItemId}/notes` records lease-fenced notes while work
is active. `POST /api/work-items/{workItemId}/comments` appends attributed
discussion only after release. Both forms are append-only and appear in the
notes collection. A comment does not change the work-item row, the release
event or its evidence, or any lease. Cloudflare Access rejects unauthenticated
and unauthorized requests before they reach the Worker with HTTP 401 or 403.

## Not adopted yet

These parts of hq's Worker are left out until their decisions call for them:

- **MCP adapter:** added after the CLI proves the operations (ADR 16).
- **Cedar authority profiles:** added with the first read-only client. `src/authorization.ts`
  keeps hq's interface and allows every authenticated client (ADR 17).
- **Analytics export and its cron trigger:** ADR 20.
- **Production diagnostics:** need a Cloudflare API token.

Adapted from Robbie Palmer's [`hq`](https://github.com/Robbie-Palmer/hq)
`workers/work-graph-api` at commit `6c08a3b`, under the AGPL-3.0.
