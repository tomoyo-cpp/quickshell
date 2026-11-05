#!/bin/sh
# Prints the wallpaper in use: the one last picked in the Wallpaper tab, or,
# when nothing has been picked yet or that file is gone (a fresh machine), the
# first image in ~/Pictures/Wallpapers. Prints nothing if there is no image
# at all.
#
# The choice lives in ~/.local/state/rice/wallpaper, written by
# set-wallpaper.sh.
#
# Read by Wallpapers.qml, whose choice both wallpaper surfaces draw.

state="${XDG_STATE_HOME:-$HOME/.local/state}/rice/wallpaper"
dir="$HOME/Pictures/Wallpapers"

if [ -r "$state" ]; then
    picked=$(head -n 1 "$state")
    [ -f "$picked" ] && { printf '%s\n' "$picked"; exit 0; }
fi

find "$dir" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' \
    -o -iname '*.jpeg' -o -iname '*.webp' \) 2>/dev/null | sort | head -n 1
