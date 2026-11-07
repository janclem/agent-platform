# Home server

`homeserver` is the home PC (MSI MS-7C95, Ryzen 7 5800XT, 32 GB) running NixOS from
the Samsung 850 EVO. Windows stays on its own NVMe and is picked from the firmware
boot menu (F11). Its config is `homelab/hosts/homeserver/`, built from
`homelab/flake.nix`.

## Disks

| Disk | by-id | Use |
| --- | --- | --- |
| Samsung 850 EVO 250GB | `ata-Samsung_SSD_850_EVO_250GB_S2R6NX0J548174K` | NixOS (ESP + ext4 root) |
| Samsung 980 1TB | `nvme-Samsung_SSD_980_1TB_S649NF0R558960D` | Windows and its ESP |
| Samsung 980 1TB | `nvme-Samsung_SSD_980_1TB_S649NF0R589610W` | Games |
| Crucial MX500 500GB | `ata-CT500MX500SSD1_2026E2AFB5F4` | Games |

Only the 850 EVO appears in the disko config. Never point it at a `/dev/sdX` name.

## Install (wipes the 850 EVO)

1. Boot the NixOS 26.05 minimal ISO from the F11 menu (`UEFI:` entry).
2. Join Wi-Fi through NetworkManager, which the minimal ISO runs (plain
   `wpa_supplicant` fights it): `sudo nmcli device wifi connect "<network>" --ask`.
3. Let the Mac in: `mkdir -p ~/.ssh && curl -fsSL https://github.com/janclem.keys > ~/.ssh/authorized_keys`.
4. From the Mac, with the commit to install merged on `main`:

   ```bash
   ssh -t nixos@<installer-ip> \
     sudo nix --extra-experimental-features 'nix-command flakes' \
     run 'github:janclem/agent-platform?dir=homelab#install-homeserver'
   ```

   The script checks the disk's serial, model, and size, asks you to type
   `WIPE S2R6NX0J548174K`, asks for the Wi-Fi name and password, then partitions,
   writes the Wi-Fi profile to `/etc/NetworkManager/system-connections`, and runs
   `nixos-install`. The password never enters Git or the Nix store.
5. Remove the USB stick and reboot. NixOS is first in the boot order.

## After install

- SSH: `ssh jared@<lan-ip>` with the Mac's key. Root login takes keys only.
- Tailscale: `sudo tailscale up` and open the printed URL to add the machine. Then
  use its tailnet name.
- Check the build: `nixos-version --configuration-revision` prints the commit.

## Rebuild

On the server, from a merged commit on `main`:

```bash
sudo nixos-rebuild switch --flake 'github:janclem/agent-platform?dir=homelab#homeserver'
```

Roll back with `sudo nixos-rebuild switch --rollback`, or choose an older generation
in the boot menu if SSH is gone.
