# Installation details

[Back to Fresh](../README.md)

## Manual installation

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


## Invoke the installed skills

| Installation | Cleanup | Configuration |
| --- | --- | --- |
| Codex plugin | `$fresh:fresh` | `$fresh:fresh-configure` |
| Codex standalone skills (`npx skills add` or manual) | `$fresh` | `$fresh-configure` |
| Claude Code | `/fresh` | `/fresh-configure` |

In Codex CLI, `/skills` opens the picker: choose **List skills**, type `fresh`,
select the skill, and send it. Plugin entries show **(fresh)** after the skill
name. Selecting one inserts its full plugin-qualified name. Start a new Codex
session after installation if it is not listed. In an app, use its skill picker
to select the installed skill.

Codex CLI 0.162.1 rejects `/fresh` as an unknown command. Plugins supply skills;
they do not register arbitrary top-level slash commands. Use the native `$`
mention or `/skills` picker. See [Codex skill invocation](https://learn.chatgpt.com/docs/build-skills#how-chatgpt-and-codex-use-skills).

In Claude Code, `/fresh:fresh` and `/fresh:fresh-configure` select the plugin's
skills explicitly if a different installed skill uses the same short name.
See [Claude skill command names](https://code.claude.com/docs/en/skills#how-a-skill-gets-its-command-name).

For other agents, select the installed skill using that agent's picker, or ask
it to use **fresh** or **fresh-configure** by name.

## What happens on the first run

Automatic linking is included in [Festival v0.3.21](https://github.com/Obedience-Corp/festival/releases/tag/v0.3.21)
with Camp v0.15.0. Previewing an unlinked repository does not create a camp or
link the repository; the link is created when you run cleanup.

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


## Requirements and scope

- macOS or Linux; use WSL2 on Windows.
- Bash and Python 3 for the skill; the installer provides Festival when needed.
- Global installs apply to local repositories. Remote agents need their own install.
- A repository clone exposes both skills through `.claude/skills/`, `.agents/skills/`,
  `.grok/skills/`, and `.opencode/skills/` symlinks. On Windows, Git needs
  `core.symlinks=true` and Developer Mode; otherwise copy both skill folders or use
  `skills add --copy`.

To select all five agents explicitly:

```bash
npx skills add https://github.com/Obedience-Corp/fresh --skill fresh fresh-configure -g \
  --agent claude-code codex cursor grok opencode
```

For terminal-only use without installing the skills:

```bash
npx -y -p @obedience-corp/festival camp fresh --dry-run
npx -y -p @obedience-corp/festival camp fresh
```

Review the preview before running cleanup. If an older developer-built Camp cannot
link an unlinked repository, update it through your existing installation method
or link the repository to a camp first. Fresh does not replace your developer build.
