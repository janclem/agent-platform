---
title: Declare self-hosted machines as a NixOS flake installed with disko
status: Accepted
date: 2026-11-07
---

# 10. Declare self-hosted machines as a NixOS flake installed with disko

Self-hosted machines run NixOS, declared in the `homelab/` flake and installed by a
generated per-host installer.

## Context

Home hardware should be rebuildable from the repository, like the cloud settings, so a
reinstall or new machine is a command rather than a set of notes. Robbie's `hq` uses a
NixOS flake in `homelab/` for the same reason.

## Decision

- **Layout:** `homelab/flake.nix` pins nixpkgs and declares each host in
  `homelab/hosts/<host>/`, with shared modules in `homelab/modules/`. Per-host facts stay
  in that host's directory; docs and tooling stay hardware-agnostic.
- **Disks:** [disko](https://github.com/nix-community/disko) declares each host's
  partitions, by `/dev/disk/by-id/` path containing the disk serial.
- **Installer:** every host gets an `install-<host>` package. It refuses unsafe targets,
  requires typing `WIPE <serials>`, writes any Wi-Fi password outside Git and the Nix
  store, and runs disko and `nixos-install`.
- **Changes:** hosts rebuild from merged `main` with `nixos-rebuild switch --flake`, and
  roll back by generation. `nixos-version --configuration-revision` reports the running
  commit.
- **CI:** a `homelab` job format-checks and evaluates every host. Renovate updates
  `flake.lock`.

## Consequences

- Machines are reproducible and changes are reviewed like code.
- Erasing the wrong disk needs several deliberate mismatches to get past the installer.
- Hosts have no channels, so every rebuild and rollback must name the flake.
- CI evaluates hosts but does not build or boot them; boot problems surface only on the
  machine.
