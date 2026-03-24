#!/bin/bash
# fetch_headlines.sh — Fetches news headlines from a random source and caches them.
# Designed to run as a Claude Code UserPromptSubmit hook.

CACHE_DIR="$HOME/.claude/news_cache"
HEADLINES_FILE="$CACHE_DIR/headlines.txt"
LOCK_FILE="$CACHE_DIR/fetch.lock"
FETCH_TIMEOUT=8

mkdir -p "$CACHE_DIR"

# Skip if another fetch is already running
if [ -f "$LOCK_FILE" ]; then
    # Remove stale locks older than 30 seconds
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
    local xml
    xml=$(curl -s --max-time "$FETCH_TIMEOUT" -A "ClaudeNewsBot/1.0" "$url" 2>/dev/null)
    [ -z "$xml" ] && return 1

    local titles
    titles=$(echo "$xml" | xmllint --xpath '//item/title/text()' - 2>/dev/null)
    [ -z "$titles" ] && return 1

    # Output as "SOURCE: headline" lines
    while IFS= read -r title; do
        # Clean up CDATA artifacts and whitespace
        title=$(echo "$title" | sed 's/<!\[CDATA\[//g;s/\]\]>//g;s/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -n "$title" ] && echo "$name: $title"
    done <<< "$titles"
}

fetch_hackernews() {
    # Get top 15 story IDs
    local ids
    ids=$(curl -s --max-time "$FETCH_TIMEOUT" "https://hacker-news.firebaseio.com/v0/topstories.json" 2>/dev/null)
    [ -z "$ids" ] && return 1

    # Extract first 15 IDs
    local id_list
    id_list=$(echo "$ids" | tr -d '[]' | tr ',' '\n' | head -15)

    for id in $id_list; do
        local item
        item=$(curl -s --max-time 5 "https://hacker-news.firebaseio.com/v0/item/${id}.json" 2>/dev/null)
        local title
        title=$(echo "$item" | grep -o '"title":"[^"]*"' | head -1 | sed 's/"title":"//;s/"$//')
        [ -n "$title" ] && echo "Hacker News: $title"
    done
}

# Pick a random source (0 = Hacker News, 1-13 = RSS feeds)
SOURCE_INDEX=$((RANDOM % (${#FEEDS[@]} + 1)))

TEMP_FILE="$CACHE_DIR/headlines_new.txt"

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
    # Append new headlines to existing cache, keep last 200 lines
    if [ -f "$HEADLINES_FILE" ]; then
        cat "$HEADLINES_FILE" >> "$TEMP_FILE"
    fi
    tail -200 "$TEMP_FILE" > "$HEADLINES_FILE"
fi

rm -f "$TEMP_FILE"
