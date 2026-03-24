#!/bin/bash
# news_statusline.sh — Outputs a random headline for the Claude Code status line.

HEADLINES_FILE="$HOME/.claude/news_cache/headlines.txt"

if [ ! -f "$HEADLINES_FILE" ] || [ ! -s "$HEADLINES_FILE" ]; then
    echo "No headlines cached yet"
    exit 0
fi

# Count lines and pick a random one
TOTAL=$(wc -l < "$HEADLINES_FILE" | tr -d ' ')
LINE=$((RANDOM % TOTAL + 1))
HEADLINE=$(sed -n "${LINE}p" "$HEADLINES_FILE")

# Truncate to 120 chars for status line readability
if [ ${#HEADLINE} -gt 120 ]; then
    HEADLINE="${HEADLINE:0:117}..."
fi

echo "$HEADLINE"
