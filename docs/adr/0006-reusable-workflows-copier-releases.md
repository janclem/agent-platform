---
title: Distribute shared CI and files through reusable workflows, a Copier template, and exact release tags
status: Accepted
date: 2026-11-07
---

# 6. Distribute through reusable workflows, a Copier template, and exact release tags

Project repositories call this repository's reusable workflows, are created and updated
from its Copier template, and consume both at exact `vX.Y.Z` release tags.

## Context

Projects need the same checks and files without copying logic that then drifts. Some
things can be called remotely (CI logic); others must exist as files in the project
(agent rules, skills, Renovate config, `mise.toml`).

## Decision

- **Logic stays here:** `checks.yml` and `scans.yml` are reusable workflows, and their
  composite actions are referenced with `$/` so a caller gets actions from the same ref.
  The `platform` job that calls `checks.yml` produces the `platform / checks` status.
- **Files are copied:** `copier.yml` and `template/` render a project. Template skills are
  symlinks to this repository's, so there is one source.
- **Versions are exact tags:** releases are `vX.Y.Z` tags on `main`, made after changes to
  the workflows, actions, or template. Callers pin the release commit SHA with a version
  comment, as jactionlint requires.
- No moving major tag such as `v1`. Copier records the newest tag as the template version,
  so a moving tag breaks `copier update` and Renovate's version tracking.
- Published tags are never moved or deleted.
- `mise run ci` renders the template and checks the result on every PR.

## Consequences

- Fixing CI logic once fixes every caller at its next pin update.
- Copied files change only through `copier update`, which Renovate proposes and a person
  reviews.
- Changes must stay backward compatible within a major version.
