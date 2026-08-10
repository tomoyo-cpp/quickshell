#!/usr/bin/env bash
# Applies a wallpaper to both awww surfaces and makes it stick across reboots.
#
# start-awww.sh drives two daemons: the default one draws behind windows, and
# the "backdrop" namespace fills the overview. awww cannot blur, so the
# backdrop copy is pre-rendered with ImageMagick — the same arrangement
# start-awww.sh sets up at login.
set -euo pipefail

WALLPAPER="${1:?usage: set-wallpaper.sh /path/to/image}"
START_SCRIPT="$HOME/.config/niri/start-awww.sh"
BLUR_DIR="$HOME/.cache/quickshell/backdrops"

[ -f "$WALLPAPER" ] || { echo "no such file: $WALLPAPER" >&2; exit 1; }

# Match the blur strength start-awww.sh is configured with.
BLUR=$(sed -n 's/^BLUR=\([0-9]\+\).*/\1/p' "$START_SCRIPT" | head -1)
BLUR=${BLUR:-8}

# Cross-fade rather than snapping. Applied to both surfaces so the sharp
# wallpaper and the blurred backdrop change together.
TRANSITION=(--transition-type any --transition-duration 1)

awww img "${TRANSITION[@]}" "$WALLPAPER"

IMG="$WALLPAPER"
if [ "$BLUR" -gt 0 ] && command -v magick >/dev/null; then
    mkdir -p "$BLUR_DIR"
    # Unique per wallpaper: awww keys its cache on the path, so reusing one
    # filename meant the backdrop kept showing the previous blur.
    key=$(printf '%s|%s' "$WALLPAPER" "$BLUR" | md5sum | cut -d' ' -f1)
    blurred="$BLUR_DIR/$key.png"

    if [ -f "$blurred" ] || magick "$WALLPAPER" -blur 0x"$BLUR" "$blurred"; then
        IMG="$blurred"
        # Keep the cache from growing without bound.
        ls -1t "$BLUR_DIR"/*.png 2>/dev/null | tail -n +13 | xargs -r rm -f
    fi
fi
awww img --namespace backdrop "${TRANSITION[@]}" "$IMG"

# Persist by rewriting the WALLPAPER= line, so a relogin keeps this choice.
if [ -w "$START_SCRIPT" ]; then
    tmp=$(mktemp)
    awk -v img="$WALLPAPER" '
        /^WALLPAPER=/ { print "WALLPAPER=\"" img "\""; next }
        { print }
    ' "$START_SCRIPT" > "$tmp"
    cat "$tmp" > "$START_SCRIPT"
    rm -f "$tmp"
fi
