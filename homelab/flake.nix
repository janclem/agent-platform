# Adapted from Robbie-Palmer/hq (homelab/flake.nix), AGPL-3.0.
{
  description = "Home lab machines declared as code";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      disko,
      lanzaboote,
      nixpkgs,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs { inherit system; };
      configurationRevision =
        self.rev or self.dirtyRev or "source-${builtins.baseNameOf (toString self.outPath)}";
    in
    {
      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);

      nixosModules.configuration-revision = {
        system.configurationRevision = configurationRevision;
      };

      nixosModules.secure-boot = {
        imports = [
          lanzaboote.nixosModules.lanzaboote
          ./modules/secure-boot.nix
        ];
      };

      nixosConfigurations.homeserver = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/homeserver
          self.nixosModules.configuration-revision
          self.nixosModules.secure-boot
        ];
      };

      # One guarded installer per host: `nix run .#install-<host>` on the NixOS installer.
      packages.x86_64-linux = nixpkgs.lib.mapAttrs' (
        name: host:
        nixpkgs.lib.nameValuePair "install-${name}" (
          (pkgsFor "x86_64-linux").writeShellApplication {
            name = "install-${name}";
            runtimeInputs = with (pkgsFor "x86_64-linux"); [
              coreutils
              gnugrep
              nixos-install-tools
              sbctl
              util-linux
            ];
            runtimeEnv = {
              HOST_NAME = name;
              SECURE_BOOT = if host.config.boot.lanzaboote.enable or false then "1" else "";
              DISKO_SCRIPT = host.config.system.build.diskoScript;
              SYSTEM_TOPLEVEL = host.config.system.build.toplevel;
              TARGET_DISKS = builtins.concatStringsSep " " (
                map (disk: disk.device) (builtins.attrValues host.config.disko.devices.disk)
              );
            };
            text = builtins.readFile ./scripts/install-host.sh;
          }
        )
      ) self.nixosConfigurations;
    };
}
