#!/usr/bin/env bash
# Emits "<source>\t<thumbnail>" per wallpaper, generating the thumbnail if it
# is missing or stale.
#
# Thumbnails are always written as real PNGs because several wallpapers are
# WebP with a .png/.jpg extension, and this Qt build has no WebP plugin — it
# would refuse them as "Unsupported image format".
set -uo pipefail

SRC_DIR="$HOME/Pictures/Wallpapers"
CACHE="$HOME/.cache/quickshell/wallpaper-thumbs"
mkdir -p "$CACHE"

find "$SRC_DIR" -maxdepth 1 -type f \
     \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) |
    sort |
    while IFS= read -r src; do
        thumb="$CACHE/$(printf '%s' "$src" | md5sum | cut -d' ' -f1).png"
        if [ ! -f "$thumb" ] || [ "$src" -nt "$thumb" ]; then
            magick "$src" -resize 400x -strip "PNG24:$thumb" 2>/dev/null || continue
        fi
        printf '%s\t%s\n' "$src" "$thumb"
    done
