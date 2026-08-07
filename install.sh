#!/usr/bin/env bash
# blackbox installer — wires the three hooks into ~/.claude/settings.json and
# links the /rescue skill. Only NEW sessions are affected; running sessions
# never re-read hooks, so installing is always safe to do live.
#
# settings.json has been destroyed by a careless tool on this machine before
# (2026-07-27), so this merges via python, backs up first, and restores the
# backup if the result does not parse.
set -euo pipefail

BB="$HOME/projects-b/blackbox"
SETTINGS="$HOME/.claude/settings.json"
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

mkdir -p "$HOME/.claude/skills"
ln -sfn "$BB/skill" "$HOME/.claude/skills/rescue"
echo "linked /rescue skill"
echo "blackbox installed. New sessions are now flight-recorded."
