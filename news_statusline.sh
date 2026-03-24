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

# Word-wrap text to COLS width. Prefix is prepended to continuation lines.
wrap() {
    local text="$1"
    local prefix="$2"
    local width="$COLS"
    local line=""
    local first=true

    for word in $text; do
        if [ -z "$line" ]; then
            line="$word"
        elif [ $(( ${#line} + 1 + ${#word} )) -le "$width" ]; then
            line="$line $word"
        else
            echo "$line"
            line="${prefix}${word}"
            width="$COLS"
            first=false
        fi
    done
    [ -n "$line" ] && echo "$line"
}

# Combine title + description into one flowing block
BODY="$SOURCE: $TITLE"
[ -n "$DESC" ] && BODY="$BODY — $DESC"
wrap "$BODY" "  "

# URL on its own line (strip tracking params)
if [ -n "$LINK" ]; then
    LINK="${LINK%%\?*}"
    echo "  $LINK"
fi
