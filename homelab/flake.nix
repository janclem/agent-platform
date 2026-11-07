# Adapted from Robbie-Palmer/hq (homelab/flake.nix), AGPL-3.0.
{
  description = "Home lab machines declared as code";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      disko,
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

      nixosConfigurations.homeserver = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/homeserver
          self.nixosModules.configuration-revision
        ];
      };

      packages.x86_64-linux.install-homeserver =
        let
          pkgs = pkgsFor "x86_64-linux";
          host = self.nixosConfigurations.homeserver.config;
        in
        pkgs.writeShellApplication {
          name = "install-homeserver";
          runtimeInputs = with pkgs; [
            coreutils
            gnugrep
            nixos-install-tools
            util-linux
          ];
          runtimeEnv = {
            DISKO_SCRIPT = host.system.build.diskoScript;
            SYSTEM_TOPLEVEL = host.system.build.toplevel;
            EXPECTED_DISK = host.disko.devices.disk.root.device;
          };
          text = builtins.readFile ./scripts/install-homeserver.sh;
        };
    };
}
