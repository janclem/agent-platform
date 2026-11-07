#!/usr/bin/env bash
# Validate the Claude Code marketplace (repo root) and the platform plugin.
set -euo pipefail

claude plugin validate --strict .
claude plugin validate --strict plugin
