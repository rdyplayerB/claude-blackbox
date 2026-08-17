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

```
/plugin marketplace add rdyplayerB/claude-blackbox
/plugin install blackbox@rdyplayerB
```

## When you need this

- Claude Code crashed, or the app force-quit, and the conversation seems gone
- You closed a terminal (or your machine restarted) mid-task and want to
  resume the session with its full context
- `claude --resume` shows nothing because the session ran under a
  per-profile `CLAUDE_CONFIG_DIR`
- You want to know a session stopped saving its transcript *while it is
  still running*, not after the loss

If a crash already happened before you found this page: install, then run
`blackbox scan`, which finds resumable sessions from before blackbox existed.

## Why it exists

One app quit took out four day-long conversations at once. Two had been sitting
on disk the whole time, findable but invisible, saved under a per-profile
`CLAUDE_CONFIG_DIR` that no default `--resume` would ever look in. The other two
had been running with transcript saving silently switched off by an inherited
`CLAUDE_CODE_CHILD_SESSION` marker, and those are gone for good. blackbox exists
so neither happens to you.

Claude Code already records everything and can resume from it. Three things are
missing, and blackbox adds them:

| Gap | blackbox answer |
|---|---|
| Nothing notices death; a crash looks like a clean exit | Marker per live session (SessionStart), removed on clean exit (SessionEnd). A marker with a dead pid **is** a crash, with death context preserved. |
| Sessions under non-default `CLAUDE_CONFIG_DIR` are invisible to a default `--resume` | Markers record the config dir; `resume` commands carry it. `scan` sweeps every root ever seen. |
| Transcript saving can be silently OFF, the one unrecoverable state | SessionStart guard: an unmissable warning in the session, with the fix, before any work happens. |


<p align="center">
  <img src="assets/demo.gif" width="920"
       alt="A real claude session is SIGKILLed mid-task. Typing blackbox opens the picker with that crash at the top of the list, above older boxes from the same project. Enter resumes it in place, and the rescued session reports exactly how far it got: numbers 1 through 20.">
</p>

```text
 start ──●────●────●────✕ crash            ●────●────▶ carries on
         record   heartbeat        blackbox rescue
         (marker) (verify saving)  (full memory intact)
```

## How it works

Three hooks and a directory of small JSON files, with no daemon and no
database.

```text
   WHILE SESSIONS RUN                      WHEN YOU GO LOOKING
   any profile, any config root

   claude ─ profile A ┐                    $ blackbox    /rescue
   claude ─ profile B ┤                                    │
   claude ─ profile C ┘                                    │
                     │                                     │
                     │  SessionStart  write the marker     │
                     │  Stop (a turn) stamp it, then       │
                     │                check it saved       │
                     │  SessionEnd    delete the marker    │
                     ▼                                     ▼
   ┌──────────────────────────────┐        ┌──────────────────────────────┐
   │ ~/.blackbox/                 │        │ marker + dead pid            │
   │   live/<sid>.json  pid, cwd, │        │   = a crash to rescue        │
   │     branch, config dir,      │        │ marker + live pid, but the   │
   │     transcript path, flags   │───────▶│   transcript is not growing  │
   │   roots.json  every config   │  read  │   = losing it right now      │
   │     root ever seen           │        │ no marker for a session      │
   │   log.jsonl  every hook,     │        │   = sweep every known root   │
   │     verdict, hazard, rescue  │        └───────────────┬──────────────┘
   └──────────────────────────────┘
                                                           │
   ┌──────────────────────────────┐        ┌──────────────────────────────┐
   │ <config root>/projects/      │        │ the picker                   │
   │   <slug>/<sid>.jsonl         │        │ ▸ T-45m crashed parkfinder   │
   │ Claude Code's own transcript │───────▶│   T-2h  closed  brewlog      │
   │ the source of truth: never   │  gist  │   T-8h  closed  synthkeys    │
   │ copied, never moved          │        └───────────────┬──────────────┘
   └──────────────────────────────┘
                                                           │
                                                           ▼
                                           exec claude --resume <sid>
                                           in its own cwd, its config
                                           root, its original flags
```

Left column is everything on disk: markers blackbox writes, and transcripts
only Claude Code writes and only blackbox reads. Right column is every way in,
and they all end at the same exec.

1. **SessionStart** writes `~/.blackbox/live/<session-id>.json`: pid, cwd,
   git branch, config dir, transcript path, and the launch flags the session
   was started with (permission mode, model), so a rescue can re-launch it
   the way it was actually running. If the session reports no transcript
   path, a warning is printed into the session itself before any work
   happens.
2. **Stop** fires after every completed turn. It stamps the marker, then
   checks the transcript for real conversation records. A completed turn
   that produced none means the session is not saving, and the marker gets a
   hazard flag while there is still time to act. A session that predates
   install gets its marker created here instead of at start.
3. **SessionEnd** deletes the marker.

A marker whose pid is dead is therefore a crashed session. `list` checks each
marker with `kill -0`, pulls the last exchange from the transcript, and prints
a resume command carrying the right `CLAUDE_CONFIG_DIR`. `rescue` picks one and
execs it, so your terminal becomes the resumed session.

