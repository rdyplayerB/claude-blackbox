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
# A root wired through the plugin system has no manual hooks at all — its
# wiring is an enabledPlugins entry (that is also how the auto-wirer wires
# roots when the plugin is installed). Leaving it meant "uninstalled" while
# every hook kept firing. Enablement is per root; the shared plugin cache
# stays, which is `claude plugin uninstall`'s job, not ours.
ep = d.get("enabledPlugins", {})
plugin_removed = [k for k in list(ep) if k.split("@")[0] == "blackbox"]
for k in plugin_removed:
    del ep[k]
if not ep and "enabledPlugins" in d and plugin_removed:
    del d["enabledPlugins"]
# Atomic: validate the temp file, then rename. A mid-write failure leaves
# settings.json untouched.
tmp = p + ".blackbox-tmp"
with open(tmp, "w") as f:
    json.dump(d, f, indent=2)
json.load(open(tmp))
os.replace(tmp, p)
print("blackbox hooks removed")
if plugin_removed:
    print(f"plugin enablement removed for this root: {', '.join(plugin_removed)}")
    print("(the plugin itself is machine-shared and may serve other roots; "
          "remove it entirely with: claude plugin uninstall blackbox@rdyplayerB)")
PY

# Belt and braces: never leave an unparseable settings.json behind.
if ! python3 -c "import json;json.load(open('$SETTINGS'))" 2>/dev/null; then
  cp "$BAK" "$SETTINGS"
  echo "ERROR: settings.json failed validation — backup restored." >&2
  exit 1
fi

# Remove only the symlink install.sh created. A real directory at that path
# is someone else's work — removing it isn't ours to do, and the failed rm
# used to abort the script after the hooks were already gone.
if [ -L "$ROOT/skills/rescue" ]; then
  rm "$ROOT/skills/rescue"
elif [ -e "$ROOT/skills/rescue" ]; then
  echo "note: $ROOT/skills/rescue is not the symlink install.sh creates — left in place"
fi

# An uninstall is explicit intent: stop the auto-wirer from re-wiring this
# machine behind the user's back (hooks in still-running sessions would
# otherwise resurrect the install within minutes).
mkdir -p "$HOME/.blackbox"
touch "$HOME/.blackbox/no-autowire"
echo "auto-wiring disabled (~/.blackbox/no-autowire; delete that file to re-enable)"
echo "blackbox uninstalled from $ROOT (state in ~/.blackbox retained)"
