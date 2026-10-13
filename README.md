<p align="center">
  <img src="docs/images/hero.png" width="880" alt="fresh. Your PR merged. Start clean. Example branches feat/login, fix/navbar, wip/rebase, and chore/deps are crossed out. main is level with origin.">
</p>
<p align="center"><em>An example. The branch names are made up.</em></p>

# fresh

**Your PR merged. Start clean.**

One agent skill, one outcome: you are on the default branch, it matches the
remote, and the branches and worktrees that already landed are gone.

## Install

### Claude Code

```bash
/plugin marketplace add Obedience-Corp/fresh
/plugin install fresh@fresh
```

### Codex

Run these in your terminal:

```bash
codex plugin marketplace add Obedience-Corp/fresh
codex plugin add fresh@fresh
```

### Cursor, Grok, OpenCode, and other skill-compatible agents

Install through the [`skills`](https://github.com/vercel-labs/skills) CLI:

```bash
npx skills add https://github.com/Obedience-Corp/fresh --skill fresh -g
```

Select your agents when prompted. `-g` makes the skill available across your
local repositories. Omit it to install into just the current project.
Claude Code and Codex can also use this route instead of the plugin.

To select all five explicitly:

```bash
npx skills add https://github.com/Obedience-Corp/fresh --skill fresh -g \
  --agent claude-code codex cursor grok opencode
```

The repository is currently private, so Git needs access to it. If you have
already cloned it, replace the URL with the local clone's path.

### Use it

Open your project repository in your agent, then say **"Use the fresh skill;
my PR merged."** You can also select it from the agent's skill picker or use
`/fresh` where slash invocation is supported. Restart the agent if it has not
picked up the new skill.

Every install includes the Festival installer under `scripts/`. The skill
runs it on invocation, so it works without a session-start hook. The Claude
plugin also checks Festival at session start.

### Manual installation

Copy the entire `skills/fresh/` folder, including `scripts/`, to one of these
locations. The paths below are also the destinations used by `skills` 1.7.1:

| Agent | Current project | All local projects |
| --- | --- | --- |
| Claude Code | `.claude/skills/fresh/` | `~/.claude/skills/fresh/` |
| Codex | `.agents/skills/fresh/` | `~/.codex/skills/fresh/` |
| Cursor | `.agents/skills/fresh/` | `~/.cursor/skills/fresh/` |
| Grok | `.grok/skills/fresh/` | `~/.grok/skills/fresh/` |
| OpenCode | `.agents/skills/fresh/` | `~/.config/opencode/skills/fresh/` |

For other agents, use their supported `SKILL.md` directory. They need shell
access to run Bash and `camp`. Remote agents need the skill and Festival in
their own environment; a local global install does not install them remotely.

References: [Codex plugin commands](https://learn.chatgpt.com/docs/developer-commands),
[Cursor skills](https://cursor.com/docs/skills),
[Grok skills](https://docs.x.ai/build/features/skills-plugins-marketplaces),
and [skills CLI agent support](https://github.com/vercel-labs/skills#supported-agents).

## What it does

1. Shows you the plan first. Nothing changes until you have seen it.
2. Switches to the default branch and brings it level with `origin`.
3. Deletes local branches that already landed, squash merges included.
4. Removes worktrees whose work already landed.

It will not touch uncommitted work. It stops and asks. It will not delete a
branch whose changes are not on the default branch. It keeps the branch and
says why.

The git work is done by `camp fresh` from
[Festival](https://github.com/Obedience-Corp/festival). That is a tested
binary, not an agent improvising git commands.

## What happens on the first run

- **Festival's `camp` is installed if it is missing.** The release archive
  comes from `Obedience-Corp/festival`, its checksum is verified, and `camp` and
  `fest` go into `~/.local/bin`. If `camp` is installed but too old, it is
  updated through the `festival` manager, or you are shown the command to
  update it. A binary you built or installed yourself is never replaced.
- **Your repository is linked into a `festival` camp** in your home directory
  (`~/campaigns/festival` by default). `camp` prints one line saying so.
- **`camp project unlink` reverses the link.** Linking adds one `.camp` marker
  file to your repository and tells git to ignore it, so `git status` stays
  clean. Unlinking removes it.

## Status

This repository is private and still being built. Until the `camp` change that
links an unlinked repository ships in a Festival release, `fresh` works only in
repositories already linked to a camp. The plugin installs the latest release,
so the skill works everywhere the day that release lands.

## Notes

- macOS and Linux. On Windows, use WSL2.
- In a clone of this repository, the skill is exposed at `.claude/skills/`,
  `.agents/skills/`, `.grok/skills/`, and `.opencode/skills/` through symlinks
  to `skills/fresh/`. To install it elsewhere, use the commands above.
  On Windows, Git needs
  `core.symlinks=true` and Developer Mode to create them. If they do not work,
  copy `skills/fresh/` into your agent's skill directory or use `skills add --copy`.
- Rather not install anything? `npx -y -p @obedience-corp/festival camp fresh`
  runs the same binary from npm's cache.
- Tests: `bash tests/run.sh`.

`fresh` is one command from Festival. For planning and running larger work with
agents, see [Festival](https://github.com/Obedience-Corp/festival).

Apache-2.0. Built by [Obedience Corp](https://obediencecorp.com).
