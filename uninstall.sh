#!/usr/bin/env bash
# Remove blackbox hooks from a Claude config root's settings.json and unlink
# the skill. Same optional root argument as install.sh — a machine using
# CLAUDE_CONFIG_DIR profiles has several roots and each must be unwired where
# it was wired. Marker state in ~/.blackbox is left alone (it is only ever a
# few KB and may still describe rescuable sessions).
set -euo pipefail

ROOT="${1:-$HOME/.claude}"
SETTINGS="$ROOT/settings.json"
[ -f "$SETTINGS" ] || { echo "no settings.json at $SETTINGS — nothing to unwire"; exit 0; }

BAK="$SETTINGS.bak-blackbox-uninstall-$(date +%Y%m%d-%H%M%S)"
cp "$SETTINGS" "$BAK"

python3 - "$SETTINGS" <<'PY'
import json, os, sys
# realpath: keep a dotfiles symlink intact — os.replace on the link path
# would swap the link for a regular file (see install.sh).
p = os.path.realpath(sys.argv[1])
try:
    d = json.load(open(p, encoding="utf-8-sig"))
except ValueError as e:
    sys.exit(f"blackbox: {sys.argv[1]} is not valid JSON ({e}). "
             "Nothing was changed.")
hooks = d.get("hooks", {})
for event in list(hooks):
    kept = []
    for entry in hooks[event]:
        # Precise match — a bare "blackbox" substring would also delete
        # unrelated user hooks that merely mention the word.
        inner = [h for h in entry.get("hooks", [])
                 if '/bin/blackbox" hook' not in h.get("command", "")]
        if inner:
            entry["hooks"] = inner
            kept.append(entry)
    if kept:
        hooks[event] = kept
    else:
        del hooks[event]
# Atomic: validate the temp file, then rename. A mid-write failure leaves
# settings.json untouched.
tmp = p + ".blackbox-tmp"
with open(tmp, "w") as f:
    json.dump(d, f, indent=2)
json.load(open(tmp))
os.replace(tmp, p)
print("blackbox hooks removed")
PY

# Belt and braces: never leave an unparseable settings.json behind.
if ! python3 -c "import json;json.load(open('$SETTINGS'))" 2>/dev/null; then
  cp "$BAK" "$SETTINGS"
  echo "ERROR: settings.json failed validation — backup restored." >&2
  exit 1
fi

rm -f "$ROOT/skills/rescue"
echo "blackbox uninstalled from $ROOT (state in ~/.blackbox retained)"
