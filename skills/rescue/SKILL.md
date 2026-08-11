---
name: rescue
description: Rescue crashed Claude Code sessions. Lists what died without a clean exit (crash, force-quit, killed terminal) and hands back the exact command to resume each one with full context. Use when a session crashed, an app killed sessions, a conversation was lost, or the user wants to continue where a dead session left off.
---

# Session rescue

The blackbox flight recorder marks every Claude Code session at start and
clears the mark on clean exit. A mark whose process is dead is a crashed
session — with its working directory, config dir (per-profile auth setups
store transcripts in non-default roots), and last exchange known.

**Voice: short and surgical.** The user is here for ONE thing: the session
that died in THIS project. A few short lines, then the command. Never list
sessions from other projects, never pad with caveats they didn't ask about.

## Steps

0. Locate the CLI — it records its own path on every run, but verify the
   recorded path is still executable before trusting it (the clone it points
   at may have moved):
   `BB="$(cat ~/.blackbox/bin-path 2>/dev/null)"; [ -x "$BB" ] || BB=""`.
   If empty, fall back to `$CLAUDE_PLUGIN_ROOT/bin/blackbox`, then the newest
   `~/.claude/plugins/cache/*/*blackbox/*/bin/blackbox` — applying the
   same `[ -x ]` check to each candidate.
1. Run: `"$BB" list --json` — returns
   `{"crashed": [...], "live_at_risk": [...], "machinery_hidden": [...]}`.
2. **`live_at_risk` first, always** (the one exception to project scoping):
   those sessions are running RIGHT NOW without saving anything — every word
   in them is lost if they die. Tell the user immediately and plainly; that
   loss is still preventable.
3. **Filter `crashed` to THIS project**: keep only entries whose `cwd`
   matches the current working directory. Everything else does not exist as
   far as this conversation is concerned — do not list it, do not summarize
   it, do not offer it.
4. **If this project has crashed session(s)**, present each in this shape
   and nothing more:
   - One line naming what the session was doing (from the last exchange).
   - One line: when it died, branch if known.
   - If flagged `maybe_live: true`: one warning line — evidence says it may
     still be running (fresh writes or an unaccounted live claude here);
     confirm its window is really gone first.
   - If flagged `unrecoverable: true`: say plainly the conversation was never
     saved and nothing can restore it; offer `"$BB" salvage <session-id>`
     only if `salvageable` is true. Do not invent hope.
   - Then: "Want it back? Run this in a separate plain terminal:" followed by
     the `resume` command in a code block. Never run it yourself and never
     suggest the `!` prefix — `claude --resume` is interactive and replaces
     its process.
5. **If this project has NO crashed session**, do not present other
   projects' sessions. Run `"$BB" scan --cwd "$PWD"` immediately (no need to
   ask) — it sweeps every storage root for THIS project's saved sessions,
   including ones from before blackbox was installed. Present any plausible
   match the same way as step 4 (scan output includes the resume command).
   Scan shows every saved session for the project, so choose with care: the
   newest tiny entries are usually this very conversation and the pane the
   user just restarted — never offer those. The lost session is typically
   the most recent SUBSTANTIVE one whose preview matches what the user was
   doing; if several are plausible, show the top one or two, newest first.
6. **If scan finds nothing either**, say exactly that in two lines: no saved
   session for this project was found in any known storage root, and the
   next diagnostic step is `"$BB" doctor --json` (reports unwired config
   roots, hook errors, and sessions that changed on disk without blackbox
   seeing them). If other projects do have crashed sessions, one closing
   pointer is allowed — "N crashed sessions exist in other projects; run
   /rescue there or `blackbox list` to see them" — with no details.

## Rules

- Never delete marker files yourself; `blackbox rescue` consumes them on use.
- Never resume, or encourage resuming, a `maybe_live` session without the
  user confirming its window is gone.
- If results look wrong (a session the user KNOWS crashed isn't found), run
  `"$BB" doctor --json` before guessing.
