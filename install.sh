#!/usr/bin/env bash
# blackbox installer — wires the three hooks into ~/.claude/settings.json and
# links the /rescue skill. Only NEW sessions are affected; running sessions
# never re-read hooks, so installing is always safe to do live.
#
# settings.json has been destroyed by a careless tool on this machine before
# (2026-07-27), so this merges via python, backs up first, and restores the
# backup if the result does not parse.
set -euo pipefail

# Wherever this clone lives — the installer must work from any checkout path.
BB="$(cd "$(dirname "$0")" && pwd)"
# Optional argument: which Claude config root to wire (default ~/.claude).
# A machine using CLAUDE_CONFIG_DIR profiles has SEVERAL roots, each with its
# own settings.json — hooks in one root do nothing for sessions under another.
# `blackbox doctor` reports roots that are active but unwired.
ROOT="${1:-$HOME/.claude}"
SETTINGS="$ROOT/settings.json"
[ -f "$SETTINGS" ] || { echo "no settings.json at $SETTINGS" >&2; exit 1; }
TS="$(date +%Y%m%d-%H%M%S)"
BAK="$SETTINGS.bak-blackbox-$TS"

chmod +x "$BB/bin/blackbox"

cp "$SETTINGS" "$BAK"
echo "backed up settings.json -> $BAK"

python3 - "$SETTINGS" "$BB" <<'PY'
import json, sys
settings_path, bb = sys.argv[1], sys.argv[2]
d = json.load(open(settings_path))
hooks = d.setdefault("hooks", {})

def ensure(event, cmd):
    entries = hooks.setdefault(event, [])
    # Idempotent: skip if any hook for this event already invokes blackbox.
    for e in entries:
        for h in e.get("hooks", []):
            if "blackbox" in h.get("command", ""):
                return False
    entries.append({"hooks": [{"type": "command", "command": cmd}]})
    return True

added = []
for event, sub in (("SessionStart", "start"), ("Stop", "stop"), ("SessionEnd", "end")):
    if ensure(event, f'"{bb}/bin/blackbox" hook {sub}'):
        added.append(event)

json.dump(d, open(settings_path, "w"), indent=2)
# Prove the write is valid JSON before declaring success.
json.load(open(settings_path))
print(f"hooks added: {added or 'none (already installed)'}")
PY

if ! python3 -c "import json;json.load(open('$SETTINGS'))" 2>/dev/null; then
  cp "$BAK" "$SETTINGS"
  echo "ERROR: settings.json failed validation — backup restored." >&2
  exit 1
fi

mkdir -p "$ROOT/skills"
ln -sfn "$BB/skills/rescue" "$ROOT/skills/rescue"
echo "linked /rescue skill"
echo "blackbox installed. New sessions are now flight-recorded."
