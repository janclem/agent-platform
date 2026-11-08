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
   system, never into Git or the Nix store. For hosts with the `secure-boot` module it
   also creates the machine's Secure Boot keys in `/var/lib/sbctl`.
5. Remove the USB stick and reboot. NixOS is first in the firmware boot order.

## After install

- SSH in with an operator key. Password and keyboard-interactive login are off, and
  root takes keys only.
- Join the tailnet: `sudo tailscale up`, then open the printed URL.
- `nixos-version --configuration-revision` prints the commit the system was built from.

## Other boot entries

Hosts that import `modules/reboot-to.nix` can restart once into another firmware boot
entry, such as a second operating system, without a screen:
`ssh <host> reboot-to <part of the entry name>`. The restart after that uses the normal
boot order again. To open the firmware settings instead, run
`sudo systemctl reboot --firmware-setup`.

Some graphics cards show the firmware screens on only one output, or none over
DisplayPort, until an OS driver loads. Keep a second cable (such as HDMI) for firmware
visits, and select that input before powering on.

## Secure Boot

Hosts that import `nixosModules.secure-boot` boot through Lanzaboote, which signs the
kernel with the machine's own keys in `/var/lib/sbctl`. The keys are created on the
machine and never leave it. To add the module to a host that is already installed, run
`sudo sbctl create-keys` on it before the first rebuild.

To turn Secure Boot on:

1. Check that the boot files are signed: `sudo sbctl verify`.
2. In the firmware settings, put Secure Boot into Setup Mode. Depending on the vendor
   that is "Reset to Setup Mode" or deleting the Platform Key. Keep the factory keys
   restorable, and never erase the forbidden-signature database (dbx). If the firmware
   has an option that provisions its factory keys automatically, disable it and save
   first; otherwise it can put the keys back on the restart that deleting the Platform
   Key forces.
3. Back on the host, check that `sudo sbctl status` shows `Setup Mode: Enabled`, then
   enroll the keys: `sudo sbctl enroll-keys --microsoft --firmware-builtin`. Microsoft's
   keys keep other operating systems and Microsoft-signed firmware add-ons booting, and
   `--firmware-builtin` keeps the vendor's own keys. If enrollment fails with
   "operation not permitted", the kernel has marked the key variables immutable; run
   `sudo chattr -i /sys/firmware/efi/efivars/{PK,KEK,db}-*` and try again.
4. In the firmware settings, enable Secure Boot. After booting, `bootctl status` shows
   `Secure Boot: enabled (user)`.
5. Run `sudo sbctl status`. If it lists firmware quirks, read the linked page for each.
   Some firmware still runs unsigned images until its Secure Boot policy is set to deny
   them, which makes Secure Boot report as on without enforcing anything.

If the keys in `/var/lib/sbctl` are lost, for example after a reinstall, create new ones
and repeat these steps.

## Rebuild and roll back

On the host, from a merged commit on `main`:

```bash
sudo nixos-rebuild switch --flake 'github:janclem/agent-platform?dir=homelab#<host>'
```

To roll back to the previous generation, pass the same flake reference; hosts have no
channels, so `--rollback` alone fails looking for `nixos-config`:

```bash
sudo nixos-rebuild switch --rollback --flake 'github:janclem/agent-platform?dir=homelab#<host>'
```

If SSH is unavailable, pick an older generation in the boot menu instead.
`nixos-version --configuration-revision` shows which commit is running.
