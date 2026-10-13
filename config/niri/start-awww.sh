#!/usr/bin/env bash
# Two awww surfaces so the wallpaper is visible behind windows AND stays
# still in the overview:
#   - default daemon        -> workspace wallpaper (drawn behind your windows)
#   - "backdrop" namespace  -> backdrop wallpaper (fixed/still, fills overview)
# To change wallpaper permanently: edit the path below, then re-run this script:
#     pkill awww-daemon; ~/.config/niri/start-awww.sh
# For a quick one-off change without editing this file (not kept after reboot):
#     awww img /path/to/new.png                                   # sharp, behind windows
#     magick /path/to/new.png -blur 0x8 ~/.cache/awww-wallpaper-blurred.png
#     awww img --namespace backdrop ~/.cache/awww-wallpaper-blurred.png   # blurred backdrop
WALLPAPER="/home/tomoyo/Pictures/Wallpapers/nix-dracula.png"

# Blur strength (the "sigma" in ImageMagick's -blur 0x<sigma>).
# Higher = blurrier. Rough guide: 4 = subtle, 8 = medium, 20 = heavy, 0 = off.
BLUR=8

awww-daemon &
awww-daemon --namespace backdrop &

# awww can't blur, so pre-render a blurred copy with ImageMagick (cached).
# Falls back to the sharp wallpaper if blur is off or magick is missing.
IMG="$WALLPAPER"
if [ "$BLUR" -gt 0 ] && command -v magick >/dev/null; then
    BLURRED="$HOME/.cache/awww-wallpaper-blurred.png"
    mkdir -p "$HOME/.cache"
    magick "$WALLPAPER" -blur 0x"$BLUR" "$BLURRED" && IMG="$BLURRED"
fi

sleep 0.5

# Sharp wallpaper behind windows; blurred copy only in the overview backdrop.
awww img "$WALLPAPER"
awww img --namespace backdrop "$IMG"
