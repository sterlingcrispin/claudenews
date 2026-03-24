#!/bin/bash
# uninstall.sh — Remove Claude Code News Headlines

set -e

INSTALL_DIR="$HOME/.claude/news"
CACHE_DIR="$HOME/.claude/news_cache"
SETTINGS="$HOME/.claude/settings.json"

echo "Uninstalling Claude Code News Headlines..."

# Remove scripts
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "  Removed $INSTALL_DIR"
fi

# Remove cache
if [ -d "$CACHE_DIR" ]; then
    rm -rf "$CACHE_DIR"
    echo "  Removed $CACHE_DIR"
fi

# Patch settings.json to remove hook and status line
if [ -f "$SETTINGS" ]; then
    echo "  Cleaning settings.json..."
    python3 << 'PYEOF'
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")

with open(settings_path) as f:
    settings = json.load(f)

# Remove our hook from UserPromptSubmit
hooks = settings.get("hooks", {})
existing = hooks.get("UserPromptSubmit", [])
filtered = [
    entry for entry in existing
    if not any(h.get("command", "").endswith("fetch_headlines.sh") for h in entry.get("hooks", []))
]
if filtered:
    hooks["UserPromptSubmit"] = filtered
elif "UserPromptSubmit" in hooks:
    del hooks["UserPromptSubmit"]
if not hooks:
    settings["hooks"] = {}
else:
    settings["hooks"] = hooks

# Remove status line if it's ours
sl = settings.get("statusLine", {})
if sl.get("command", "").endswith("news_statusline.sh"):
    del settings["statusLine"]

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

print("  Cleaned settings.json")
PYEOF
fi

echo ""
echo "Done! Claude Code News Headlines has been removed."
echo "Restart Claude Code for changes to take effect."
