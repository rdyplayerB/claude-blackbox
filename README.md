```text
▛▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▜
▌ ◉                                                                 ◉ ▐
▌                                ● REC                                ▐
▌                                                                     ▐
▌  ██████╗ ██╗      █████╗  ██████╗██╗  ██╗██████╗  ██████╗ ██╗  ██╗  ▐
▌  ██╔══██╗██║     ██╔══██╗██╔════╝██║ ██╔╝██╔══██╗██╔═══██╗╚██╗██╔╝  ▐
▌  ██████╔╝██║     ███████║██║     █████╔╝ ██████╔╝██║   ██║ ╚███╔╝   ▐
▌  ██╔══██╗██║     ██╔══██║██║     ██╔═██╗ ██╔══██╗██║   ██║ ██╔██╗   ▐
▌  ██████╔╝███████╗██║  ██║╚██████╗██║  ██╗██████╔╝╚██████╔╝██╔╝ ██╗  ▐
▌  ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝  ▐
▌                                                                     ▐
▌                   CRASH RECOVERY FOR CLAUDE CODE                    ▐
▌ ◉                                                                 ◉ ▐
▙▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▟
```

<p align="center">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-blue">
  <img alt="claude code" src="https://img.shields.io/badge/Claude_Code-plugin-de7c00">
  <img alt="deps" src="https://img.shields.io/badge/dependencies-zero-brightgreen">
</p>

> **Memory plugins remember what you *learned*. blackbox remembers what you
> were *doing*, and puts you back there.**

This started with a bad afternoon. One app quit took out four day-long
conversations at once. Two of them had been sitting on disk the whole time,
findable but invisible, saved under a per-profile `CLAUDE_CONFIG_DIR` that no
default `--resume` would ever think to look in. The other two had been running
with transcript saving silently switched off, thanks to an inherited
`CLAUDE_CODE_CHILD_SESSION` marker. Those are simply gone. blackbox exists so
neither happens to you.

Claude Code already records everything and can resume from it. What's missing, and what this
adds, is three small things:

| Gap | blackbox answer |
|---|---|
| Nothing notices death; a crash looks like a clean exit | Marker per live session (SessionStart), removed on clean exit (SessionEnd). A marker with a dead pid **is** a crash, with death context preserved. |
| Sessions under non-default `CLAUDE_CONFIG_DIR` are invisible to a default `--resume` | Markers record the config dir; `resume` commands carry it. `scan` sweeps every root ever seen. |
| Transcript saving can be silently OFF, the one unrecoverable state | SessionStart guard: an unmissable warning in the session, with the fix, before any work happens. |


<p align="center">
  <img src="assets/demo.gif" width="920"
       alt="A real claude session is SIGKILLed mid-task, blackbox lists it with its last exchange and resume command, and the resumed session reports exactly how far it got: numbers 1 through 6.">
</p>

```text
 start ──●────●────●────✕ crash            ●────●────▶ carries on
         record   heartbeat        blackbox rescue
         (marker) (verify saving)  (full memory intact)
```

## How it works

Three hooks and a directory of small JSON files. No daemon, no database.

1. **SessionStart** writes `~/.blackbox/live/<session-id>.json`: pid, cwd,
   git branch, config dir, transcript path. If the session reports no
   transcript path, a warning is printed into the session itself before any
   work happens.
2. **Stop** fires after every completed turn. It stamps the marker, then
   checks the transcript for real conversation records. A completed turn
   that produced none means the session is not saving, and the marker gets a
   hazard flag while there is still time to act. A session that predates
   install gets its marker created here instead of at start.
3. **SessionEnd** deletes the marker.

One invariant falls out: a marker whose pid is dead is a crashed session.
`list` checks each marker with `kill -0`, pulls the last exchange from the
transcript, and prints a resume command carrying the right
`CLAUDE_CONFIG_DIR`. `rescue` picks one and execs it, so your terminal
becomes the resumed session.

## Install

**As a plugin** (the normal way, like claude-mem):

```
/plugin marketplace add rdyplayerB/claude-blackbox
/plugin install claude-blackbox@rdyplayerB
```

That wires the three hooks and the `/rescue` skill automatically, and updates
like any other plugin.

**Or manually** (from a clone, no plugin system needed):

```
./install.sh
```

Backs up `~/.claude/settings.json`, merges three hooks (validated, restored on
failure), links the `/rescue` skill. `uninstall.sh` reverses it.

**Pick one, not both.** Installing both ways runs every hook twice. Either is
fine; the CLI records its own location (`~/.blackbox/bin-path`) on every run,
so the skill and hooks find it regardless of which path you chose or where the
clone lives.

Either way, only *new* sessions are affected; running ones never re-read
hooks.

## Use

After a crash / force-quit / app death:

```
blackbox rescue     # in a terminal: pick a session, it becomes that session
/rescue             # inside any Claude session: list + copy-paste commands
blackbox list       # just show what's rescuable
blackbox scan       # no markers needed: sweep all storage roots (pre-install crashes)
blackbox salvage <session-id>   # last resort for sessions that never saved
```

**What salvage is (and isn't):** a session running with transcript saving
disabled still writes a sidecar file: no conversation, just ~200-char stubs
of each prompt you typed and an AI-generated title. `salvage` extracts that
into a markdown outline for re-seeding a new session. It is the consolation
prize, not a recovery: if salvage is ever your primary tool, the guard has
already failed. It exists because it works *retroactively*: the guard can
only protect sessions started after install, but salvage can still pull the
outline out of losses that predate blackbox entirely.

## Knowing it's working

A recorder you can't audit is a recorder you find out about at rescue time.
Every hook invocation, guard verdict, hazard transition, rescue, and swallowed
exception writes one JSON line to `~/.blackbox/log.jsonl` (self-truncating,
~5 MB cap). The reader is:

```
blackbox doctor          # human report
blackbox doctor --json   # for tooling / a Claude session
```

Doctor answers four questions the log alone can't:

- **Are hooks firing at all?** Counts by event over 24h, errors with
  tracebacks, and hook runs slow enough to delay sessions.
- **Is every root wired?** A machine using `CLAUDE_CONFIG_DIR` profiles has
  several config roots, each with its own settings.json, and hooks in one do
  nothing for sessions under another. Doctor names any active-but-unwired
  root and the exact install command. (This precise hole shipped on day one
  and doctor's first run caught it.)
- **Did anything slip past?** Transcripts that changed in the last 24h with
  no matching log entry: sessions blackbox never saw. Pre-install sessions
  show here until they age out; a *growing* miss count after that is a bug.
- **What needs action now?** Live sessions flagged not-saving, crashes
  awaiting rescue.

## What it can't do

- Resurrect sessions that never saved a transcript. It can only make sure you
  know *before* the loss, not after.
- Restart background processes the crash killed. The resumed agent re-runs
  them. File edits already on disk survive regardless.
- Watch anything other than Claude Code (v1 scope decision).

## Design constraints

- Hooks swallow every exception (a broken recorder must never break the
  session it records).
- No dependencies: bash + python3 stdlib.
- State is a directory of small JSON files (`~/.blackbox/live/`). Nothing here
  ever duplicates transcript content; the transcript stays the single source
  of truth.
