# NixOS hosts

Self-hosted servers run NixOS built from `homelab/flake.nix`. Each host has a directory
under `homelab/hosts/<host>/` and an entry in `nixosConfigurations`, which also gives it
an installer package, `install-<host>`.

## Add a host

1. Boot the target machine from the NixOS minimal ISO (UEFI) and get a shell on it
   (see Install, steps 2–3).
2. Copy an existing host directory to `homelab/hosts/<host>/` and set
   `networking.hostName`.
3. Point `disk-config.nix` at the install disk by its `/dev/disk/by-id/` path, from
   `ls -l /dev/disk/by-id/` on the installer. Use a path that contains the disk's serial
   number; the installer refuses kernel names like `/dev/sda`.
4. Replace `hardware-configuration.nix` with the output of
   `sudo nixos-generate-config --no-filesystems --show-hardware-config`.
5. Add the host to `nixosConfigurations` in `homelab/flake.nix`, then open a PR.
   CI format-checks and evaluates every host.

## Install (erases the disks in the host's disko config)

1. Boot the NixOS minimal ISO in UEFI mode. Disable Secure Boot until the host has a
   signed bootloader.
2. Get online. Wired networking works on its own. For Wi-Fi use NetworkManager, which
   the ISO runs: `sudo nmcli device wifi connect "<network>" --ask`.
3. Let your workstation in:
   `mkdir -p ~/.ssh && curl -fsSL https://github.com/<github-user>.keys > ~/.ssh/authorized_keys`.
4. From the workstation, with the host merged on `main`:

   ```bash
   ssh -t nixos@<installer-ip> \
     sudo nix --extra-experimental-features "'nix-command flakes'" \
     run "'github:janclem/agent-platform/<commit>?dir=homelab#install-<host>'"
   ```

   The installer lists each target disk, checks that its serial is in its by-id path
   and that nothing on it is mounted, and asks you to type `WIPE <serial>`. It then
   asks for an optional Wi-Fi network and password and runs disko and `nixos-install`.
   The Wi-Fi password goes only to `/etc/NetworkManager/system-connections` on the new
   system, never into Git or the Nix store.
5. Remove the USB stick and reboot. NixOS is first in the firmware boot order.

## After install

- SSH in with an operator key. Password and keyboard-interactive login are off, and
  root takes keys only.
- Join the tailnet: `sudo tailscale up`, then open the printed URL.
- `nixos-version --configuration-revision` prints the commit the system was built from.

## Rebuild and roll back

On the host, from a merged commit on `main`:

```bash
sudo nixos-rebuild switch --flake 'github:janclem/agent-platform?dir=homelab#<host>'
```

Roll back with `sudo nixos-rebuild switch --rollback`, or pick an older generation in
the boot menu if SSH is unavailable.
