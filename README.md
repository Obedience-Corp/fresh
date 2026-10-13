# fresh

**Your PR merged. Start clean.**

Fresh syncs your default branch and removes branches and worktrees whose changes
already landed, including squash merges. Use it through Claude Code, Codex, Cursor,
Grok, or OpenCode, or run `camp fresh` in your terminal.

You see the cleanup plan first. Uncommitted changes stop the run, and branches
with unmerged work are kept.

[Install](#install) · [Watch setup](#configure-your-workflow) · [CLI reference](#cli-reference)

## Configure your workflow

With Festival installed, open the setup screen from your project:

```bash
camp fresh configure
```

It opens on your project's settings. Add an install step, a build, a dev server,
or your own commands. Change branch settings and reorder steps from the same screen.

![Recording of camp fresh configure: opening the project workflow, adding npm ci and npm run build through the forms, and saving both steps.](docs/demos/configure.gif)

Use the arrow keys to navigate, **Enter** to edit, and **a** to add a command.
Changes are saved from the form; configuration does not run cleanup.
[Watch the MP4](docs/demos/configure.mp4) · [Still image](docs/demos/configured.png)

The companion `fresh-configure` skill can do this for you, too:

> Use fresh-configure. After cleanup, install dependencies and build this project.

## After your next merge

Ask your coding agent:

> Use the fresh skill. My PR merged.

Or preview and run it in your terminal:

```bash
camp fresh --dry-run
camp fresh
```

![Recording of camp fresh: previewing cleanup, removing the merged homepage branch, then running the install and build steps saved in the setup screen.](docs/demos/cleanup.gif)

[Watch the MP4](docs/demos/cleanup.mp4) · [Still image](docs/demos/cleaned.png)

These recordings use a disposable demo project and a development build of Camp.
They show the real TUI and commands. [Recording source](docs/demos/README.md).

## Install

**Current availability:** this repository is private, so Git needs access to it.
Until automatic linking ships in Festival, Fresh works only in repositories
already linked to a camp (a Festival workspace).

Install both skills, then select your coding agents when prompted:

```bash
npx skills add https://github.com/Obedience-Corp/fresh --skill fresh fresh-configure -g
```

`-g` makes them available across your local repositories. Omit it for this project
only. Open your project in the agent and use the prompt above. `/fresh` also works
where the agent supports slash invocation.

<details>
<summary>Native Claude Code and Codex plugins</summary>

In Claude Code:

```text
/plugin marketplace add Obedience-Corp/fresh
/plugin install fresh@fresh
```

In your terminal for Codex:

```bash
codex plugin marketplace add Obedience-Corp/fresh
codex plugin add fresh@fresh
```

Both plugins include `fresh` and `fresh-configure`. The Claude plugin also includes
native output cards for supported Claude Code and Desktop Code versions. Codex
can preview the captured output as HTML where the app supports it. Other agents
show the command transcript. [Output support](docs/installation.md#visual-output-in-your-agent).

</details>

Fresh uses the `camp fresh` command from [Festival](https://github.com/Obedience-Corp/festival).
On first use, the skill installs Festival if needed, or explains how to update an
existing install. That provides the `camp` command used in the recordings.
It preserves developer-built binaries. Requires macOS or Linux (WSL2 on Windows),
Bash, and Python 3. [Manual install and setup details](docs/installation.md).

When automatic linking is available, a new repo can be linked into
`~/campaigns/festival`; Camp reports the link and how `camp project unlink` undoes it.
With current releases, use an existing camp as described in the reference below.

## CLI reference

The interactive setup above is the terminal entry point. These commands are also
available for scripts, agents, or direct edits.

<details>
<summary>Manage follow-ups, project scope, branch settings, and one-run options</summary>

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

### Add, edit, reorder, and remove

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

</details>

<p align="center">
  <img src="docs/images/hero.png" width="880" alt="Tangled branches draw into one clean line. Fresh: Your PR merged. Start clean.">
</p>

[Development and tests](docs/development.md) · [Festival](https://github.com/Obedience-Corp/festival) · [Apache-2.0](LICENSE)

Built by [Obedience Corp](https://obediencecorp.com).
