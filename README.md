<p align="center">
  <img src="docs/images/hero.png" width="880" alt="fresh. Your PR merged. Start clean. Example branches feat/login, fix/navbar, wip/rebase, and chore/deps are crossed out. main is level with origin.">
</p>
<p align="center"><em>An example. The branch names are made up.</em></p>

# fresh

**Your PR merged. Start clean.**

The `fresh` skill gets you to one outcome: you are on the default branch, it matches the
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
npx skills add https://github.com/Obedience-Corp/fresh --skill fresh fresh-configure -g
```

Select your agents when prompted. `-g` makes the skill available across your
local repositories. Omit it to install into just the current project.
Claude Code and Codex can also use this route instead of the plugin.

To select all five explicitly:

```bash
npx skills add https://github.com/Obedience-Corp/fresh --skill fresh fresh-configure -g \
  --agent claude-code codex cursor grok opencode
```

The repository is currently private, so Git needs access to it. If you have
already cloned it, replace the URL with the local clone's path.

### Use it

Open your project repository in your agent, then say **"Use the fresh skill;
my PR merged."** You can also select it from the agent's skill picker or use
`/fresh` where slash invocation is supported. Restart the agent if it has not
picked up the new skill.

The plugin includes `fresh` and `fresh-configure`. The commands above install both
skills; use `fresh-configure` to manage what runs after cleanup.

The `fresh` skill includes the Festival installer under `scripts/`. It
runs it on invocation, so it works without a session-start hook. The Claude
plugin also checks Festival at session start.

### Manual installation

Copy the entire `skills/fresh/` folder, including `scripts/` and `references/`,
to one of these locations. Copy `skills/fresh-configure/` alongside it as
`fresh-configure/`. The paths below are also the destinations used by `skills` 1.7.1:

| Agent | Current project | All local projects |
| --- | --- | --- |
| Claude Code | `.claude/skills/fresh/` | `~/.claude/skills/fresh/` |
| Codex | `.agents/skills/fresh/` | `~/.codex/skills/fresh/` |
| Cursor | `.agents/skills/fresh/` | `~/.cursor/skills/fresh/` |
| Grok | `.grok/skills/fresh/` | `~/.grok/skills/fresh/` |
| OpenCode | `.agents/skills/fresh/` | `~/.config/opencode/skills/fresh/` |

For other agents, use their supported `SKILL.md` directory. They need shell
access to run Bash, Python 3, and `camp`. Remote agents need the skill and Festival in
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
5. Runs any follow-up commands you configured, in order.

It will not touch uncommitted work. It stops and asks. It will not delete a
branch whose changes are not on the default branch. It keeps the branch and
says why.

The git work is done by `camp fresh` from
[Festival](https://github.com/Obedience-Corp/festival). That is a tested
binary, not an agent improvising git commands.

## Visual output in your agent

Fresh captures the actual `camp fresh` output for both the preview and the run:
checklist rows, branch names, kept work, follow-up logs, and failures.

- **Claude Code plugin:** a Claude Mod renders a native output card in the terminal
  and the Claude Desktop **Code** tab. Mods must be enabled; terminal support starts
  at 2.1.287 and Desktop Code at 2.1.286. A skills-only install has no mod.
- **Codex app:** the skill presents the captured HTML as a local artifact link,
  opening an HTML preview where supported. Hosts with an inline HTML visualization
  facility can show the same file in the conversation.
- **Cursor, Grok, OpenCode, and other hosts:** the literal transcript remains
  available, with the local HTML report as an optional view. If a native card or
  HTML preview is unavailable, the skill displays the transcript as text.

These are snapshots after each command finishes; shell output streams during the
run. The renderer does not replace Camp's cleanup logic or run commands itself.
Reports stay in a private temporary directory outside the repository. They contain
command logs; share them only intentionally. Large visual displays are shortened
with a notice and a complete `transcript.txt` alongside them.

References: [Claude Mods surfaces and versions](https://code.claude.com/docs/en/plugins/mods/overview)
and [app HTML previews](https://learn.chatgpt.com/docs/artifacts-viewer).

## Configure what runs after cleanup

Ask your agent: **"Use fresh-configure. After cleanup, install dependencies, build
this project, and start its dev server."** The companion skill inspects the repo's
existing commands and saves the requested workflow. Configuration alone does not
run cleanup or execute those commands.

You can manage the same settings directly with the CLI. Run these from a linked
project and replace `my-project` with its registered name from:

```bash
camp project list --format json
camp fresh show-workflow my-project
camp fresh show-workflow my-project --json
```

If the repo is not linked yet, link it without running cleanup:

```bash
camp project link /path/to/repo --campaign my-camp --yes --no-commit
```

### Add and maintain commands

For a project using npm, for example:

```bash
camp fresh configure add install --run 'npm ci' --project my-project
camp fresh configure add build --run 'npm run build' --project my-project

