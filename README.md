# agent-platform

Personal platform for semi-autonomous software development: infrastructure, agent
instructions, shared skills, CI workflows, and the services (code review, Work Graph)
that project repos build on.

Coding agents should read [AGENTS.md](AGENTS.md).

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
