---
title: Use Secure Boot on NixOS hosts with Lanzaboote and machine-owned keys
status: Accepted
date: 2026-11-07
---

# 12. Use Secure Boot on NixOS hosts with Lanzaboote and machine-owned keys

Hosts that need Secure Boot import `nixosModules.secure-boot`, which boots through
Lanzaboote with keys created on the machine and enrolled alongside Microsoft's.

## Context

Some machines must keep UEFI Secure Boot enabled, for example to run other software that
requires it. Stock NixOS boot entries are unsigned, so they fail under Secure Boot.
This extends the NixOS hosts flake (ADR 10).

## Decision

- **Signing:** [Lanzaboote](https://github.com/nix-community/lanzaboote) replaces
  systemd-boot and signs each generation with keys in `/var/lib/sbctl`.
- **Keys:** the installer creates the keys before `nixos-install`, so new hosts install
  already signed. Keys never leave the machine.
- **Enrollment:** enroll with `sbctl enroll-keys --microsoft --firmware-builtin`. This
  keeps Microsoft's and the vendor's keys, so other operating systems and Microsoft-signed
  option ROMs keep booting.
- **Firmware steps:** the runbook covers the manual firmware steps and checking
  `sbctl status` for firmware quirks.

## Consequences

- Hosts boot with Secure Boot on, and rebuilds stay signed automatically.
- Enabling it involves manual firmware steps that differ by vendor.
- Some firmware runs unsigned images unless its policy is set to deny them, so Secure Boot
  can report as on without enforcing anything. Each host's actual enforcement depends on
  its firmware settings.
- Losing `/var/lib/sbctl`, for example in a reinstall, means creating and enrolling new
  keys.
