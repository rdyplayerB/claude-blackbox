#!/usr/bin/env bash
# Remove blackbox hooks from ~/.claude/settings.json and unlink the skill.
# Marker state in ~/.blackbox is left alone (it is only ever a few KB and may
# still describe rescuable sessions).
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
cp "$SETTINGS" "$SETTINGS.bak-blackbox-uninstall-$(date +%Y%m%d-%H%M%S)"

python3 - "$SETTINGS" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
hooks = d.get("hooks", {})
for event in list(hooks):
    kept = []
    for entry in hooks[event]:
        inner = [h for h in entry.get("hooks", []) if "blackbox" not in h.get("command", "")]
        if inner:
            entry["hooks"] = inner
            kept.append(entry)
    if kept:
        hooks[event] = kept
    else:
        del hooks[event]
json.dump(d, open(p, "w"), indent=2)
json.load(open(p))
print("blackbox hooks removed")
PY

rm -f "$HOME/.claude/skills/rescue"
echo "blackbox uninstalled (state in ~/.blackbox retained)"