# Change a command, keeping its position; optionally use --name to rename it.
camp fresh configure edit build --run 'npm run build:dev' --project my-project

# Move one position earlier or later.
camp fresh configure move build --up --project my-project
camp fresh configure move build --down --project my-project

camp fresh configure remove build --project my-project
camp fresh show-workflow my-project --json
```

Use any command your project needs, including `just` recipes, tests, or scripts.
`--dir apps/web` runs a step in that directory relative to the project root.
Commands run sequentially through `sh -c` after successful cleanup and branch setup.
A failing command stops later steps unless you add `--continue-on-error`. On `edit`,
resupply `--dir` and `--continue-on-error` if you want to keep them: it replaces the
whole entry. Commands in agent runs must work without interactive stdin.

A foreground server such as this keeps `camp fresh` running until the server exits:

```bash
camp fresh configure add dev --run 'npm run dev' --project my-project
```

For a service that should stay running after Fresh returns, use the project's
existing service manager or managed startup script instead. For example, a project
with a Docker Compose setup could use `--run 'docker compose up -d'`. Fresh does not
automatically detach a dev server.

### Scope, preview, and skip

Always pass `--project` for project-specific commands. Omitting it on configuration
subcommands changes the camp-wide defaults. `show-workflow` without a project name
shows those global defaults, even when run from inside a project.

A project's follow-up list **replaces** the global list. The first project `add`
starts a new list; add inherited steps explicitly if you want to retain them.
Project `edit` and `move` copy the inherited list before changing it. `remove` acts
on the stored list, and removing its last entry restores global inheritance.
Check `show-workflow my-project --json` after changes to see what will really run.
Settings are stored in the camp's `.campaign/settings/fresh.yaml`.

```bash
camp fresh configure show                     # all stored follow-up lists
camp fresh configure --project my-project     # interactive editor
camp fresh --dry-run                          # preview; follow-ups do not execute
camp fresh --no-follow-up                     # cleanup; skip follow-ups this once
```

The last command still performs cleanup. Preview it with
`camp fresh --dry-run --no-follow-up` first. Skipping does not change saved settings.

You can also manage the branch created after cleanup and upstream pushing:

```bash
camp fresh configure set branch --action branch --value feat/next --project my-project
camp fresh configure set branch --action no-branch --project my-project
camp fresh configure set branch --action inherit --project my-project
camp fresh configure set push_upstream --action off --project my-project
camp fresh configure set push_upstream --action inherit --project my-project
```

`prune` and `prune_remote` are camp-wide settings. See
`camp fresh configure set --help` before changing them. If your installed release
lacks a subcommand above, update Festival through your existing installation method.

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
- In a clone of this repository, both skills are exposed at `.claude/skills/`,
  `.agents/skills/`, `.grok/skills/`, and `.opencode/skills/` through symlinks
  to both skill folders. To install them elsewhere, use the commands above.
  On Windows, Git needs
  `core.symlinks=true` and Developer Mode to create them. If they do not work,
  copy both skill folders into your agent's skill directory or use `skills add --copy`.
- Rather not install anything? `npx -y -p @obedience-corp/festival camp fresh`
  runs the same binary from npm's cache.
- Tests: `bash tests/run.sh`. With Claude Code installed, also run
  `claude plugin validate .` and `claude plugin test .` for the native Mod.

For an optional check against real Camp/Fest builds, place Linux binaries named
`camp` and `fest` in `/absolute/linux-binaries`, then run from this repo:

```bash
docker run --rm --mount type=bind,src="$PWD",dst=/fresh,readonly \
  --mount type=bind,src=/absolute/linux-binaries,dst=/binaries,readonly \
  alpine:3.21 sh -c 'apk add --no-cache bash git python3 && PATH=/binaries:$PATH bash /fresh/tests/camp.integration.sh'
```

The integration check refuses to run outside a fresh Docker container. It verifies
configuration readback, preview without follow-up execution, merged-branch cleanup,
command order, skip, failure, continue-on-error, and inheritance.

`fresh` is one command from Festival. For planning and running larger work with
agents, see [Festival](https://github.com/Obedience-Corp/festival).

Apache-2.0. Built by [Obedience Corp](https://obediencecorp.com).
