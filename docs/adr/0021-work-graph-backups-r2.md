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
