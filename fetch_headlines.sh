#!/bin/bash
# fetch_headlines.sh — Fetches news headlines from a random source and caches them.
# Designed to run as a Claude Code UserPromptSubmit hook.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CACHE_DIR="$HOME/.claude/news_cache"
HEADLINES_FILE="$CACHE_DIR/headlines.tsv"
LOCK_FILE="$CACHE_DIR/fetch.lock"
FETCH_TIMEOUT=8

mkdir -p "$CACHE_DIR"

# Skip if another fetch is already running
if [ -f "$LOCK_FILE" ]; then
    find "$CACHE_DIR" -name "fetch.lock" -mmin +0.5 -delete 2>/dev/null
    [ -f "$LOCK_FILE" ] && exit 0
fi
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# RSS feeds: name|url
FEEDS=(
    "BBC News|https://feeds.bbci.co.uk/news/rss.xml"
    "NPR|https://feeds.npr.org/1001/rss.xml"
    "Al Jazeera|https://www.aljazeera.com/xml/rss/all.xml"
    "The Guardian|https://www.theguardian.com/world/rss"
    "NBC News|https://feeds.nbcnews.com/nbcnews/public/news"
    "CBS News|https://www.cbsnews.com/latest/rss/main"
    "NYT|https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml"
    "PBS NewsHour|https://www.pbs.org/newshour/feeds/rss/headlines"
    "Fox News|https://moxie.foxnews.com/google-publisher/latest.xml"
    "Politico|https://rss.politico.com/politics-news.xml"
    "Bloomberg|https://feeds.bloomberg.com/markets/news.rss"
    "TechCrunch|https://techcrunch.com/feed/"
    "Ars Technica|https://feeds.arstechnica.com/arstechnica/index"
)

fetch_rss() {
    local name="$1"
    local url="$2"
    curl -s --max-time "$FETCH_TIMEOUT" -A "ClaudeNewsBot/1.0" "$url" 2>/dev/null \
        | python3 "$SCRIPT_DIR/parse_rss.py" "$name"
}

fetch_hackernews() {
    local ids
    ids=$(curl -s --max-time "$FETCH_TIMEOUT" "https://hacker-news.firebaseio.com/v0/topstories.json" 2>/dev/null)
    [ -z "$ids" ] && return 1

    local id_list
    id_list=$(echo "$ids" | tr -d '[]' | tr ',' '\n' | head -15)

    for id in $id_list; do
        local item
        item=$(curl -s --max-time 5 "https://hacker-news.firebaseio.com/v0/item/${id}.json" 2>/dev/null)
        [ -z "$item" ] && continue
        echo "$item" | python3 -c "
import sys, json
d = json.load(sys.stdin)
title = d.get('title', '')
url = d.get('url', 'https://news.ycombinator.com/item?id=${id}')
if title:
    print(f'Hacker News\t{title}\t\t{url}')
" 2>/dev/null
    done
}

# Pick a random source (0 = Hacker News, 1-13 = RSS feeds)
SOURCE_INDEX=$((RANDOM % (${#FEEDS[@]} + 1)))

TEMP_FILE="$CACHE_DIR/headlines_new.tsv"

if [ "$SOURCE_INDEX" -eq 0 ]; then
    fetch_hackernews > "$TEMP_FILE" 2>/dev/null
else
    FEED="${FEEDS[$((SOURCE_INDEX - 1))]}"
    NAME="${FEED%%|*}"
    URL="${FEED##*|}"
    fetch_rss "$NAME" "$URL" > "$TEMP_FILE" 2>/dev/null
fi

# Only update cache if we got results
if [ -s "$TEMP_FILE" ]; then
    if [ -f "$HEADLINES_FILE" ]; then
        cat "$HEADLINES_FILE" >> "$TEMP_FILE"
    fi
    tail -200 "$TEMP_FILE" > "$HEADLINES_FILE"
fi

rm -f "$TEMP_FILE"

# Pick a random headline and write to "current" file for stable display
if [ -s "$HEADLINES_FILE" ]; then
    TOTAL=$(wc -l < "$HEADLINES_FILE" | tr -d ' ')
    LINE=$((RANDOM % TOTAL + 1))
    sed -n "${LINE}p" "$HEADLINES_FILE" > "$CACHE_DIR/current.tsv"
fi
