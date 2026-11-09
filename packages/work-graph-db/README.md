# work-graph-db

PostgreSQL persistence and coordination for the Work Graph. It has:

- the Drizzle schema and committed migrations;
- the repository: claims with `FOR UPDATE SKIP LOCKED`, fenced leases, and serialized
  graph edits with combined cycle checks;
- GitHub delivery correlation and the queue consumer;
- the immutable event log.

The decisions behind it are [ADRs 14–20](../../docs/adr/index.md).

```bash
pnpm db:check            # migrations are named well and match the schema
pnpm test:integration    # disposable PostgreSQL 17 in Docker; migrates, then runs the suite
pnpm db:generate add_<subject>   # new migration after a schema change
```

`test:integration` truncates tables. To point it at an existing database instead of Docker,
set both `TEST_DATABASE_URL` and `ALLOW_INTEGRATION_DATABASE=1`.

Automatic release exists in the schema, but no completion policy enables it
(`automatic_release` defaults to `false`). Turning it on is a separate decision (ADR 19).

Adapted from Robbie Palmer's [`hq`](https://github.com/Robbie-Palmer/hq)
`packages/work-graph-db` at commit `6c08a3b`, under the AGPL-3.0. Migrations are kept
exactly as hq wrote them.
