{ pkgs, ... }:

let
  operatorKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGfFHfgzLyuem/WxTjPeQvI7UXmDeDOmVcqwkPP4835X janc_clem@yahoo.co.uk"
  ];
in
{
  imports = [
    ./disk-config.nix
    ./hardware-configuration.nix
  ];

  networking = {
    hostName = "homeserver";
    # The Wi-Fi profile is written to /etc/NetworkManager/system-connections by
    # the installer, so the passphrase never enters the Nix store.
    networkmanager = {
      enable = true;
      wifi.powersave = false;
    };
    firewall = {
      enable = true;
      checkReversePath = "loose";
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ 41641 ];
    };
  };

  # MT7922 Wi-Fi firmware and AMD microcode.
  hardware.enableRedistributableFirmware = true;

  boot = {
    # The bootloader is Lanzaboote (modules/secure-boot.nix). This lets it put NixOS
    # first in the firmware boot order.
    loader.efi.canTouchEfiVariables = true;
    tmp.cleanOnBoot = true;
  };

  time.timeZone = "America/Chicago";

  users.users = {
    root.openssh.authorizedKeys.keys = operatorKeys;
    jared = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      openssh.authorizedKeys.keys = operatorKeys;
    };
  };

  security.sudo.wheelNeedsPassword = false;

  services = {
    openssh = {
      enable = true;
      settings = {
        AllowUsers = [
          "root"
          "jared"
        ];
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
        X11Forwarding = false;
      };
    };
    tailscale.enable = true;
    journald.extraConfig = ''
      SystemMaxUse=1G
      MaxRetentionSec=14day
    '';
  };

  zramSwap.enable = true;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [ "@wheel" ];
    };
    gc = {
      automatic = true;
      dates = "Sun 04:15";
      options = "--delete-older-than 30d";
    };
  };

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    jq
    tmux
  ];

  system = {
    autoUpgrade.enable = false;
    stateVersion = "26.05";
  };
}
