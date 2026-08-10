#!/bin/sh
# Renders a thumbnail for every image sitting in the clipboard history, for
# ClipboardPanel.qml.
#
#   clip-thumbs.sh <cache-dir>
#
# Thumbnails are named <id>.png. Existing ones are left alone, so the common
# case — a refresh where nothing changed — costs one `cliphist list` and no
# decoding at all. Entries that have fallen out of the history get their
# thumbnails pruned.

dir=$1
[ -n "$dir" ] || exit 1
mkdir -p "$dir" || exit 1

list=$(cliphist list 2>/dev/null) || exit 0

ids=""
printf '%s\n' "$list" | while IFS='	' read -r id preview; do
    case "$preview" in
        '[[ binary data '*) ;;
        *) continue ;;
    esac

    out="$dir/$id.png"
    [ -s "$out" ] && continue

    # Decode straight into the resize so the full-size image never lands on
    # disk. A clipboard screenshot is several hundred KiB; the thumbnail is a
    # couple of KiB.
    cliphist decode "$id" 2>/dev/null \
        | magick - -resize '320x320>' -strip "$out.tmp" 2>/dev/null

    if [ -s "$out.tmp" ]; then
        mv -f "$out.tmp" "$out"
    else
        rm -f "$out.tmp"
    fi
done

# Prune thumbnails whose entry is gone. Recomputed here rather than in the
# loop above because that loop runs in a subshell and cannot export back.
ids=$(printf '%s\n' "$list" | cut -f1)
for f in "$dir"/*.png; do
    [ -e "$f" ] || continue
    base=${f##*/}
    id=${base%.png}
    printf '%s\n' "$ids" | grep -qx "$id" || rm -f "$f"
done

exit 0
