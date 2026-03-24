#!/bin/bash
# fetch_headlines.sh — Fetches news headlines from a random source and caches them.
# Designed to run as a Claude Code UserPromptSubmit hook.

CACHE_DIR="$HOME/.claude/news_cache"
HEADLINES_FILE="$CACHE_DIR/headlines.tsv"
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

parse_rss() {
    local name="$1"
    python3 -c "
import sys, xml.etree.ElementTree as ET, re, html

def clean(text):
    if not text:
        return ''
    text = re.sub(r'<!\[CDATA\[|\]\]>', '', text)
    text = re.sub(r'<[^>]+>', '', text)
    text = html.unescape(text)
    text = ' '.join(text.split())
    return text.strip()

def first_sentence(text):
    if not text:
        return ''
    # Split on sentence-ending punctuation followed by space or end
    m = re.match(r'(.*?[.!?])(?:\s|$)', text)
    if m:
        s = m.group(1)
        if len(s) > 200:
            return s[:197] + '...'
        return s
    if len(text) > 200:
        return text[:197] + '...'
    return text

name = '$name'
xml_data = sys.stdin.read()
try:
    root = ET.fromstring(xml_data)
except ET.ParseError:
    sys.exit(1)

# Handle both RSS and Atom namespaces
ns = {'atom': 'http://www.w3.org/2005/Atom'}
items = root.findall('.//item')
if not items:
    items = root.findall('.//atom:entry', ns)

for item in items:
    title_el = item.find('title') or item.find('atom:title', ns)
    desc_el = item.find('description') or item.find('atom:summary', ns)
    link_el = item.find('link') or item.find('atom:link', ns)

    title = clean(title_el.text if title_el is not None and title_el.text else '')
    desc = first_sentence(clean(desc_el.text if desc_el is not None and desc_el.text else ''))
    link = ''
    if link_el is not None:
        link = link_el.text or link_el.get('href', '')
        link = link.strip()

    if title:
        # TSV: source, title, description, link
        print(f'{name}\t{title}\t{desc}\t{link}')
"
}

fetch_rss() {
    local name="$1"
    local url="$2"
    local xml
    xml=$(curl -s --max-time "$FETCH_TIMEOUT" -A "ClaudeNewsBot/1.0" "$url" 2>/dev/null)
    [ -z "$xml" ] && return 1
    echo "$xml" | parse_rss "$name"
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
        local title url
        title=$(echo "$item" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('title',''))" 2>/dev/null)
        url=$(echo "$item" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('url', 'https://news.ycombinator.com/item?id=$id'))" 2>/dev/null)
        [ -n "$title" ] && printf 'Hacker News\t%s\t\t%s\n' "$title" "$url"
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
