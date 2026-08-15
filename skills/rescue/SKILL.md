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
Speak in Claude Code terms, not aviation terms: open with something like
"Checking your recent Claude Code sessions…" — never "checking the flight
recorder" or other black-box jargon. The tool's internals stay internal.

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
3. **Gather THIS project's sessions, however they ended.** Users reach for
   /rescue to get their last session back; they do not care whether it
   crashed or closed cleanly (closing a terminal window IS a clean exit and
   leaves no crash marker). So collect BOTH:
   - crashed entries from step 1 whose `cwd` matches the current working
     directory, and
   - `"$BB" scan --cwd "$PWD" --json` (run it now; no need to ask), which
     returns `{"sessions": [...]}`: every saved session for this project,
     newest first, including cleanly-closed ones and ones from before
     blackbox was installed. Same field names as step 1, so both sources are
     read the same way. Entries with `"alive": true` are running right now
     (usually this very conversation) — never offer those.
   Everything from other projects does not exist as far as this conversation
   is concerned — never list it, never summarize it, never offer it.
4. **Present the boxes as a selection, not prose — and every option in ONE
   fixed shape.** Use the question tool (AskUserQuestion or equivalent
   selectable-options UI) with as many session options as it allows (aim
   for eight; if capped lower, the newest win), newest first. Use the
   selector even when there is only ONE candidate. The shape, with no
   deviations and no extra facts:
   - label: `T-<age> · <crashed|closed> · <2-4 word gist>`
     where age is T-minus from now in the single coarsest unit: `T-45m`,
     `T-8h`, `T-3d`. Examples:
       `T-8h · crashed · Reel studio preview`
       `T-3d · closed · diagram controls audit`
   - description: ONE line, what the session was doing, drawn from its last
     exchange. BANNED everywhere in the selector: file sizes, turn counts,
     token counts, config-profile notes, resume advice, and any
     "most recent real work" style commentary — all of that belongs AFTER
     selection or nowhere. The only permitted extra is a trailing
     `⚠ may still be running` or `✗ never saved` when the session carries
     that flag.
   - the built-in free-text option covers "none of these": treat typed text
     as a session-id prefix or a phrase to search `"$BB" scan --cwd "$PWD"`
     output for, then re-present matches the same way.
   When the user picks one, deliver step 4b for exactly that session. If the
   selection UI is genuinely unavailable, fall back to a compact table with
   the SAME columns (T-age, status, gist) — never paragraphs.
   Flag meanings, applied at selection time:
   - `maybe_live: true`: evidence says it may still be running; confirm its
     window is really gone before resuming.
   - `unrecoverable: true`: the conversation was never saved and nothing can
     restore it; offer `"$BB" salvage <session-id>` only if `salvageable`
     is true. Do not invent hope.
4b. **Deliver the chosen box.** ALWAYS lead with the same command, so the
   answer never looks like it changes shape from one rescue to the next:

   ```
   blackbox rescue <session-id>
   ```

   (`"$BB" rescue <session-id>` if `command -v blackbox` fails.) This works
   from any directory, any profile, every time: it handles the project
   directory, the config profile, the original launch flags, and the exec.
   Never show the long cd/CLAUDE_CONFIG_DIR/claude form, never run it
   yourself, never suggest the `!` prefix (`claude --resume` is interactive
   and replaces its process).

   **Then, ONLY if the entry's `resume_in_place` is true**, add the in-pane
   shortcut as a second option. blackbox computes that field for you against
   the pane you are asking from; it is true only when the session ran in
   THIS directory under THIS config root. Do not re-derive it by comparing
   paths yourself, and if the field is missing entirely (an older binary is
   answering), simply skip the shortcut — the command above always works.

   The directory half matters as much as the profile half: the built-in
   `/resume` swaps the conversation but does NOT move the pane, so resuming
   another project's session here would run it against THIS directory and
   edits would land in the wrong repo. When both match there is nothing to
   move and the shortcut is genuinely equivalent:
   "Since that session ran in this directory and profile, you can also swap
   this pane to it: type `/resume` and pick 「its title」 (Ctrl+A widens the
   picker; this pane's conversation stays saved)." The built-in picker takes
   names, not raw ids.

   When you leave the shortcut out, say why in one clause, so its absence
   reads as a reason rather than a coin flip: "it ran in another project"
   or "it ran under a different profile", then move on. Never offer
   `/resume` for a session from another directory or profile at all.
   Skip non-candidates silently: the newest tiny transcripts are usually
   this very conversation and the pane the user just restarted — never
   offer those.
5. **If neither source has any session for this project**, say exactly that
   in two lines: no saved session for this project was found in any known
   storage root, and the next diagnostic step is `"$BB" doctor --json`
   (reports unwired config roots, hook errors, and sessions that changed on
   disk without blackbox seeing them). If other projects do have crashed
   sessions, one closing pointer is allowed — "N crashed sessions exist in
   other projects; run /rescue there or `blackbox list` to see them" — with
   no details.

## Rules

- Never delete marker files yourself; `blackbox rescue` consumes them on use.
- Never resume, or encourage resuming, a `maybe_live` session without the
  user confirming its window is gone.
- If results look wrong (a session the user KNOWS crashed isn't found), run
  `"$BB" doctor --json` before guessing.
