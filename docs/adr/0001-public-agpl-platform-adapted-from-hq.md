---
title: Build the platform as a public AGPL repository adapted from hq
status: Accepted
date: 2026-11-07
---

# 1. Build the platform as a public AGPL repository adapted from hq

One public repository, `janclem/agent-platform`, holds the shared infrastructure, agent
rules, CI, template, and services for semi-autonomous development, adapted from Robbie
Palmer's `hq` under the AGPL-3.0.

## Context

Agents need the same rules, checks, and delivery policy in every project. Keeping those in
each project lets them drift. Robbie Palmer's
[`hq`](https://github.com/Robbie-Palmer/hq) already solves much of this for one person and
publishes its code, decisions, and runbooks under the AGPL-3.0, so adapting it is much
cheaper than designing from scratch.

## Decision

Keep the platform in one repository that project repositories consume, rather than
copying platform code into each project. Make it public and license it under the
AGPL-3.0, the license that lets this repository reuse `hq` code. Files adapted from `hq`
keep a notice naming their source.

Keep work for employers out of this repository; it holds personal projects only.

## Consequences

- `hq`'s designs and code can be reused directly, and its ADRs explain choices this
  repository inherits.
- Everything committed here is public. Secrets, machine-specific details beyond what a
  host needs, and private notes must stay out (see the secrets decision).
- The AGPL applies to anything built from adapted code, including network services.
- `hq` is built for a larger, multi-project setup. Each adoption should be scaled to this
  platform's size and recorded as its own decision.
