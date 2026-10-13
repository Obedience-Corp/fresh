<p align="center">
  <img src="docs/images/hero.png" width="880" alt="fresh. Your PR merged. Start clean. Example branches feat/login, fix/navbar, wip/rebase, and chore/deps are crossed out. main is level with origin.">
</p>
<p align="center"><em>An example. The branch names are made up.</em></p>

# fresh

**Your PR merged. Start clean.**

One agent skill, one outcome: you are on the default branch, it matches the
remote, and the branches and worktrees that already landed are gone.

## Install

Claude Code:

```bash
/plugin marketplace add Obedience-Corp/fresh
/plugin install fresh@fresh
```

Any other agent, through the [`skills`](https://github.com/vercel-labs/skills) CLI:

```bash
npx skills add https://github.com/Obedience-Corp/fresh --skill fresh
```

Then tell your agent `/fresh`, or just "my PR merged".

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
- The skill is exposed at `.claude/skills/`, `.agents/skills/`, and
  `.opencode/skills/` through symlinks to `skills/fresh/`. On Windows, Git needs
  `core.symlinks=true` and Developer Mode to create them. If they do not work,
  copy `skills/fresh/` into your agent's skill directory.
- Rather not install anything? `npx -y -p @obedience-corp/festival camp fresh`
  runs the same binary from npm's cache.
- Tests: `bash tests/run.sh`.

`fresh` is one command from Festival. For planning and running larger work with
agents, see [Festival](https://github.com/Obedience-Corp/festival).

Apache-2.0. Built by [Obedience Corp](https://obediencecorp.com).
