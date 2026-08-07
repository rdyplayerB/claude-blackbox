# blackbox

Flight recorder + rescue for Claude Code sessions.

Born from a real loss: four day-long conversations died with an app quit on
2026-08-06. Two turned out to be sitting on disk, findable but invisible —
saved under a per-profile `CLAUDE_CONFIG_DIR` that no default `--resume` would
ever look in. The other two had been running with transcript saving silently
disabled (an inherited `CLAUDE_CODE_CHILD_SESSION` marker) and were gone,
permanently. blackbox exists so neither happens again.

Claude Code already records everything and can resume from it. What's missing —
and what this adds — is three small things:

| Gap | blackbox answer |
|---|---|
| Nothing notices death — a crash looks like a clean exit | Marker per live session (SessionStart), removed on clean exit (SessionEnd). A marker with a dead pid **is** a crash, with death context preserved. |
| Sessions under non-default `CLAUDE_CONFIG_DIR` are invisible to a default `--resume` | Markers record the config dir; `resume` commands carry it. `scan` sweeps every root ever seen. |
| Transcript saving can be silently OFF — the one unrecoverable state | SessionStart guard: an unmissable warning in the session, with the fix, before any work happens. |

## Install

```
~/projects-b/blackbox/install.sh
```

Backs up `~/.claude/settings.json`, merges three hooks (validated, restored on
failure), links the `/rescue` skill. Only new sessions are affected — running
ones never re-read hooks. `uninstall.sh` reverses it.

## Use

After a crash / force-quit / app death:

```
blackbox rescue     # in a terminal: pick a session, it becomes that session
/rescue             # inside any Claude session: list + copy-paste commands
blackbox list       # just show what's rescuable
blackbox scan       # no markers needed: sweep all storage roots (pre-install crashes)
```

## What it can't do

- Resurrect sessions that never saved a transcript. It can only make sure you
  know *before* the loss, not after.
- Restart background processes the crash killed — the resumed agent re-runs
  them. File edits already on disk survive regardless.
- Watch anything other than Claude Code (v1 scope decision).

## Design constraints

- Hooks swallow every exception — a broken recorder must never break the
  session it records.
- No dependencies: bash + python3 stdlib.
- State is a directory of small JSON files (`~/.blackbox/live/`). Nothing here
  ever duplicates transcript content; the transcript stays the single source
  of truth.
