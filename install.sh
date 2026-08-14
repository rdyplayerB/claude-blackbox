#!/usr/bin/env bash
# blackbox installer — wires the three hooks into a Claude config root's
# settings.json and links the /rescue skill. New sessions are protected
# immediately; whether running sessions pick the hooks up varies by Claude
# Code version. Installing is always safe to do live either way.
#
# settings.json has been destroyed by a careless tool on this machine before
# (2026-07-27), so every write here is atomic (temp + rename after validation):
# no failure mode leaves a truncated settings.json behind, and a backup is
# taken first regardless.
set -euo pipefail

# Wherever this clone lives — the installer must work from any checkout path.
BB="$(cd "$(dirname "$0")" && pwd)"
# Optional argument: which Claude config root to wire (default ~/.claude).
# A machine using CLAUDE_CONFIG_DIR profiles has SEVERAL roots, each with its
# own settings.json — hooks in one root do nothing for sessions under another.
# `blackbox doctor` reports roots that are active but unwired.
ROOT="${1:-$HOME/.claude}"
SETTINGS="$ROOT/settings.json"
TS="$(date +%Y%m%d-%H%M%S)"

chmod +x "$BB/bin/blackbox"

# A fresh root (new machine, or a profile that never saved settings) simply
# has no settings.json yet — start it from an empty object rather than
# refusing to protect the root.
if [ ! -f "$SETTINGS" ]; then
  mkdir -p "$ROOT"
  printf '{}\n' > "$SETTINGS"
  echo "created empty $SETTINGS"
fi

# Refuse to create the double-wiring the README warns about: a root already
# wired through the plugin system would run every hook twice with manual
# hooks added on top (doctor diagnoses that after the fact; better to not
# create it). Checked before the backup so a refusal leaves zero residue.
if python3 - "$SETTINGS" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8-sig"))
except Exception:
    sys.exit(1)  # unreadable settings: let the main block report it properly
sys.exit(0 if any(k.split("@")[0] == "blackbox"
                  for k in d.get("enabledPlugins", {})) else 1)
PY
then
  echo "This root already has blackbox enabled as a plugin — installing the"
  echo "manual hooks on top would run every hook twice. Nothing was changed."
  echo "  to update instead:      claude plugin update blackbox@rdyplayerB"
  echo "  to switch to manual:    ./uninstall.sh $ROOT   (then re-run this)"
  exit 1
fi

BAK="$SETTINGS.bak-blackbox-$TS"
cp "$SETTINGS" "$BAK"
echo "backed up settings.json -> $BAK"

python3 - "$SETTINGS" "$BB" <<'PY'
import json, os, sys
# realpath: settings.json is a SYMLINK in dotfiles setups, and os.replace on
# the link path would swap the link for a regular file — orphaning the
# dotfiles copy, whose next sync would then silently remove these hooks.
settings_path, bb = os.path.realpath(sys.argv[1]), sys.argv[2]
try:
    # utf-8-sig: tolerate a BOM some editors prepend.
    d = json.load(open(settings_path, encoding="utf-8-sig"))
except ValueError as e:
    sys.exit(f"blackbox: {sys.argv[1]} is not valid JSON ({e}). "
             "Fix it (or delete it) and re-run — nothing was changed.")
hooks = d.setdefault("hooks", {})
# A hand-edited file can have hooks as a list/string/null. Refuse with a
# sentence instead of a traceback — the backup/restore guard treats a
# traceback as failure anyway, but the user deserves to know what to fix.
if not isinstance(hooks, dict) or any(
        not isinstance(v, list) or any(not isinstance(e, dict) for e in v)
        for v in hooks.values()):
    sys.exit(f"blackbox: the hooks section in {sys.argv[1]} is not the "
             "expected shape (an object of event -> list of entries). "
             "Fix it by hand and re-run — nothing was changed.")

def ensure(event, cmd):
    entries = hooks.setdefault(event, [])
    # Idempotent: skip only if a hook for this event already invokes the
    # blackbox HOOK — matched precisely, because a bare "blackbox" substring
    # also matches unrelated user hooks (e.g. ~/bin/blackbox-theme.sh) and
    # would silently skip real wiring.
    for e in entries:
        for h in e.get("hooks", []):
            if '/bin/blackbox" hook' in h.get("command", ""):
                return False
    entries.append({"hooks": [{"type": "command", "command": cmd}]})
    return True

added = []
for event, sub in (("SessionStart", "start"), ("Stop", "stop"), ("SessionEnd", "end")):
    if ensure(event, f'"{bb}/bin/blackbox" hook {sub}'):
        added.append(event)

# Atomic: write to a temp file, validate THAT, then rename over the original.
# A mid-write failure (disk full, interrupt) leaves settings.json untouched.
tmp = settings_path + ".blackbox-tmp"
with open(tmp, "w") as f:
    json.dump(d, f, indent=2)
json.load(open(tmp))
os.replace(tmp, settings_path)
print(f"hooks added: {added or 'none (already installed)'}")
PY

# Belt and braces: if anything above still left the file unparseable, restore.
if ! python3 -c "import json;json.load(open('$SETTINGS'))" 2>/dev/null; then
  cp "$BAK" "$SETTINGS"
  echo "ERROR: settings.json failed validation — backup restored." >&2
  exit 1
fi

mkdir -p "$ROOT/skills"
ln -sfn "$BB/skills/rescue" "$ROOT/skills/rescue"
echo "linked /rescue skill"
echo "blackbox installed. New sessions are now flight-recorded."
