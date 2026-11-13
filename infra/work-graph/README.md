# Work Graph infrastructure

Adapted from Robbie-Palmer/hq (`infra/work-graph`) at `6c08a3b`, AGPL-3.0.

This Terraform root provisions the production Work Graph service:

- the `work-graph-api` Worker service name, with a fail-closed bootstrap
  version, and its custom domain `work-graph.clemetson.me`;
- the Cloudflare Access application and a service-token-only policy (ADR 17);
- the private R2 bucket for encrypted database backups (ADR 21);
- the dedicated Neon project, the Hyperdrive configuration and the Access
  service token, through credential helpers described below.

HCP Terraform stores the state in the `terraform-clemetson/work-graph`
workspace, which uses local execution.

Hyperdrive's origin connection limit is 20, the most Workers Free accepts
(ADR 22). hq uses 60 on Workers Paid; raise it when the account upgrades.

## Why credentials bypass state

The Neon provider reads the default role password into state. Cloudflare's
Terraform resources do the same for an Access service-token secret and a
Hyperdrive origin password. Marking those attributes sensitive hides them from
normal output but does not remove them from state.

So this root uses three small API helpers during apply:

1. `provision-sensitive-resources.sh` creates or finds the Neon project,
   Hyperdrive configuration, and Access service token. It sends the database
   URL, Hyperdrive ID and token pair straight to Doppler config
   `work-graph/prd_work_graph` (ADR 23).
2. `read-resource-metadata.sh` returns only IDs, host, database and role names
   to Terraform.
3. `install-hyperdrive-origin.sh` reinstalls the Neon origin through
   Cloudflare's API when its coordinates change or during password rotation.

The helpers disable shell tracing, keep request and response bodies in a
mode-0700 temporary directory, pass bearer headers through mode-0600 curl
config files, and delete every temporary file on exit. They never print secret
values.

`check-security-boundary.sh` runs in CI and rejects credential-bearing
resources or expressions. After every apply, `check-state-for-credentials.sh`
rejects provider resources that return credentials, PostgreSQL URLs with
passwords, and sensitive outputs in the raw state.

## Credentials

Runs read their credentials from 1Password through `op run` and
[`op.env`](op.env), which holds only `op://` references:

| Variable | 1Password item (vault `agent-platform`) |
|---|---|
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | `cloudflare-work-graph-infra` |
| `NEON_API_KEY`, `NEON_ORG_ID` | `neon-work-graph-infra` |
| `WORK_GRAPH_DOPPLER_SERVICE_TOKEN` | `doppler-work-graph-writer` |

The Cloudflare token needs, at account scope, Workers Scripts, Hyperdrive,
Access: Apps and Policies, Access: Service Tokens and Workers R2 Storage
edit; and for the `clemetson.me` zone only, Zone read and Workers Routes edit.
The Neon key is an organization API key. The Doppler token is read/write on
`work-graph/prd_work_graph` only. HCP access comes from `terraform login`.

## Running

```bash
mise run work-graph-infra:plan    # writes infra/work-graph/.planfile
mise run work-graph-infra:apply   # owner-approved only; applies the plan, checks state, records it
```

Agents run `plan` and report; only the owner authorizes `apply`.

After a successful apply from a clean checkout of the current `origin/main`,
`scripts/record-deployment.sh` records a GitHub deployment to
`production-work-graph-infra` for that commit, using the operator's `gh` login. That
deployment is the delivery evidence the Work Graph observer needs before a ticket that
changed `infra/work-graph` can count as done. Applies from anywhere else skip the record
and say why. It then records deployments for the earlier `main` commits that changed
`infra/work-graph` since the previous recorded apply, because this apply delivered them
too (`mise run work-graph:record-covered-deployments`).