## Install

**As a plugin** (the normal way, like claude-mem):

```
/plugin marketplace add rdyplayerB/claude-blackbox
/plugin install blackbox@rdyplayerB
```

That wires the three hooks and the `/rescue` skill automatically, and updates
like any other plugin.

**Or manually** (from a clone, no plugin system needed):

```
./install.sh
```

Backs up `~/.claude/settings.json`, merges three hooks (validated, restored on
failure), links the `/rescue` skill. `uninstall.sh` reverses it.

**Pick one, not both.** Installing both ways runs every hook twice, so
`install.sh` refuses a root that already has the plugin enabled (and
`blackbox doctor` flags a double-wired root if one exists anyway). Either
way is fine; the CLI records its own location (`~/.blackbox/bin-path`) on
every run, so the skill and hooks find it regardless of which path you
chose or where the clone lives.

New sessions are protected immediately either way. Whether an
already-running session picks the hooks up varies by Claude Code version
(observed both ways on one machine in one day), so restart any long-lived
session you care about. Sessions that do fire a hook mid-life register
themselves on their next completed turn.

## Multiple accounts and profiles

Install once and the whole machine is covered, including profiles that do
not exist yet. Claude Code treats every `CLAUDE_CONFIG_DIR` as its own
world with its own settings, so a plugin enabled in one profile does
nothing for the others. That hole once swallowed a session on this
machine while diagnostics said everything was fine. blackbox closes it by
wiring itself: at every session start it reads the `CLAUDE_CONFIG_DIR` of
running claude processes, and any profile it has never wired before gets
wired automatically (through the plugin system when installed, manual
hooks otherwise; ~60ms, atomic, backed up).

```text
   ┌────────────────────────────────────────────────────────────────────┐
   │ ~/.claude          wired: plugin   ✓   sessions recorded           │
   │ ~/profiles/work    wired: hooks    ✓   sessions recorded           │
   │ ~/profiles/side    never wired     ✗   sessions INVISIBLE          │
   └───────────────────────────────────────────────────┴────────────────┘
                                                       ▲
   at every session start, in a root                   │  wired at most
   that is already wired:                              │  once, ever
     ps eww ─▶ CLAUDE_CONFIG_DIR of every ─────────────┘
               running claude process
```

Intent always wins over convenience: each profile is auto-wired at most
once, so disabling blackbox anywhere sticks; `uninstall.sh <root>` removes
that root's wiring whichever kind it is (manual hooks or the plugin
enablement the auto-wirer creates) and writes `~/.blackbox/no-autowire`,
which stops all auto-wiring until you delete it. `blackbox doctor` reports
any profile that is active but unwired.

## Use

After a crash / force-quit / app death, run `blackbox` with no arguments to get
the Black Box Picker:

```text
▄▄▄ BLACK BOXES ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
 filter: _                                               [Tab: this project]
▸  T-45m  crashed parkfinder     add a radius slider to the map search
    T-2h  closed  brewlog        chart caffeine per day from the entries
    T-8h  closed  synthkeys      fix stuck notes when two keys land together
    T-1d  crashed dungeonrun     balance loot drops in the crypt level
    T-2d  closed  invoicely      draft the overdue reminder email
    T-9d  closed  gardenio       water schedule pushes at the wrong hour
 6 of 6 boxes · Enter resume · Esc clear/quit · Tab scope
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
```

One line per session: T-minus age, how it ended, project, and what it was
doing when it stopped. Arrows move, Enter resumes in place, Tab switches
between this project and everything. Typing filters, and filtering replaces
scrolling, which is what keeps years of history navigable in ten rows.
Crashed and cleanly-closed sessions sit in the same list because closing a
terminal window is a clean exit, and either way you want the session back.

The rest of the surface:

```
blackbox rescue          # same picker (numbered list when not a real terminal)
blackbox rescue <id>     # one command, any session: crashed or cleanly closed,
                         # any profile; handles cd + CLAUDE_CONFIG_DIR + exec
blackbox rescue <id> --dangerously-skip-permissions   # flags pass through
blackbox flags <args>    # flags every rescue should add (set once)
/rescue                  # inside any Claude session: this project's sessions + commands
blackbox list            # just show what's rescuable
blackbox scan [--cwd d]  # no markers needed: sweep storage roots (pre-install crashes)
blackbox salvage <id>    # last resort for sessions that never saved
blackbox root <dir>      # register a storage root by hand (rarely needed:
                         # hooks register every root they see automatically)
```

**What salvage does:** a session running with transcript saving disabled still
writes a sidecar file containing no conversation, just ~200-char stubs of each
prompt you typed and an AI-generated title. `salvage` extracts that into a
markdown outline for re-seeding a new session. It recovers an outline rather
than the conversation, so if you are relying on it, the guard has already
failed. It exists because it works *retroactively*: the guard can only protect
sessions started after install, but salvage can still pull the outline out of
losses that predate blackbox entirely.

