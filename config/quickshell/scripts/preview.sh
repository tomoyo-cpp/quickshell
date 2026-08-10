#!/usr/bin/env bash
# A guided tour of the shell: opens windows, tiles and floats them, walks the
# bar's panels, hops workspaces and shows the overview.
#
#   preview.sh            full tour
#   preview.sh --slow     the original pace, twice as long
#   preview.sh --fast     brisker still
#   preview.sh --panels   panels only, no windows
#   preview.sh --clean    just close anything a previous run left behind
#
# Ctrl-C at any point stops the tour and closes everything it opened.

set -uo pipefail

# ── Pacing ───────────────────────────────────────────────────────────────
# Divides every `pause`. The tour was originally paced at 1, which made the
# full run drag — every dwell was long enough to read a panel twice. 2 is the
# default now; --slow gets the old timing back.
SPEED=2
MODE=full

for arg in "$@"; do
    case "$arg" in
        --fast) SPEED=3 ;;
        --slow) SPEED=1 ;;
        --panels) MODE=panels ;;
        --windows) MODE=windows ;;
        --clean) MODE=clean ;;
        -h | --help)
            sed -n '2,11p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "unknown option: $arg (try --help)" >&2
            exit 1
            ;;
    esac
done

# `sleep 0.4` style waits, divided by the speed multiplier.
#
# The sleep runs in the background and is waited on, rather than run in the
# foreground. Bash defers a trap until the current foreground command returns,
# so a foreground `sleep 3.4` meant a stop request sat unhandled for up to
# three seconds. Signals are handled immediately while in `wait`.
SLEEP_PID=""
pause() {
    sleep "$(awk -v d="$1" -v s="$SPEED" 'BEGIN{printf "%.3f", d/s}')" &
    SLEEP_PID=$!
    wait "$SLEEP_PID" 2>/dev/null
    SLEEP_PID=""
}

# A wait that ignores SPEED, for time that is not pacing.
#
# The wallpaper swap is the case this exists for: those pauses are not "how
# long to look at this", they are waiting on set-wallpaper.sh and the
# compositor to finish a transition that takes as long as it takes. Dividing
# them by the speed multiplier just films the middle of the crossfade.
hold() {
    sleep "$1" &
    SLEEP_PID=$!
    wait "$SLEEP_PID" 2>/dev/null
    SLEEP_PID=""
}

step() { printf '\033[38;5;183m▸\033[0m %s\n' "$*"; }

niri_do() { niri msg action "$@" >/dev/null 2>&1; }
bar() { qs ipc call bar "$@" >/dev/null 2>&1; }

# ── Windows this run owns ────────────────────────────────────────────────
# Marked with a distinct class so cleanup never touches anything else. Each
# runs in its own systemd scope, so nothing here dies with the shell.
MARK="qs-preview"

# Notifications this run posted. The critical one deliberately never expires,
# so it has to be withdrawn explicitly or it outlives the tour.
NOTIF_IDS=()

notify() { # urgency, summary, body
    local id
    id=$(notify-send -p -u "$1" -a "Preview" "$2" "$3" 2>/dev/null)
    [[ -n ${id:-} ]] && NOTIF_IDS+=("$id")
}

spawn_term() { # title, then command
    local title=$1
    shift
    systemd-run --user --scope --quiet --collect \
        --unit="${MARK}-$(date +%s%N)" \
        kitty --class "$MARK" --title "$title" \
        -o confirm_os_window_close=0 \
        sh -c "$*" >/dev/null 2>&1 &
    # Long enough for the window to map and paint before the next action
    # targets it.
    pause 1.6
}

# Place a float at an absolute position, so they sit apart instead of stacking
# on niri's default spawn point.
float_at() { # x y w h
    niri_do move-window-to-floating
    niri_do set-window-width "$3"
    niri_do set-window-height "$4"
    pause 0.35
    niri msg action move-floating-window -x "$1" -y "$2" >/dev/null 2>&1
}

