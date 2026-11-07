# agent-platform

Personal platform for semi-autonomous software development: infrastructure, agent
instructions, shared skills, CI workflows, and the services (code review, Work Graph)
that project repos build on.

Coding agents should read [AGENTS.md](AGENTS.md).

## Reusable workflows

Project repos run the platform checks and security scans by calling the reusable workflows:

```yaml
jobs:
  platform: # required status check: `platform / checks`
    permissions:
      contents: read
    uses: janclem/agent-platform/.github/workflows/checks.yml@v1
```

`checks.yml` lints workflows and checks Terraform under `infra/`, the agent skill layout, and the
Renovate config. It then runs the project's own `mise run ci` task if one exists. Each check
skips itself when the repo has nothing for it to check. Tools come from the project's
`mise.toml`, so pin `jactionlint`, `shellcheck`, and (with `infra/`) `terraform` there. Call
`scans.yml` the same way, granting `security-events: write`, for gitleaks and zizmor.

## Shared skills

Agent skills live in `.agents/skills/`, which Codex reads, with pointer files in
`.claude/skills/` for Claude Code. This follows the layout of Robbie's `hq`. Project repos
get copies from this repo's Copier template and pick up changes with `copier update`.

## Credits

The architecture follows Robbie Palmer's
[semi-autonomous software development](https://robbiepalmer.me/initiatives/semi-autonomous-software-development)
initiative and his [`hq`](https://github.com/Robbie-Palmer/hq) monorepo. Files adapted
from `hq` keep their original copyright notices.

## License

[GNU Affero General Public License v3.0](LICENSE).
