#!/usr/bin/env bash
# Fetch lyrics for one track and print them as normalised JSON.
#
#   lyrics.sh <artist> <title> <album> <duration-seconds>
#
# Output, always valid JSON so the caller never has to special-case a failure:
#
#   {"kind":"synced","lines":[{"t":12.4,"text":"…"}, …]}
#   {"kind":"plain", "lines":[{"t":-1, "text":"…"}, …]}
#   {"kind":"none",  "lines":[]}
#
# Source is lrclib.net: no account, no API key, and it matches on artist,
# title, album and duration together, which avoids the wrong version of a
# track. Results — including misses — are cached, so a replay costs nothing and
# a track with no lyrics is not re-fetched every time it comes round.
set -uo pipefail

ARTIST="${1:-}"
TITLE="${2:-}"
ALBUM="${3:-}"
DURATION="${4:-0}"

[[ -n $ARTIST && -n $TITLE ]] || {
    echo '{"kind":"none","lines":[]}'
    exit 0
}

CACHE_DIR="$HOME/.cache/quickshell/lyrics"
mkdir -p "$CACHE_DIR"

key=$(printf '%s|%s|%s|%s' "$ARTIST" "$TITLE" "$ALBUM" "$DURATION" | sha1sum | cut -d' ' -f1)
cache="$CACHE_DIR/$key.json"

# Misses are cached too, but expire, so lyrics added later are picked up.
if [[ -f $cache ]]; then
    if [[ $(head -c 24 "$cache") == '{"kind":"none"' ]]; then
        # 7 days
        if [[ -n $(find "$cache" -mtime -7 2>/dev/null) ]]; then
            cat "$cache"
            exit 0
        fi
    else
        cat "$cache"
        exit 0
    fi
fi

raw=$(curl -sG --max-time 10 'https://lrclib.net/api/get' \
    --data-urlencode "artist_name=$ARTIST" \
    --data-urlencode "track_name=$TITLE" \
    --data-urlencode "album_name=$ALBUM" \
    --data-urlencode "duration=$DURATION" 2>/dev/null)

# Fall back to a looser search when the exact match misses — album tags differ
# between Spotify and lrclib more often than titles do.
if [[ -z $raw || $raw == *'"statusCode":404'* ]]; then
    raw=$(curl -sG --max-time 10 'https://lrclib.net/api/search' \
        --data-urlencode "artist_name=$ARTIST" \
        --data-urlencode "track_name=$TITLE" 2>/dev/null)
fi

printf '%s' "$raw" | python3 -c '
import json, re, sys

def parse(synced):
    """LRC cues -> [{t, text}], dropping empty and unparsable lines."""
    out = []
    for line in synced.splitlines():
        m = re.match(r"^\[(\d+):(\d+(?:[.:]\d+)?)\](.*)$", line)
        if not m:
            continue
        text = m.group(3).strip()
        t = int(m.group(1)) * 60 + float(m.group(2).replace(":", "."))
        out.append({"t": round(t, 2), "text": text})
    out.sort(key=lambda r: r["t"])
    return out

def emit(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False))
    sys.exit(0)

try:
    d = json.load(sys.stdin)
except Exception:
    emit({"kind": "none", "lines": []})

# /search returns a list; prefer an entry that actually carries timing.
if isinstance(d, list):
    if not d:
        emit({"kind": "none", "lines": []})
    d = next((r for r in d if r.get("syncedLyrics")), d[0])

if not isinstance(d, dict) or d.get("instrumental"):
    emit({"kind": "none", "lines": []})

synced = d.get("syncedLyrics") or ""
if synced.strip():
    lines = parse(synced)
    if lines:
        emit({"kind": "synced", "lines": lines})

plain = (d.get("plainLyrics") or "").strip()
if plain:
    emit({"kind": "plain",
          "lines": [{"t": -1, "text": l.strip()} for l in plain.splitlines() if l.strip()]})

emit({"kind": "none", "lines": []})
' > "$cache".tmp 2>/dev/null

if [[ -s ${cache}.tmp ]]; then
    mv "$cache".tmp "$cache"
else
    echo '{"kind":"none","lines":[]}' > "$cache"
    rm -f "$cache".tmp
fi

cat "$cache"
