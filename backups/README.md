<!-- Adapted from Robbie-Palmer/hq (backups/README.md, backups/work-graph.md), AGPL-3.0. -->

# Work Graph backups

ADR 21. Three layers protect the Work Graph database:

1. Neon's restore history (6 hours on the Free plan) undoes recent mistakes.
2. A manual Neon snapshot before a risky migration gives a known-good checkpoint.
3. [`work-graph-backup.yml`](../.github/workflows/work-graph-backup.yml) keeps
   age-encrypted archives in the private R2 bucket `work-graph-database-backups`,
   independent of Neon.

## Nightly backup

At 03:17 UTC, `mise run work-graph:backup` runs
[`backup-work-graph.sh`](scripts/backup-work-graph.sh):

1. Records production's tables, migration count and event count.
2. Runs one `pg_dump --format=custom` against Neon's direct endpoint as the read-only
   `work_graph_backup` login, and streams it to two places: `age`, which encrypts it
   to the public recipient, and `pg_restore`, which loads it into a throwaway
   PostgreSQL 17 container.
3. Checks the restored copy: every production table and migration is present and the
   append-only event log has not shrunk. The row counts are printed as evidence.
4. Uploads the ciphertext and its SHA-256 sidecar to `daily/YYYY/MM/`, checks both
   object sizes, and copies the first pair of each ISO week and month to
   `weekly/YYYY/Www/` and `monthly/YYYY/MM/`.

Plaintext never touches disk, and only ciphertext leaves the runner. A failed run
opens (or comments on) a "Work Graph backup failed" issue.

## Retention and locks

[`r2-lifecycle.json`](r2-lifecycle.json) and [`r2-lock.json`](r2-lock.json) hold the
bucket rules, since the Cloudflare Terraform provider v4 cannot manage them. Apply them
with `mise run work-graph:backup-policies`, which uses the infrastructure token from
1Password and replaces the rules wholesale:

| Prefix | Kept for |
| --- | --- |
| `daily/` | 14 days |
| `weekly/` | 60 days |
| `monthly/` | 400 days |

Every object is locked against deletion or overwrite for its first 8 days, so a
leaked R2 token cannot erase the last week of backups. Terraform's `prevent_destroy`
guards the bucket itself.

## Credentials

| Where | What |
| --- | --- |
| Doppler `work-graph/prd_work_graph_backup` | `NEON_DATABASE_URL_UNPOOLED` (read-only `work_graph_backup` login, `sslmode=require&channel_binding=require`), `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY` (Object Read & Write on this bucket only), `AGE_RECIPIENT` (public), `CLOUDFLARE_ACCOUNT_ID`, `R2_DATABASE_BACKUPS_BUCKET_NAME`, `DATABASE_BACKUP_LABEL` |
| GitHub environment `production-work-graph-backup` | `DOPPLER_TOKEN`, a read-only service token for that config; deployable from `main` only |
| 1Password `agent-platform/work-graph-backup-age-key` | The private age identity. Nowhere else: losing it makes every archive unreadable, and keeping it out of GitHub, Doppler and Cloudflare means a leaked bucket exposes nothing. |

`work_graph_backup` was created with:

```sql
CREATE ROLE work_graph_backup LOGIN PASSWORD '<generated>';
GRANT CONNECT ON DATABASE work_graph TO work_graph_backup;
GRANT pg_read_all_data TO work_graph_backup;
ALTER ROLE work_graph_backup SET default_transaction_read_only = on;
```

`pg_read_all_data` does not bypass row-level security. If RLS is introduced, confirm
the dump is still complete.

## Restore drill

The nightly check proves the dump restores but not that the archive decrypts, because
the private key never reaches CI. Run a full drill monthly, and before relying on a
backup:

```bash
mise run work-graph:restore-drill                          # newest daily archive
mise run work-graph:restore-drill -- monthly/2026/11/<name>.dump.age
```

It downloads the archive and checksum, verifies the checksum, decrypts with the key
from 1Password (or `AGE_IDENTITY_FILE`) straight into `pg_restore` on a throwaway
PostgreSQL, and runs the same checks. Record its output on the drill's Work Graph
ticket.

## Restoring production

Never restore over production directly. Restore into a new Neon branch, check it as
above, then point the Worker's Hyperdrive origin at it (or promote the branch) once
it is verified. To produce a plaintext dump for that:

```bash
op document get work-graph-backup-age-key --vault agent-platform --out-file key.txt
age --decrypt --identity key.txt work-graph-<timestamp>.dump.age \
  | pg_restore --exit-on-error --no-owner --no-privileges --dbname "$TARGET_URL"
rm key.txt
```
