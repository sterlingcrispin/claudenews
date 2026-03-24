#!/bin/bash
# install.sh — Install Claude Code News Headlines
# Usage: curl -fsSL https://raw.githubusercontent.com/sterlingcrispin/claudenews/main/install.sh | bash

set -e

INSTALL_DIR="$HOME/.claude/news"
CACHE_DIR="$HOME/.claude/news_cache"
SETTINGS="$HOME/.claude/settings.json"
REPO_BASE="https://raw.githubusercontent.com/sterlingcrispin/claudenews/main"

echo "Installing Claude Code News Headlines..."

# Create directories
mkdir -p "$INSTALL_DIR" "$CACHE_DIR"

# Download scripts (or copy if running from repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/fetch_headlines.sh" ] && [ -f "$SCRIPT_DIR/parse_rss.py" ] && [ -f "$SCRIPT_DIR/news_statusline.sh" ]; then
    echo "  Copying scripts from local repo..."
    cp "$SCRIPT_DIR/fetch_headlines.sh" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/parse_rss.py" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/news_statusline.sh" "$INSTALL_DIR/"
else
    echo "  Downloading scripts..."
    curl -fsSL "$REPO_BASE/fetch_headlines.sh" -o "$INSTALL_DIR/fetch_headlines.sh"
    curl -fsSL "$REPO_BASE/parse_rss.py" -o "$INSTALL_DIR/parse_rss.py"
    curl -fsSL "$REPO_BASE/news_statusline.sh" -o "$INSTALL_DIR/news_statusline.sh"
fi

chmod +x "$INSTALL_DIR/fetch_headlines.sh" "$INSTALL_DIR/news_statusline.sh"

echo "  Scripts installed to $INSTALL_DIR"

# Patch settings.json
echo "  Configuring Claude Code settings..."

python3 << 'PYEOF'
import json, sys, os

settings_path = os.path.expanduser("~/.claude/settings.json")
install_dir = os.path.expanduser("~/.claude/news")

# Load or create settings
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    os.makedirs(os.path.dirname(settings_path), exist_ok=True)
    settings = {}

# Add hook
hook_cmd = os.path.join(install_dir, "fetch_headlines.sh")
hook_entry = {"hooks": [{"type": "command", "command": hook_cmd, "async": True}]}

hooks = settings.get("hooks", {})
existing = hooks.get("UserPromptSubmit", [])

# Check if already installed
already_installed = any(
    any(h.get("command", "").endswith("fetch_headlines.sh") for h in entry.get("hooks", []))
    for entry in existing
)

if not already_installed:
    existing.append(hook_entry)
    hooks["UserPromptSubmit"] = existing
    settings["hooks"] = hooks
    print("  Added UserPromptSubmit hook")
else:
    print("  Hook already configured, skipping")

# Add status line
statusline_cmd = os.path.join(install_dir, "news_statusline.sh")
if settings.get("statusLine", {}).get("command", "").endswith("news_statusline.sh"):
    print("  Status line already configured, skipping")
else:
    if "statusLine" in settings:
        print(f"  WARNING: Existing statusLine found, overwriting")
    settings["statusLine"] = {"type": "command", "command": statusline_cmd}
    print("  Added status line")

# Write settings
with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

PYEOF

# Run initial fetch so headlines are ready immediately
echo "  Fetching initial headlines..."
"$INSTALL_DIR/fetch_headlines.sh" 2>/dev/null || true

echo ""
echo "Done! Restart Claude Code to see news headlines in your status line."
echo "Each message you send will fetch fresh headlines in the background."
echo ""
echo "To uninstall: curl -fsSL $REPO_BASE/uninstall.sh | bash"
