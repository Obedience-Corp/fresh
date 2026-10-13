---
name: fresh
description: Start clean after a merged PR. Puts the repo on its default branch, level with the remote, and removes branches and worktrees that already landed (squash merges included). Use when someone says "/fresh", "my PR merged", "clean up my branches", or "start fresh".
license: Apache-2.0
metadata:
  version: "0.1.0"
  author: Obedience Corp
  hermes:
    tags:
      - fresh
      - git
      - branches
      - worktrees
      - cleanup
    category: git
---

# /fresh

Your PR merged. Start clean.

`<skill-dir>` is the directory containing this `SKILL.md` (Claude Code prints it
as "Base directory for this skill"). Never guess an install path.

1. **Get `camp`.** Run `bash "<skill-dir>/scripts/ensure-festival.sh"`. It prints
   the path to `camp` on stdout; use that path below. It installs or updates
   Festival only if needed and says so on stderr. Tell the user what it said.
2. **Preview.** `"<camp>" fresh --dry-run`. Show the plan unedited; stop if it fails.
3. **Run.** `"<camp>" fresh`. Use `-b <branch>` in both commands if the user named what is next.
4. **Report** what was deleted, what was kept and why, and any undo line.

Done means: default branch synced with origin, merged work cleaned up, and on
the requested next branch if one was given. Report anything `camp` kept.

## When it stops

- **Step 1 exits 3.** Festival could not be installed or updated. Say what
  the script said and stop.
- **Step 1 exits 4 or 5.** This `camp` cannot yet freshen a repository that is
  not in a camp. Run the preview anyway; it works if the repository is already
  linked. If it says "not in a camp", say so in one or two plain sentences,
  give any update command the script printed, and stop. Do not do the git work
  by hand.
- **`camp` asks for `--campaign`.** Show the camps it listed, ask which one,
  then rerun steps 2 and 3 with `--campaign <name>`. Do not pick.

When `camp` says it linked the repository or created the `festival` camp, repeat
that line to the user, including `camp project unlink`. Never let it be silent.

## Laws

- One repository, one outcome.
- Preview first. Every time.
- Uncommitted changes stop the run. Ask; never stash or commit for the user.
- Never force-delete a branch that `camp` kept.
