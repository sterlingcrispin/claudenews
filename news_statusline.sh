#!/bin/bash
# news_statusline.sh — Displays the current headline for the Claude Code status line.

CURRENT_FILE="$HOME/.claude/news_cache/current.tsv"

if [ ! -f "$CURRENT_FILE" ] || [ ! -s "$CURRENT_FILE" ]; then
    echo "No headlines cached yet"
    exit 0
fi

ENTRY=$(cat "$CURRENT_FILE")

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

    set -f  # disable glob expansion so *, ?, [...] in headlines are literal
    for word in $text; do
        if [ -z "$line" ]; then
            line="$word"
        elif [ $(( ${#line} + 1 + ${#word} )) -le "$width" ]; then
            line="$line $word"
        else
            echo "$line"
            line="${prefix}${word}"
        fi
    done
    [ -n "$line" ] && echo "$line"
    set +f
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
