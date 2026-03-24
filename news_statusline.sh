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

# Line 1: Source: Title
# Line 2: Description... [link]
echo "$SOURCE: $TITLE"
if [ -n "$DESC" ] || [ -n "$LINK" ]; then
    LINE2=""
    [ -n "$DESC" ] && LINE2="$DESC"
    [ -n "$LINK" ] && LINE2="$LINE2 [$LINK]"
    echo "  $LINE2"
fi
