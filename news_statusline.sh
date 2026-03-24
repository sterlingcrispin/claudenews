#!/bin/bash
# news_statusline.sh — Outputs a random headline for the Claude Code status line.

HEADLINES_FILE="$HOME/.claude/news_cache/headlines.tsv"

if [ ! -f "$HEADLINES_FILE" ] || [ ! -s "$HEADLINES_FILE" ]; then
    echo "No headlines cached yet"
    exit 0
fi

# Count lines and pick a random one
TOTAL=$(wc -l < "$HEADLINES_FILE" | tr -d ' ')
LINE=$((RANDOM % TOTAL + 1))
ENTRY=$(sed -n "${LINE}p" "$HEADLINES_FILE")

# Parse TSV: source \t title \t description \t link
SOURCE=$(echo "$ENTRY" | cut -f1)
TITLE=$(echo "$ENTRY" | cut -f2)
DESC=$(echo "$ENTRY" | cut -f3)
LINK=$(echo "$ENTRY" | cut -f4)

# Get terminal width, default 80
COLS=$(tput cols 2>/dev/null || echo 80)

# Line 1: Source: Title
L1="$SOURCE: $TITLE"
if [ ${#L1} -gt "$COLS" ]; then
    L1="${L1:0:$((COLS - 3))}..."
fi
echo "$L1"

# Line 2: Description (no URL — not clickable in status bar)
if [ -n "$DESC" ]; then
    L2="  $DESC"
    if [ ${#L2} -gt "$COLS" ]; then
        L2="${L2:0:$((COLS - 3))}..."
    fi
    echo "$L2"
fi
