#!/usr/bin/env bash
# Records deployments for the earlier main commits that a successful deployment
# of HEAD also delivered; see record-covered-deployments.ts. Needs `gh`
# credentials with deployments: write (GH_TOKEN in Actions).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
pnpm exec tsx scripts/record-covered-deployments.ts "$@"
