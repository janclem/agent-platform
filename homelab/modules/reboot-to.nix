# `reboot-to <name>` restarts once into another firmware boot entry, such as another
# operating system, without needing a screen or the firmware boot menu. The next
# restart after that returns to the normal boot order.
{ pkgs, ... }:

let
  rebootTo = pkgs.writeShellApplication {
    name = "reboot-to";
    runtimeInputs = with pkgs; [
      efibootmgr
      gnugrep
      systemd
    ];
    text = ''
      if [[ $# -ne 1 ]]; then
        echo "usage: reboot-to <part of a boot entry name>" >&2
        efibootmgr | grep -E '^Boot[0-9A-F]{4}' >&2
        exit 2
      fi
      if [[ $(id -u) != 0 ]]; then
        exec sudo "$0" "$@"
      fi

      matches=$(efibootmgr | grep -E '^Boot[0-9A-F]{4}' | grep -iF -- "$1" || true)
      if [[ -z $matches || $(grep -c . <<<"$matches") -ne 1 ]]; then
        echo "need exactly one boot entry matching '$1'; found:" >&2
        efibootmgr | grep -E '^Boot[0-9A-F]{4}' >&2
        exit 1
      fi

      entry=''${matches:4:4}
      efibootmgr --bootnext "$entry" >/dev/null
      echo "Restarting once into: ''${matches#Boot????}"
      systemctl reboot
    '';
  };
in
{
  environment.systemPackages = [ rebootTo ];
}
