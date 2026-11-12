---
title: Back up the Work Graph database nightly to R2 with restore drills
status: Accepted
date: 2026-11-09
---

# 21. Back up the Work Graph database nightly to R2 with restore drills

A scheduled job writes an encrypted dump of the Work Graph database to a dedicated R2 bucket
every night, keeps weekly and monthly copies, and proves restores work.

## Context

The Work Graph holds the plan and its evidence, so losing it loses the platform's memory.
Neon's Free plan restore history is
[6 hours](https://neon.com/docs/introduction/history-window), which covers a bad migration
caught quickly but not a mistake found the next day, or a lost account. Robbie backs up his
database to R2 with age encryption and restore drills.

## Decision

- **Schedule:** a GitHub Actions workflow runs `pg_dump` nightly against Neon directly, not
  through Hyperdrive.
- **Encryption:** encrypt with age to a recipient whose private key lives only in 1Password
  (ADR 4).
- **Storage:** upload the archive and its checksum to a dedicated private R2 bucket, managed
  by Terraform. Write under `daily/`, `weekly/`, and `monthly/` prefixes, each with its own
  lifecycle expiry.
- **Restore drills:** a scheduled job restores the latest archive into a scratch database and
  checks row counts and migrations. A failed backup or drill fails visibly.
- **Credentials:** the workflow gets a read-only database role and an R2 token scoped to the backup bucket.

## Consequences

- Recovery no longer depends on Neon's history window or the account itself.
- Restores need the age key from 1Password, so a leaked bucket alone exposes nothing.
- One more scheduled workflow, bucket, and two scoped credentials to maintain. R2 storage
  beyond its [free allowance](https://developers.cloudflare.com/r2/pricing/) costs money.

## Implementation notes (2026-11-12)

- **Nightly, not weekly.** Robbie backs up weekly to stay inside Neon Free's 5 GB monthly
  transfer. The Work Graph dump is about 120 KB, so nightly costs nothing.
- **Retention:** `daily/` 14 days, `weekly/` 60 days, `monthly/` 400 days, and every object
  locked for 8 days.
- **Restore drills in two parts.** The private key stays out of CI, so the nightly job cannot
  decrypt. Instead it streams the one `pg_dump` into both `age` and a scratch `pg_restore`,
  and checks the restored copy on every run. A monthly manual drill
  (`mise run work-graph:restore-drill`) decrypts a stored archive with the key from 1Password
  and runs the same checks.
- **Separate credentials.** The backup has its own Doppler config
  (`prd_work_graph_backup`) and GitHub environment, so it never sees the deploy token or the
  owner database URL. See `backups/README.md`.

