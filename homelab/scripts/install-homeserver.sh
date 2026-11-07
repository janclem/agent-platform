# shellcheck shell=bash
# Runs as root on the NixOS installer. DISKO_SCRIPT, SYSTEM_TOPLEVEL and
# EXPECTED_DISK come from the flake, so the disk layout and system match the
# commit this was run from.
expected_serial=S2R6NX0J548174K
expected_model="Samsung SSD 850 EVO 250GB"
expected_size=250059350016

if [[ $(id -u) != 0 ]]; then
  echo "run this as root: sudo nix run ..." >&2
  exit 1
fi
grep -q '^NAME=NixOS$' /etc/os-release
if [[ ! -d /iso ]]; then
  echo "this must run from the NixOS installer USB, not an installed system" >&2
  exit 1
fi

test -b "${EXPECTED_DISK}"
disk=$(readlink -f "${EXPECTED_DISK}")
test "$(lsblk --nodeps --noheadings --output SERIAL "${disk}" | xargs)" = "${expected_serial}"
test "$(lsblk --nodeps --noheadings --output MODEL "${disk}" | xargs)" = "${expected_model}"
test "$(lsblk --bytes --nodeps --noheadings --output SIZE "${disk}" | xargs)" = "${expected_size}"
if lsblk --noheadings --output MOUNTPOINTS "${disk}" | grep -q '[^[:space:]]'; then
  echo "${disk} or one of its partitions is mounted" >&2
  exit 1
fi
echo "Install target: ${expected_model}, serial ${expected_serial}, ${disk}."
echo "Every other disk is left alone. Everything on this one is erased."

printf 'Type WIPE %s to continue: ' "${expected_serial}" >&2
read -r confirmation </dev/tty
if [[ ${confirmation} != "WIPE ${expected_serial}" ]]; then
  echo "confirmation did not match; no disk changes were made" >&2
  exit 1
fi

printf 'Wi-Fi network name: ' >&2
IFS= read -r ssid </dev/tty
printf 'Wi-Fi password (hidden): ' >&2
IFS= read -r -s psk </dev/tty
printf '\nRepeat the Wi-Fi password: ' >&2
IFS= read -r -s psk_confirmation </dev/tty
printf '\n' >&2
if [[ -z ${ssid} || -z ${psk} || ${psk} != "${psk_confirmation}" ]]; then
  echo "network name was empty or the passwords did not match; no disk changes were made" >&2
  exit 1
fi
unset psk_confirmation

"${DISKO_SCRIPT}"

umask 077
connections=/mnt/etc/NetworkManager/system-connections
install -d -m 700 "${connections}"
cat >"${connections}/home-wifi.nmconnection" <<PROFILE
[connection]
id=home-wifi
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
chmod 600 "${connections}/home-wifi.nmconnection"

nixos-install --system "${SYSTEM_TOPLEVEL}" --no-root-passwd --no-channel-copy

echo "NixOS is installed. Remove the USB stick, then run: reboot"
