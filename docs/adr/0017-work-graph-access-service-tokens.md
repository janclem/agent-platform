---
title: Authenticate Work Graph clients with Cloudflare Access service tokens, and add Cedar with the first read-only client
status: Accepted
date: 2026-11-09
---

# 17. Authenticate Work Graph clients with Cloudflare Access service tokens

Cloudflare Access protects the Work Graph API. Each headless client has its own service token.
Per-client authorization with Cedar is deferred until the first client that must not have full
access.

## Context

The API holds planning context and mutations meant for the platform's own agents, not the
public internet. Agents run headlessly on several machines, so interactive logins don't work.
ADR 13 runs services on Workers behind Cloudflare Access. Robbie authenticates this way in
[ADR 004](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/work-graph/adrs/004-cloudflare-access-service-auth.mdx). In
[ADR 013](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/work-graph/adrs/013-cedar-client-authorization.mdx) he adds Cedar, so different clients can get
different API subsets, such as full access or read-only.

## Decision

- **Authentication:** protect the API hostname with an Access self-hosted application and a
  Service Auth policy. Each client installation or service gets its own service token, sent
  in the `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers. Tokens are stored
  under ADR 4 and rotated with an overlap.
- **Identity:** the lease's worker ID is application data, not an authorization boundary.
- **People:** a later human interface uses GitHub as the Access identity provider, not email
  one-time codes.
- **Tailscale:** stays the access path for machines. The Cloudflare device client is not added.
- **Authorization:** every authenticated client gets full access for now.
- **Revisit trigger:** add Cedar authority profiles when the first client that should not
  mutate appears, such as a dashboard, a reporting job, or a read-only observer. Map each
  client to a profile in a trusted adapter, never from request data.

## Consequences

- Agents authenticate without a browser, and each token can be revoked alone.
- Until Cedar arrives, any leaked token can change any work item. Separate tokens per client
  limit that to revocation and an audit trail, not prevention.
- The CLI must protect two secret headers and never send them to another host.
- Token expiry and rotation become routine operations. Cloudflare shows a new secret once, so
  provisioning must store it immediately.
