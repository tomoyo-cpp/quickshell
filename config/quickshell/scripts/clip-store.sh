#!/bin/sh
# Clipboard history, minus passwords. `wl-paste --watch` runs this for every
# copy, with the copied data on stdin.
#
# Two ways a copy is kept out of cliphist:
#   - the app marked it secret (x-kde-passwordManagerHint), which wl-paste
#     reports as CLIPBOARD_STATE=sensitive and cliphist already skips;
#   - it was copied while KeePassXC had focus, in case a copy arrives
#     without the hint.
#
# How many clips to keep is the shell's "Clipboard history" setting, read
# from its settings file on every copy, so a change applies at once. $1 is
# the fallback while that file does not exist yet.

app=$(niri msg --json focused-window 2>/dev/null | jq -r '.app_id // empty' 2>/dev/null)
case "$app" in
    org.keepassxc.KeePassXC)
        cat >/dev/null
        exit 0
        ;;
esac

# The shell keys its state directory on the md5 of its shell.qml path.
shell="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/shell.qml"
hash=$(printf %s "$shell" | md5sum | cut -d' ' -f1)
settings="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/by-shell/$hash/settings.json"
max=$(jq -r '.clipboardMaxItems // empty' "$settings" 2>/dev/null)
case "$max" in
    '' | *[!0-9]*) max="${1:-15}" ;;
esac

# Global flags go before the subcommand: `cliphist store -max-items N`
# silently ignores N and keeps cliphist's default of 750.
exec cliphist -max-items "$max" store