# The wallpaper is swapped during the workspace section and put back. Captured
# here, and restored from cleanup as well as inline: set-wallpaper.sh persists
# its argument, so an interrupted swap would otherwise make the random pick
# permanent.
AWWW_START="$HOME/.config/niri/start-awww.sh"
ORIG_WALL=$(sed -n 's/^WALLPAPER="\(.*\)"$/\1/p' "$AWWW_START" | head -1)
WALL_SWAPPED=0

current_ws() {
    niri msg --json workspaces 2>/dev/null | python3 -c '
import json, sys
try:
    ws = json.load(sys.stdin)
except Exception:
    print(""); raise SystemExit
cur = next((w for w in ws if w.get("is_focused")), None)
print(cur["idx"] if cur else "")
' 2>/dev/null
}

set_wall() { "$(dirname "$0")/set-wallpaper.sh" "$1" >/dev/null 2>&1; }

restore_wall() {
    [[ $WALL_SWAPPED -eq 1 && -n ${ORIG_WALL:-} && -f ${ORIG_WALL:-/nonexistent} ]] || return 0
    set_wall "$ORIG_WALL"
    WALL_SWAPPED=0
}

cleanup() {
    printf '\n'
    step "closing preview windows"
    # Ask niri for this run's windows by class and close them by id, rather
    # than pkill: that cannot catch an unrelated terminal by accident.
    local ids
    ids=$(niri msg --json windows 2>/dev/null |
        python3 -c '
import json,sys
try: ws=json.load(sys.stdin)
except Exception: sys.exit()
print(" ".join(str(w["id"]) for w in ws if (w.get("app_id") or "")=="'"$MARK"'"))
' 2>/dev/null)
    for id in $ids; do
        niri msg action close-window --id "$id" >/dev/null 2>&1
    done
    for n in ${NOTIF_IDS[@]+"${NOTIF_IDS[@]}"}; do
        busctl --user call org.freedesktop.Notifications \
            /org/freedesktop/Notifications org.freedesktop.Notifications \
            CloseNotification u "$n" >/dev/null 2>&1
    done
    NOTIF_IDS=()

    restore_wall

    bar close
    niri_do close-overview
    step "done"
}
trap 'kill "${SLEEP_PID:-0}" 2>/dev/null; cleanup; exit 130' INT TERM

if [[ $MODE == clean ]]; then
    cleanup
    exit 0
fi

# ── Preflight ────────────────────────────────────────────────────────────
command -v niri >/dev/null || {
    echo "niri is not on PATH" >&2
    exit 1
}
niri msg version >/dev/null 2>&1 || {
    echo "no running niri instance" >&2
    exit 1
}
qs ipc show >/dev/null 2>&1 || {
    echo "quickshell is not running (systemctl --user start quickshell.service)" >&2
    exit 1
}

# `tab` replaced `show`; on an older running instance fall back to indices so
# the tour still works rather than silently doing nothing.
if qs ipc call bar tab system >/dev/null 2>&1; then
    dash() { bar tab "$1"; }
else
    echo "note: running shell predates 'bar tab' — using page indices" >&2
    dash() {
        case "$1" in
            system) bar page 0 ;;
            wallpaper) bar page 1 ;;
            appearance) bar page 2 ;;
            settings) bar page 3 ;;
        esac
    }
fi

