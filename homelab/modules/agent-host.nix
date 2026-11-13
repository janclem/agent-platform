# A host that runs coding agents (ADR 25): a dedicated user with no sudo, whose
# systemd user services (T3 Code) start at boot, plus the tools agents need.
# Agents run as that user, so they cannot change or rebuild the host; the
# operator does. No credential enters the Nix store: each is set up on the host
# after a switch (docs/runbooks/agent-host.md).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.platform.agentHost;
in
{
  options.platform.agentHost = {
    enable = lib.mkEnableOption "running coding agents on this host";

    user = lib.mkOption {
      type = lib.types.str;
      default = "agent";
      description = "Unprivileged user that runs T3 Code and every agent it starts.";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH keys that may log in as the agent user, for provider sign-in and service setup.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.user} = { };
    users.users.${cfg.user} = {
      isNormalUser = true;
      group = cfg.user;
      # Not in wheel: no sudo, so no nixos-rebuild or system changes.
      extraGroups = [ ];
      # User services, including T3 Code, start at boot and survive logout.
      linger = true;
      # Subordinate IDs for rootless Docker.
      autoSubUidGidRange = true;
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

    services.openssh.settings.AllowUsers = [ cfg.user ];

    # Prebuilt Linux binaries, such as T3 Code's runtime and Claude Code, need a
    # standard dynamic loader.
    programs.nix-ld.enable = true;

    # Rootless, so access to the Docker socket does not grant root. The Work Graph
    # database tests start Postgres containers.
    virtualisation.docker.rootless = {
      enable = true;
      setSocketVariable = true;
    };

    # Lets the agent user publish T3 Code to the tailnet with `tailscale serve`.
    services.tailscale.extraSetFlags = [ "--operator=${cfg.user}" ];

    # Watchers for editors, test runners and dev servers across many worktrees.
    boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;

    # mise itself is installed per user at the version CI pins
    # (.github/actions/setup-mise/mise-version.txt); nixpkgs' release lags it.
    # Every other repository tool comes from that repository's mise.toml.
    environment.systemPackages = with pkgs; [
      gh
      git
      jq
      tmux
      unzip
    ];
  };
}
