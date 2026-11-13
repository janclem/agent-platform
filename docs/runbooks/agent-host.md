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

## 2. Install the pinned tools

As `agent` on the host, install mise at the version CI pins, make its shims visible to login
shells (T3 Code finds provider CLIs there), and install the agent-host tools pinned in
`homelab/agent-host/mise.toml`:

```bash
raw=https://raw.githubusercontent.com/janclem/agent-platform/main
curl -fsSL https://mise.run | MISE_VERSION="v$(curl -fsSL "$raw/.github/actions/setup-mise/mise-version.txt")" sh
echo 'export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"' >> ~/.profile
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
mkdir -p ~/.config/mise
curl -fsSL "$raw/homelab/agent-host/mise.toml" -o ~/.config/mise/config.toml
~/.local/bin/mise install
```

Check from your workstation that a non-interactive login shell sees them:

```bash
ssh agent@<host> 'sh -lc "t3 --version; claude --version; codex --version"'
```

Clone the repository, install its pinned tools and the `work-graph` CLI:

```bash
git clone https://github.com/janclem/agent-platform.git ~/code/agent-platform
cd ~/code/agent-platform && mise trust && mise install && mise run work-graph-cli:install
```

## 3. Start T3 Code

Your T3 Code client must run the same version as the `t3` pin, or it refuses the server. As
`agent`:

```bash
mkdir -p ~/.t3
cat > ~/.t3/service.env <<EOF
T3CODE_HOST=127.0.0.1
DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock
WORK_GRAPH_DOPPLER_BIN=$HOME/.local/share/mise/shims/doppler
EOF
chmod 600 ~/.t3/service.env
t3 service install
t3 service status
```

`systemctl --user is-active t3code` reports `active`. The service's boot log prints a one-time
pairing QR code; treat the log as a secret.

## 4. Sign in

As `agent` on the host:

- **GitHub:** create a fine-grained token on the owner's account with an expiry, limited to the
  repositories agents work in (`janclem/agent-platform`, `janclem/platform-smoke-test`), with
  read and write access to Contents, Pull requests and Workflows, and read access to Actions,
  Commit statuses and Metadata. (Fine-grained tokens have no Checks permission; Actions read
  covers this repository's check runs.) Run `gh auth login --with-token` and paste it at the
  prompt, then `gh auth setup-git`, and set `git config --global user.name` and `user.email`
  to the owner's. `git push --dry-run` from a clone checks it.
- **Work Graph:** from a workstation signed in to Doppler, create a read-only service token for
  `work-graph/prd_work_graph_agents` and write it straight into the service environment:

  ```bash
  doppler configs tokens create --name agent-host-<host> --project work-graph \
    --config prd_work_graph_agents --access read --max-age 8760h --plain |
    ssh agent@<host> 'umask 077; read -r t; sed -i "/^DOPPLER_TOKEN=/d" ~/.t3/service.env;
      printf "DOPPLER_TOKEN=%s\n" "$t" >> ~/.t3/service.env'
  ssh agent@<host> 'set -a; . ~/.t3/service.env; set +a; sh -lc "work-graph ready"; systemctl --user restart t3code'
  ```
- **Claude Code:** `claude auth login`.
- **Codex:** `codex login`, or connect it in **Settings → Providers** with the host's
  environment selected.

## 5. Pair a client

```bash
~/.local/bin/t3 pair --tailscale
```

Open the printed link on the client, or paste it into **Add environment**. Treat it as a
password. The client reaches the host at `https://<host>.<tailnet>.ts.net/`, from the tailnet
only.

## Update the pinned tools

Renovate proposes bumps to `homelab/agent-host/mise.toml`; review and merge them by hand. Then,
as `agent`, with no T3 work running:

```bash
curl -fsSL https://raw.githubusercontent.com/janclem/agent-platform/main/homelab/agent-host/mise.toml \
  -o ~/.config/mise/config.toml
mise install
t3 service install
t3 service restart
```

For a `t3` bump, update your T3 Code client to the same version in the same sitting. Do not use
the client's **Update server** button; it would move the host off the pin.

## Rotate or revoke

- Paired clients: `t3 auth session list` and `t3 auth session revoke <id>`.
- GitHub and Doppler tokens: replace them as in step 4, then revoke the old ones where they
  were created.
- To stop the agent host: `t3 service uninstall` as `agent`, then set
  `platform.agentHost.enable = false` and rebuild.
