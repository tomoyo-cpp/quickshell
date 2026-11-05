#!/bin/sh
# Picks a wallpaper: writes its path to ~/.local/state/rice/wallpaper, outside
# the repo. The shell watches that file and draws both copies, sharp and
# blurred (surfaces/Wallpaper.qml); current-wallpaper.sh reads it back.
set -eu

WALLPAPER="${1:?usage: set-wallpaper.sh /path/to/image}"
[ -f "$WALLPAPER" ] || { echo "no such file: $WALLPAPER" >&2; exit 1; }

state="${XDG_STATE_HOME:-$HOME/.local/state}/rice/wallpaper"
mkdir -p "$(dirname "$state")"
printf '%s\n' "$WALLPAPER" > "$state"
