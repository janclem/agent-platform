# shellcheck shell=bash
# Runs as root on the NixOS installer. HOST_NAME, DISKO_SCRIPT, SYSTEM_TOPLEVEL and
# TARGET_DISKS come from the flake, so the disk layout and system match the commit
# this was run from.

if [[ $(id -u) != 0 ]]; then
  echo "run this as root: sudo nix run ..." >&2
  exit 1
fi
grep -q '^NAME=NixOS$' /etc/os-release
if [[ ! -d /iso ]]; then
  echo "this must run from the NixOS installer USB, not an installed system" >&2
  exit 1
fi

serials=()
for device in ${TARGET_DISKS}; do
  if [[ ${device} != /dev/disk/by-id/* ]]; then
    echo "${device}: disko devices must be /dev/disk/by-id paths" >&2
    exit 1
  fi
  if [[ ! -b ${device} ]]; then
    echo "${device} is not attached to this machine" >&2
    exit 1
  fi
  disk=$(readlink -f "${device}")
  serial=$(lsblk --nodeps --noheadings --output SERIAL "${disk}" | xargs)
  if [[ -z ${serial} || ${device} != *"${serial}"* ]]; then
    echo "${device}: the disk's serial (${serial:-none}) is not part of its by-id path" >&2
    exit 1
  fi
  if lsblk --noheadings --output MOUNTPOINTS "${disk}" | grep -q '[^[:space:]]'; then
    echo "${disk} or one of its partitions is mounted" >&2
    exit 1
  fi
  lsblk --nodeps --output NAME,MODEL,SERIAL,SIZE "${disk}"
  serials+=("${serial}")
done

echo "Installing ${HOST_NAME}. Everything on the disks above is erased; other disks are left alone."
expected="WIPE ${serials[*]}"
printf 'Type %s to continue: ' "${expected}" >&2
read -r confirmation </dev/tty
if [[ ${confirmation} != "${expected}" ]]; then
  echo "confirmation did not match; no disk changes were made" >&2
  exit 1
fi

printf 'Wi-Fi network name (leave empty for wired networking): ' >&2
IFS= read -r ssid </dev/tty
if [[ -n ${ssid} ]]; then
  printf 'Wi-Fi password (hidden): ' >&2
  IFS= read -r -s psk </dev/tty
  printf '\nRepeat the Wi-Fi password: ' >&2
  IFS= read -r -s psk_confirmation </dev/tty
  printf '\n' >&2
  if [[ -z ${psk} || ${psk} != "${psk_confirmation}" ]]; then
    echo "the passwords were empty or did not match; no disk changes were made" >&2
    exit 1
  fi
  unset psk_confirmation
fi

"${DISKO_SCRIPT}"

if [[ -n ${ssid} ]]; then
  umask 077
  connections=/mnt/etc/NetworkManager/system-connections
  install -d -m 700 "${connections}"
  cat >"${connections}/wifi.nmconnection" <<PROFILE
[connection]
id=wifi
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=${ssid}

[wifi-security]
key-mgmt=wpa-psk
psk=${psk}

[ipv4]
method=auto

[ipv6]
method=auto
PROFILE
  unset psk
  chmod 600 "${connections}/wifi.nmconnection"
fi

nixos-install --system "${SYSTEM_TOPLEVEL}" --no-root-passwd --no-channel-copy

echo "${HOST_NAME} is installed. Remove the USB stick, then run: reboot"
