# Show the actual camp fresh output

Use the bundled capture script from the user's repository. It invokes `camp fresh`
once, streams its output, and returns its exit status plus a JSON report on stdout.
It never implements cleanup itself. Python 3 is required (also used by the installer).

Preview:

```bash
python3 "<skill-dir>/scripts/fresh-output.py" --camp "<camp>" -- --dry-run
```

Run, after showing a successful preview:

```bash
python3 "<skill-dir>/scripts/fresh-output.py" --camp "<camp>" --
```

Pass the same project, branch, campaign, and other requested flags after `--` in
both commands; only the preview adds `--dry-run`. Invoke each capture as its own
shell tool call, so the renderer can recognize stdout. Do not pipe it through
another command or merge stderr into stdout. Configuration is a separate task:
use `fresh-configure` when available, without running cleanup to save settings.

## Display

- **Claude plugin with Mods enabled:** the `ToolResult` renderer shows a native
  output card in Claude Code's terminal and Desktop Code tab. It shows the literal
  transcript with preview/completed/failed status. A skills-only install has no mod.
- **Codex app:** include a clickable `[View camp fresh output](<absolute htmlPath>)`
  link using the `htmlPath` returned by the report. The app can open HTML previews
  where that feature is available. If the host provides an inline HTML visualization
  skill/tool, use its supported contract to display this file in the conversation.
- **Other hosts or unavailable rendering:** show `output` verbatim in a fenced text
  block and link `transcriptPath`. Do not silently replace the command's output
  with a success summary. If the native card is absent, use this fallback too.

Show the preview before running cleanup and show the final report afterward.
These are completed command snapshots; ordinary shell output streams while running.
No animation or live app progress is promised. An HTML file contains escaped text,
no scripts, remote assets, or command buttons. Report files may contain command logs;
keep them local unless the user requests sharing.

The default is a private temporary directory outside the repository. For a lasting
app artifact, pass `--output-dir "<existing task artifact directory>"` before `--`.
Never put the report inside the repo being cleaned: it would create uncommitted work.
The script creates a unique directory containing `output.html`, `report.json`, and
`transcript.txt`. Long displays are explicitly shortened; the transcript is complete.
Read the full transcript before reporting kept work, warnings, or undo instructions
if `truncated` is true. Do not interpret exit 0 as every follow-up passing: a step
configured to continue on error can fail while Camp exits successfully.

If capture cannot start, Camp has not run. If Camp ran but saving the visual failed,
use the existing tool output/transcript. **Never rerun cleanup just to get a visual.**
