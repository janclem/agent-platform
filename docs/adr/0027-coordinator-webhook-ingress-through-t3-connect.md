---
title: Receive coordinator webhooks through T3 Connect, with an exit through the observer and a Durable Object
status: Accepted
date: 2026-11-13
---

# 27. Receive coordinator webhooks through T3 Connect, with an exit through the observer

GitHub reaches the coordinator's webhook task (ADR 26) through T3 Connect, T3 Code's managed
relay and Cloudflare tunnel. This amends ADR 25's tailnet-only access: the agent host's T3
server becomes reachable from the internet behind T3's own authentication, as a second public
ingress beside the observer (ADR 19). We accept that trust for now, bound what it can reach,
and record the route back to a single public ingress.

## Context

ADR 25 publishes the T3 server only to the tailnet through Tailscale Serve, with no T3 Connect
relay. GitHub cannot reach the tailnet. ADR 26 needs GitHub to call a T3 webhook task.

In T3 Code 0.1.9 a public webhook URL
[needs a T3 Connect managed tunnel](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/user/project-settings.md#webhook-automations);
without one the editor shows only the URL's path. Whether that path answers directly on the
environment's own address, such as the Tailscale Serve URL, is undocumented and untested.

[T3 Connect](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/internals/t3-connect.md)
works like this:
- Clerk holds the cloud identity, and the relay mints one-time bootstrap credentials, bound to
  the client's DPoP key, which the client exchanges directly with the environment for a session.
- Clients then talk to the environment through its tunnel hostname. So the whole T3 server,
  not only the webhook path, is reachable from the internet behind that authentication.
- The relay forwards `/v1/hooks/:endpointKey/:hookId/:token` to the environment and leaves
  token and signature checks to it.
- The design doc states the trust assumption itself: the relay holds the signing authority
  for mint requests, and DPoP does not make a compromised relay signing key harmless.
- Optional offline holding stores raw requests, including the hook token, in the relay for up
  to 24 hours.
- An account [links up to three machines](https://github.com/pingdotgg/t3code/blob/v0.1.9/docs/user/remote-access.md#more-machines-with-t3-chat);
  phones and browsers do not count, and a paid T3 Chat plan raises the limit.

Robbie's [ADR 001](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/agent-coordinator/adrs/001-t3-code-orchestration-control-plane.mdx)
uses T3 Connect as his coordinator's ingress and rejects a separately managed tunnel. His
[ADR 002](https://github.com/Robbie-Palmer/hq/blob/main/ui/content/projects/agent-coordinator/adrs/002-event-driven-incident-ledger.mdx)
rejects having the Work Graph forward webhooks, as an extra boundary that adds nothing to
admission.

What an agent on the host can do is already bounded by ADR 25:
- it runs as an unprivileged user without sudo;
- there is no 1Password on the host, so no root credentials;
- its GitHub token is limited to two repositories and expires;
- `main` is protected and squash-only behind checks (ADR 8);
- its Doppler token is read-only and scoped to the Work Graph agents' config.

## Decision

- **Ingress.** Enable T3 Connect for the agent host's environment and give the coordinator's
  webhook task its T3 Connect URL. Tailscale Serve stays for the owner's devices. This amends
  the Access bullet of ADR 25 only; the rest of ADR 25 stands.
- **Trust assumption, stated.** We trust T3 Connect's relay, its Clerk tenant and its
  operators not to be compromised: a compromised relay signing key could mint access to the
  host's T3 server. Anyone who holds the owner's T3 Connect account can do the same. Either
  would get what an agent on the host has, which ADR 25 bounds as listed above: no root, no
  root credentials, two repositories, protected `main`, read-only Work Graph secrets. It would
  not reach Terraform applies, host rebuilds or other repositories.
- **Mitigations.**
  - **Hold webhooks while offline** stays off, so no request body or hook token is stored in
    the relay. Missed deliveries are redelivered from GitHub.
  - The T3 Connect account uses strong second-factor authentication.
  - The webhook task requires GitHub's signature and passes only identity fields to the
    prompt; the controller re-fetches state from GitHub (ADR 26).
- **Exit plan: the intended later option.** The observer becomes the only public ingress
  again, and the T3 server returns to tailnet-only:
  1. the observer, which already verifies GitHub's signature (ADR 19), forwards the events the
     coordinator needs to a Durable Object;
  2. a relay on the host holds an outbound WebSocket to that Durable Object and posts each
     event to the local T3 webhook task;
  3. T3 Connect is turned off.

  The controller thread and webhook task stay unchanged; only the URL the events arrive on
  moves. Take this route when the local webhook path is confirmed to work without Connect, or
  earlier if any revisit trigger below fires.

## Alternatives

- **Tailscale Funnel on the hook path only.** Exposes one path rather than the whole server,
  with no third-party relay. But Funnel publishes on the tailnet's public hostname, and
  whether T3's hook route answers on a non-Connect address is untested. A good fit if that
  path works and a host-held public port is acceptable.
- **A self-managed Cloudflare Tunnel.** Full control of routes and access policies under our
  own Cloudflare account, but one more tunnel, credential and set of Terraform to run, and it
  still needs the untested non-Connect hook path. Robbie rejects it for the same reason.
- **Workers VPC.** Lets a Worker call a private service directly, which would suit the exit
  plan; it still needs a tunnel or connector on the host and a Worker in front, so it is the
  exit plan's heavier form rather than a quicker start.
- **A self-hosted GitHub Actions runner on the host.** Workflows would trigger the host
  directly, with no inbound route. Rejected: this repository is public, and a self-hosted
  runner on a public repository can run code from fork pull requests.
- **A polling timer on the host.** No public ingress at all, but it polls GitHub on a fixed
  cadence, adds latency, and is the polling ADR 26 rejects.
- **The exit plan now.** Keeps one public ingress from the start, but needs a Durable Object,
  a host relay and observer changes before the coordinator has handled a single event.

## Consequences

- The coordinator can be built on T3 Code's documented path, with no new service code.
- The platform has two public ingresses until the exit plan lands: the observer's verified
  Worker route and the host's T3 Connect tunnel. ADR 19's observer is unchanged; it is no
  longer the platform's only public entry point, though it stays the Work Graph's.
- Security of the agent host now also depends on T3 Connect's relay, Clerk and the owner's
  T3 Connect account. A T3 Connect outage stops new coordinator work but not agents already
  running, and the owner can still reach the host over the tailnet.
- With offline holding off, deliveries sent while the host is down fail and must be
  redelivered.
- The host takes one of the account's three machine slots.
- Revisit, and take the exit plan, if T3 Connect changes its trust model, a relay or account
  incident is disclosed, the host's credentials grow beyond ADR 25's bounds, or the
  coordinator gains authority beyond this repository.
