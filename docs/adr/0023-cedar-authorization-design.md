---
title: Authorize Work Graph clients with a shared fail-closed Cedar package and trusted profile mapping
status: Accepted
date: 2026-11-11
---

# 23. Authorize clients with a shared fail-closed Cedar package and trusted profile mapping

When ADR 17's trigger fires, Cedar comes in through a shared `packages/cedar-authorization`
package that turns every policy error into a denial. Each service owns its schema and
policies, and a client's authority profile comes only from its verified Cloudflare Access
identity. This records the design now, so the first restricted client does not reopen it.

## Context

ADR 17 authenticates every client with a Cloudflare Access service token and gives each one
full access. It defers Cedar until a client appears that must not mutate, such as a
dashboard, reporting job, or read-only observer. It does not say how Cedar is loaded,
where policies live, or how a request maps to a profile.

Robbie has since settled those questions. In
[platform ADR 049](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/personal-engineering-platform/adrs/049-cedar-authorization-engine.mdx)
he makes Cedar the default engine for every TypeScript service. In
[Work Graph ADR 013](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/work-graph/adrs/013-cedar-client-authorization.mdx)
he applies it with full and read-only profiles. Our API kept the request shape of his
authorizer (`services/work-graph-api/src/authorization.ts`), so his policy set can drop in
behind the existing middleware. The ADR 19 webhook intake and any later service will need
the same mechanics, so they should not live inside one service.

Cedar runs as WebAssembly ([`@cedar-policy/cedar-wasm`](https://www.npmjs.com/package/@cedar-policy/cedar-wasm)).
hq patches version 4.14.0 because workerd exposes the `.wasm` import as a
`WebAssembly.Module` that the package does not instantiate itself.

## Decision

- **Shared package:** adapt hq's `packages/cedar-authorization`. It compiles named static
  policies against a schema in strict validation mode. It rejects policy templates, policies
  without an `@id`, and duplicate IDs. It returns a denial for any parser, validation,
  warning, or evaluation diagnostic. A policy set that fails to compile stops the Worker
  from starting instead of serving with partial rules.
- **Service-owned policy:** each service keeps its Cedar schema, policies, action
  vocabulary, and tests next to the code that builds its entities. The package contains no
  service rules.
- **Work Graph profiles:** start with hq's `authority:work-graph-full` and
  `authority:work-graph-read-only`. Read-only clients may perform `api.read`. A `forbid`
  policy blocks them from `api.write`, and from `mcp.invoke` once the MCP adapter exists
  (ADR 16). Human-only actions and other hard limits are also written as `forbid`, so a
  broader permit cannot override them.
- **Trusted identity mapping:** the Worker verifies the `Cf-Access-Jwt-Assertion` header
  against the Access application's signing keys. It then maps the service token's client ID
  to a profile through checked-in configuration. A missing, invalid, or unmapped identity
  is denied. Request bodies, headers other than the verified assertion, lease worker IDs,
  and MCP arguments never select a profile.
- **Audit:** an allowed mutation records its determining policy IDs with its event (ADR 20).
- **Layering:** a Cedar permit only lets a caller attempt an operation. Lease fencing,
  cycle checks, idempotency, lifecycle transitions, and SQL row filtering stay in the domain
  and repository layers (ADR 15).
- **Runtime proof:** any Worker that embeds Cedar is started in workerd by its check task.
  A dry-run bundle does not prove that the WebAssembly module initializes.
  `mise run work-graph:api` already does this for the Work Graph.

## Alternatives

- **Hand-written TypeScript checks per service:** no WebAssembly and easy to step through.
  They fit while there is one full-access profile, which is why ADR 17 waits. Once read-only
  clients, prohibitions, and a second service appear, each would fail differently and be
  harder to review. A service with one stable owner check may still use them.
- **Cloudflare Access policies per path:** keeps authorization at the edge with nothing in
  the Worker. Read and write share the same paths and differ by HTTP method, and Access
  applications match hostnames and paths, not methods. Split hostnames or paths would also
  leave the authority profile invisible to the API's event log.
- **A central authorization service:** one decision point for every caller, at the cost of
  a network hop, an availability dependency, and shared entity models. The facts each
  decision needs are already local to the Worker.

## Consequences

- One loader and one failure behavior serve every service. Policies stay reviewable next to
  the code they protect, and a read-only client gets no mutation authority.
- The identity mapping becomes security-sensitive code with its own tests: unknown client,
  bad signature, wrong audience, and expired assertion must all deny.
- Each Worker carries the Cedar WebAssembly module, which adds bundle size, startup work, and
  CPU on every request. On Workers Free (ADR 22) that counts against the 10 ms limit, so the
  PR that adds Cedar measures its per-request cost. If a startup or request exceeds the
  limit, ADR 22's trigger applies.
- We carry a patch to `@cedar-policy/cedar-wasm` until upstream handles workerd's module
  form. Renovate updates to the package must rebase or drop the patch, and must pass the
  workerd start check before they merge.
- A schema change and a policy change form one compatibility boundary. Changing an action or
  entity updates both, and must pass strict validation before release.
- Until a restricted client exists, this record changes no code. When the first one is
  planned, port the package and policies in its PR, not before.
