# Agent host

Set up a NixOS host that runs coding agents through T3 Code (ADR 25). The host imports
`homelab/modules/agent-host.nix` with `platform.agentHost.enable = true`. Below, `<host>` is
its tailnet name and `agent` is `platform.agentHost.user`.

No step puts a credential in Git, the Nix store or a chat. Paste each one only into the
prompt or file named.

## 1. Switch the host

After the owner approves the change, follow [Rebuild and roll back](nixos-hosts.md#rebuild-and-roll-back).
Then check from your workstation:

```bash
ssh agent@<host> 'id; systemctl --user is-active docker; docker info --format "{{.SecurityOptions}}"'
```

`id` lists no `wheel`, Docker is `active`, and the security options include `rootless`.

## 2. Install tools for the agent user

As `agent` on the host, install mise at the version CI pins:

```bash
version=$(curl -fsSL https://raw.githubusercontent.com/janclem/agent-platform/main/.github/actions/setup-mise/mise-version.txt)
curl -fsSL https://mise.run | MISE_VERSION="v${version}" sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
```

## 3. Install T3 Code

Use the exact version your T3 Code client shows in **Settings → About**, because a client
refuses a newer or older server:

```bash
curl -fsSL https://t3.codes/install.sh | T3CODE_VERSION=<version> sh
cat > ~/.t3/service.env <<'EOF'
T3CODE_HOST=127.0.0.1
DOCKER_HOST=unix:///run/user/<agent uid>/docker.sock
EOF
chmod 600 ~/.t3/service.env
~/.local/bin/t3 service install
~/.local/bin/t3 service status
```

`t3 service status` reports the service running, enabled and lingering.

## 4. Sign in

As `agent` on the host:

- **GitHub:** create a fine-grained token on the owner's account, limited to the owner's
  repositories, with read and write access to Contents, Pull requests and Workflows, read access
  to Metadata, and an expiry. Then run `gh auth login --with-token` and paste it at the prompt,
  and `gh auth setup-git`. Set `git config --global user.name` and `user.email` to the owner's.
- **Work Graph:** create a read-only Doppler service token for `work-graph/prd_work_graph_agents`,
  add `DOPPLER_TOKEN=<token>` to `~/.t3/service.env`, and run `t3 service restart`.
- **Claude Code:** `claude auth login` (install it first from **Settings → Providers** in T3 Code,
  or with its installer).
- **Codex:** connect it in **Settings → Providers** with the host's environment selected.

## 5. Pair a client

```bash
~/.local/bin/t3 pair --tailscale
```

Open the printed link on the client, or paste it into **Add environment**. Treat it as a
password. The client reaches the host at `https://<host>.<tailnet>.ts.net/`, from the tailnet
only.

## Update T3 Code

Update the client, then use **Update server** when the client reports the host's version is
older. A host that cannot update remotely: `t3 update <version> --yes` as `agent`.

## Rotate or revoke

- Paired clients: `t3 auth session list` and `t3 auth session revoke <id>`.
- GitHub and Doppler tokens: replace them as in step 4, then revoke the old ones where they
  were created.
- To stop the agent host: `t3 service uninstall` as `agent`, then set
  `platform.agentHost.enable = false` and rebuild.
