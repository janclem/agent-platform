# agent-platform

Personal platform for semi-autonomous software development: infrastructure, agent
instructions, shared skills, CI workflows, and the services (code review, Work Graph)
that project repos build on.

Coding agents should read [AGENTS.md](AGENTS.md).

## Shared skills

Project repos get the shared agent skills from the `platform` Claude Code plugin:

```text
/plugin install platform --marketplace janclem/agent-platform
```

Or commit it to the project's `.claude/settings.json` so every session has it:

```json
{
  "extraKnownMarketplaces": {
    "agent-platform": { "source": { "source": "github", "repo": "janclem/agent-platform" } }
  },
  "enabledPlugins": { "platform@agent-platform": true }
}
```

## Credits

The architecture follows Robbie Palmer's
[semi-autonomous software development](https://robbiepalmer.me/initiatives/semi-autonomous-software-development)
initiative and his [`hq`](https://github.com/Robbie-Palmer/hq) monorepo. Files adapted
from `hq` keep their original copyright notices.

## License

[GNU Affero General Public License v3.0](LICENSE).
