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

1. Run: `~/projects-b/blackbox/bin/blackbox list --json` — returns
   `{"crashed": [...], "live_at_risk": [...]}`.
2. **`live_at_risk` first, always**: those sessions are running RIGHT NOW
   without saving anything — every word in them is lost if they die. Tell the
   user immediately and plainly; that loss is still preventable.
3. If `crashed` is empty, say so — and offer
   `~/projects-b/blackbox/bin/blackbox scan`, which sweeps every known storage
   root for recent substantive sessions regardless of markers (covers crashes
   from before blackbox was installed).
3. Otherwise, present each crashed session conversationally: project, branch,
   how long ago it was last active, and the last user/assistant exchange so
   the user can recognize the conversation.
4. Any session flagged `unrecoverable: true` never saved a transcript. Say so
   plainly — nothing can restore it — and do not invent hope.
5. For the session(s) the user wants back, give them the `resume` command to
   run **in their own terminal** (suggest the `!` prefix to run it from the
   prompt). Do not run it yourself: `claude --resume` replaces the current
   session, which would kill the very session the user is speaking through.

## Rules

- Never delete marker files yourself; `blackbox rescue` consumes them on use.
- If every session is recent and alive, say there is nothing to rescue rather
  than guessing.