## What a rescue restores

Everything Claude Code saved: the full conversation, with all its context,
exactly as the transcript on disk recorded it. The resumed session picks up
where the dead one stopped, in the project directory it ran in, under the
config profile that stored it, with the launch flags it was started with.

Those flags are worth a note, because the conversation is not the whole
session: a rescue that quietly drops `--dangerously-skip-permissions` hands
back a session that interrogates you about every command. blackbox records
the behavior-shaping flags (permission mode, model) at session start and
re-applies them. A session with no marker of its own, which is the normal
state for one that closed cleanly, still gets its permission mode back:
Claude Code writes that into the transcript, so it survives in the one file
that always outlives the session. Your standing default fills whatever is
left:

```
blackbox flags --dangerously-skip-permissions   # set once
blackbox rescue <id> --model opus               # or per rescue; typed wins
```

Precedence is most-specific-first: flags you type on the rescue command, then
the session's own recorded flags, then your default. blackbox ships with no
default of its own, so a rescue changes nothing about how you run Claude Code
until you say so.

Any claude flag passes through, including ones released after this tool was
written. The exceptions are the handful that cannot mean anything on a rescue,
which are refused with the reason rather than passed along to fail oddly:
`--resume` and `--continue` (a rescue already names an exact session),
`--session-id`, `--teleport`, `--cloud`, `--print`, `--background`,
`--worktree`, and `--no-session-persistence`, which would switch off the
transcript saving that makes recovery possible at all.

One thing sits outside any tool's reach: the model's context window. A
conversation long enough to need compaction (Claude Code summarizing older
turns to make room) will still need it after a rescue, at the same point it
would have needed it with no crash at all. So a freshly rescued marathon
session may compact soon after coming back. That is the conversation's length,
not the rescue, and nothing is lost that a crash-free session would have kept:
compaction never touches the transcript on disk, and the summary Claude Code
builds is drawn from that intact file. The better the transcript survives, the
better the summary, which is one more quiet reason the recorder guards it.

### What a rescue costs

blackbox itself spends nothing. Finding, listing, and resuming are file reads
by a Python script; no model is in the loop until the resumed session takes
its first turn.

That first turn pays for one prompt-cache rebuild, and it helps to know that
long sessions pay for those routinely anyway. A model call has no memory, so
Claude Code re-sends the whole conversation on every turn; the prompt cache is
what makes those re-sends cheap, and it expires after enough idle time. Every
long break already triggers the same full-price rebuild a rescue does. On the
day-long 10 MB session this tool was built in, the rescue's rebuild was the
sixth of the day and not the largest, because five ordinary coffee-break gaps
had each cost the same with no crash anywhere. After that one turn, pricing
returns to the normal cached rate. What actually drives cost is conversation
length, and it drives it identically in sessions that never crash.

## blackbox and the built-in resume

The built-in resume is the engine, and `rescue` finishes by execing
`claude --resume <session-id>`. The restored session is exactly what Claude
Code itself restores, at the same cost, from the same transcript file.
blackbox's work is everything before that command can be typed. The
difference is finding, not restoring:

| | built-in `/resume` | blackbox |
|---|---|---|
| Restore a saved conversation | ✓ | ✓ (by execing the same resume) |
| Tell you a session crashed at all | no; a crash looks like a clean exit | ✓ dead-pid marker per session |
| Sessions in the current project and profile | ✓ picker | ✓ picker |
| Sessions in other project folders | hidden by default (Ctrl+A widens) | ✓ Tab scope in the picker |
| Sessions under another `CLAUDE_CONFIG_DIR` profile | invisible | ✓ sweeps every root ever seen |
| Set cwd, profile, and launch flags for the resumed session | you arrange them by hand | ✓ `rescue <id>` does cd + config dir + original flags (permission mode, model) + exec |
| Warn a live session that it is not saving | no | ✓ start-of-session guard |
| When nothing was ever saved | nothing to offer | outline recovery via `salvage` |

The rows that matter most are the two in the middle. Resume searches exactly
one config root (the current one) and its picker starts scoped to the current
folder, so on a machine with profiles, "resume shows nothing" usually means
"the session lives in a root resume never looked in", while the transcript
sits on disk the whole time. That is precisely how two of the four sessions
in the origin story stayed lost. And since a crash announces nothing, you can
be missing a session without knowing there is one to look for.

If none of the gaps applies (same profile, same folder, clean close, and you
know which session you want), the built-in resume alone serves fine. The gaps
are just never announced when they do apply.

## Knowing it's working

You should be able to confirm blackbox is recording before you need it to have
recorded. Every hook invocation, guard verdict, hazard transition, rescue, and
swallowed exception writes one JSON line to `~/.blackbox/log.jsonl`
(self-truncating, ~5 MB cap). The reader is:

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

- Resurrect sessions that never saved a transcript. It can only warn you while
  the session is still running and the loss is still preventable.
- Grow the model's context window. A conversation that was long enough to
  compact before the crash resumes just as long, and compacts on the same
  schedule it always would have (see "What a rescue restores").
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
