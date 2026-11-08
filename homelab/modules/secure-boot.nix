# Secure Boot with Lanzaboote: signs the kernel and boot stub with keys in /var/lib/sbctl.
# The keys are created once per machine with `sbctl create-keys` and never leave it; see
# docs/runbooks/nixos-hosts.md for enrollment.
{ lib, pkgs, ... }:

{
  # Lanzaboote replaces the systemd-boot module.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    configurationLimit = 10;
  };

  environment.systemPackages = [ pkgs.sbctl ];
}
