# work-graph-domain

Pure domain rules for the Work Graph, with no database or network access:

- work items, lifecycle, and readiness;
- the combined containment and dependency graph, with cycle checks;
- decomposition;
- leases and their fencing epochs;
- attention requests and notes;
- contextual priority ranking;
- work-item context;
- critical-path projection;
- delivery evidence and completion candidacy;
- GitHub delivery normalization.

The decisions behind these rules are [ADRs 14–20](../../docs/adr/index.md).

```bash
pnpm --filter work-graph-domain test
```

Adapted from Robbie Palmer's [`hq`](https://github.com/Robbie-Palmer/hq)
`packages/work-graph-domain` at commit `6c08a3b`, under the AGPL-3.0. The analytics module
is left out until analytics are adopted (ADR 20).