# Remembered so the tour puts you back where it found you. The workspace list
# is the source for this — `focused-output` carries no workspace field.
START_WS=$(niri msg --json workspaces 2>/dev/null |
    python3 -c '
import json, sys
try:
    ws = json.load(sys.stdin)
except Exception:
    print(1); raise SystemExit
cur = next((w for w in ws if w.get("is_focused")), None)
print(cur["idx"] if cur else 1)
' 2>/dev/null || echo 1)

# Which workspace holds which demo, so the tour can switch to them by index —
# the bar highlights the one picked, the way clicking it would, rather than
# just stepping up and down.
TILE_WS="$START_WS"
FLOAT_WS=""

# ── 1. Panels ────────────────────────────────────────────────────────────
tour_panels() {
    step "bar panels"
    for p in calendar clipboard notifications network battery; do
        bar toggle "$p"
        pause 2.2
        bar toggle "$p"
        pause 0.5
    done

    step "control centre — every tab"
    for t in system wallpaper appearance settings; do
        dash "$t"
        pause 2.6
    done
    bar close
    pause 0.4
}

# ── 1b. Media player ─────────────────────────────────────────────────────
# Given a section of its own rather than two seconds in the panel sweep: it is
# the piece with the most going on — album art, a scrolling title, the cava
# visualiser, transport, a seek bar and a ten-band equalizer.
tour_media() {
    step "media player"
    bar toggle media
    pause 4.0

    # The tour deliberately never touches transport. It used to pause and
    # resume playback to show the visualiser fall to silence, which meant a
    # three second hole in the audio of every recording — and the recording is
    # the point. Nothing here changes what the player is doing, so there is no
    # original state to capture and restore either.
    step "equalizer: ten bands and presets"
    pause 4.0

    bar close
    pause 0.6
}

# ── 2. Tiling, on the starting workspace ─────────────────────────────────
tour_tiling() {
    step "tiling: three columns"
    spawn_term "fastfetch" "fastfetch; exec sh"
    spawn_term "peaclock" "peaclock"
    spawn_term "yazi" "yazi"
    # Columns default to half the screen each, so three of them overfill it and
    # the workspace stays covered no matter which one has focus.
    pause 3.0

    step "resize the column"
    niri_do set-column-width "60%"
    pause 3.0

    # Consumes one neighbour, not both: two columns still span the screen,
    # where collapsing all three into one would leave half of it empty.
    step "stack two into a tabbed column"
    niri_do consume-or-expel-window-left
    pause 2.4
    niri_do toggle-column-tabbed-display
    pause 3.4
    niri_do toggle-column-tabbed-display
    pause 2.4
}

# ── 3. Floating, on a workspace of its own ───────────────────────────────
# Kept apart from the tiling demo so neither is read against the other's
# clutter, and so the overview later shows two distinctly laid-out workspaces.
tour_floating() {
    step "floating: on its own workspace"
    niri_do focus-workspace-down
    FLOAT_WS=$(current_ws)
    pause 1.4

    spawn_term "cava" "cava"
    float_at 70 560 "34%" "22%"
    pause 2.4

    spawn_term "pipes" "pipes-rs"
    float_at 880 120 "30%" "34%"
    pause 2.8
}

# ── 4. Workspaces + overview ─────────────────────────────────────────────
tour_workspaces() {
    step "workspaces: picking each one directly"
    for ws in "$TILE_WS" "${FLOAT_WS:-$TILE_WS}" "$TILE_WS"; do
        niri msg action focus-workspace "$ws" >/dev/null 2>&1
        pause 2.2
    done

    step "overview"
    niri_do open-overview
    pause 2.4

    # Swapped while the overview is up, with the Wallpaper tab open, so the
    # change is visible across every workspace thumbnail at once.
    local pick
    pick=$(find "$HOME/Pictures/Wallpapers" -maxdepth 1 -type f \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
        ! -samefile "${ORIG_WALL:-/nonexistent}" 2>/dev/null | shuf -n 1)

    if [[ -n ${pick:-} ]]; then
        step "wallpaper: $(basename "$pick")"
        dash wallpaper
        pause 1.6
        WALL_SWAPPED=1
        # hold, not pause: both waits bracket an actual wallpaper transition,
        # so they keep their real durations however fast the rest is running.
        set_wall "$pick"
        hold 2.0
        restore_wall
        hold 1.6
        bar close
        pause 0.6
    fi

    pause 1.2
    niri_do close-overview
    pause 1.0
}

case "$MODE" in
    panels)
        tour_panels
        tour_media
        ;;
    windows)
        tour_tiling
        tour_floating
        tour_workspaces
        ;;
    full)
        tour_panels
        tour_media
        tour_tiling
        tour_floating
        tour_workspaces
        step "toasts"
        notify normal "Notifications" "Toasts follow the accent colour."
        pause 1.8
        notify critical "Critical urgency" "Stays until dismissed — the tour withdraws it."
        pause 2.8
        bar toggle notifications
        pause 2.6
        bar close
        ;;
esac

niri msg action focus-workspace "$START_WS" >/dev/null 2>&1
cleanup
