#!/usr/bin/env bash
# Formats-check and evaluates every host without building it. Needs Nix.
set -euo pipefail

homelab_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "${homelab_dir}"
export NIX_CONFIG="experimental-features = nix-command flakes"

nix fmt -- --ci
nix flake check --no-build
