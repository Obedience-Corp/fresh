---
name: fresh-configure
description: Configure camp fresh follow-up commands and branch settings for a project. Use when someone wants builds, dependency installation, a dev server, or other commands to run after cleanup, or wants to inspect, edit, reorder, remove, or skip those steps.
license: Apache-2.0
metadata:
  version: "0.2.0"
  author: Obedience Corp
---

# Configure camp fresh

Save the user's requested workflow with `camp fresh configure` subcommands.
Configuring does not run cleanup or execute the saved commands.

1. Locate `camp` and read `camp fresh configure --help`. If missing, use the
   companion `fresh` skill's installer when available (only its setup step), or
   explain that Festival must be installed. Check subcommand help before using
   a feature absent from the installed version; do not replace a developer build.
2. Resolve the registered project name using `camp project list --format json`
   and the repository path. Do not guess from its basename. For an unlinked repo,
   select the user's intended camp, then use `camp project link <repo-path>
   --campaign <camp> --yes --no-commit`; disclose the link and `camp project unlink`
   undo. Ask only if the target camp is unclear. Do not run cleanup to link it.
3. Inspect `camp fresh show-workflow <project-name> --json` and the project's
   existing runner/scripts. Use the requested commands, directories, and order;
   ask only about choices the repo and request do not resolve. Default to this
   project with `--project <project-name>`. Global changes require global intent.
4. Apply the commands below, then read back `show-workflow <project-name> --json`.
   Report the saved scope, order, commands, directories, and failure policy.

## CLI operations

```bash
camp fresh configure add install --run 'npm ci' --project <project-name>
camp fresh configure add build --run 'npm run build' --project <project-name>
camp fresh configure edit build --run 'just build' --project <project-name>
camp fresh configure move build --up --project <project-name>
camp fresh configure remove build --project <project-name>
camp fresh configure set branch --action branch --value feat/next --project <project-name>
camp fresh configure set branch --action inherit --project <project-name>
camp fresh configure set push_upstream --action off --project <project-name>
```

These are examples, not defaults. Prefer the repo's existing commands. Use `--dir`
for a directory relative to the project root. `edit` replaces the whole entry:
resupply its directory and `--continue-on-error` if they should be preserved.
A failure normally stops later steps; set `--continue-on-error` only when wanted.

Project follow-ups replace the global list. The first project `add` does not copy
inherited steps; explicitly add any the user wants to retain. Project `edit` and
`move` copy the effective inherited list before changing it. `remove` addresses
only the stored list; removing its last entry restores inheritance. Always check
the readback. Do not drop inherited steps as a side effect of adding one.

Commands run sequentially through `sh -c`, after a successful cleanup/branch cycle,
in the project root (or `--dir`). A foreground dev server such as `npm run dev`
keeps Fresh running until it exits. Clarify foreground versus managed startup if
needed; use the project's existing service manager for background services. Do
not invent a process supervisor or add `&` silently. Agent runs have no interactive
stdin. Commands must suit that environment.

Omitting `--project` on mutations changes camp-wide defaults. Omitting the project
name from `show-workflow` displays global defaults, even inside a project.
`prune` and `prune_remote` settings are camp-wide; do not change them incidentally.
`camp fresh configure --project <project-name>` is the interactive editor for humans.
`camp fresh --no-follow-up` skips all follow-ups for one run without changing config;
`camp fresh --dry-run` previews the cycle and commands without executing them.
Only run either when the user also requested a cleanup/preview.
