---
name: rescue
description: List Claude Code sessions that died without a clean exit (crash, force-quit, killed terminal) and hand back the exact command to resume each one with full context. Use when the user says a session crashed, an app killed their sessions, they lost a conversation, or they want to continue where a dead session left off.
---

# Session rescue

The blackbox flight recorder marks every Claude Code session at start and
clears the mark on clean exit. A mark whose process is dead is a crashed
session — with its working directory, config dir (per-profile auth setups
store transcripts in non-default roots), and last exchange known.

## Steps

0. Locate the CLI — it records its own path on every run, but verify the
   recorded path is still executable before trusting it (the clone it points
   at may have moved):
   `BB="$(cat ~/.blackbox/bin-path 2>/dev/null)"; [ -x "$BB" ] || BB=""`.
   If empty, fall back to `$CLAUDE_PLUGIN_ROOT/bin/blackbox`, then the newest
   `~/.claude/plugins/cache/*/claude-blackbox/*/bin/blackbox` — applying the
   same `[ -x ]` check to each candidate.
1. Run: `"$BB" list --json` — returns
   `{"crashed": [...], "live_at_risk": [...], "machinery_hidden": [...]}`.
2. **`live_at_risk` first, always**: those sessions are running RIGHT NOW
   without saving anything — every word in them is lost if they die. Tell the
   user immediately and plainly; that loss is still preventable.
3. If `crashed` is empty, say so — and offer `"$BB" scan`, which sweeps every
   known storage root for recent substantive sessions regardless of markers
   (covers crashes from before blackbox was installed). If `machinery_hidden`
   is non-empty, mention it: those are sessions spawned by tools (memory
   plugins etc.), listed in case one is actually the user's.
4. Otherwise, present each crashed session conversationally: project, branch,
   how long ago it was last active, and the last user/assistant exchange so
   the user can recognize the conversation.
5. Any session flagged `unrecoverable: true` never saved a transcript. Say so
   plainly — nothing can restore it — and do not invent hope.
6. For the session(s) the user wants back, give them the `resume` command to
   run **in a separate plain terminal**. Do not run it yourself, and do not
   suggest the `!` prefix: `claude --resume` is an interactive program that
   replaces its process, so running it from inside a session nests one TUI
   in another or kills the very session the user is speaking through.

## Rules

- Never delete marker files yourself; `blackbox rescue` consumes them on use.
- If every session is recent and alive, say there is nothing to rescue rather
  than guessing.
- If results look wrong (a session the user KNOWS crashed isn't listed), run
  `"$BB" doctor --json` — it reports unwired config roots, hook errors, and
  sessions that changed on disk without blackbox seeing them.
