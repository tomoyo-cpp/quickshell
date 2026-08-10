#!/usr/bin/env bash
# Screen recording that offloads H.264 to the iGPU instead of the CPU.
#
#   record.sh              record until Ctrl-C
#   record.sh --preview [full|panels]  run the guided tour and record it
#   record.sh --seconds 60 record for a fixed length
#   record.sh -o out.mp4   choose the output file
#   record.sh --no-audio   video only
#
# Why wl-screenrec and not OBS: this machine is a two-core Broadwell, and
# OBS's default x264 encoder saturates it at 1080p. wl-screenrec hands
# wlr-screencopy buffers straight to VA-API, so encoding happens on the GPU —
# measured at ~0% CPU against OBS's 100%.

set -uo pipefail

OUT=""
SECONDS_LIMIT=""
WITH_PREVIEW=0
FPS=30
AUDIO=1
PREVIEW_MODE=full

while [[ $# -gt 0 ]]; do
    case "$1" in
        --preview)
            WITH_PREVIEW=1
            # Optional tour mode: --preview panels
            if [[ ${2:-} =~ ^(full|panels|windows)$ ]]; then
                PREVIEW_MODE="$2"
                shift
            fi
            ;;
        --no-audio) AUDIO=0 ;;
        --seconds)
            SECONDS_LIMIT="${2:?--seconds needs a value}"
            shift
            ;;
        --fps)
            FPS="${2:?--fps needs a value}"
            shift
            ;;
        -o | --output)
            OUT="${2:?-o needs a path}"
            shift
            ;;
        -h | --help)
            sed -n '2,12p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "unknown option: $1 (try --help)" >&2
            exit 1
            ;;
    esac
    shift
done

command -v wl-screenrec >/dev/null || {
    echo "wl-screenrec is not installed" >&2
    exit 1
}

# iHD is what works on this Gen8 part; the legacy i965 driver fails to
# initialise against libva 1.23.
export LIBVA_DRIVER_NAME="${LIBVA_DRIVER_NAME:-iHD}"

if ! vainfo 2>/dev/null | grep -q 'VAProfileH264.*EncSlice'; then
    echo "warning: no VA-API H.264 encode entrypoint — this will be slow" >&2
fi

# Desktop audio, not the microphone: capture the monitor of the hardware sink,
# which carries the final mix after the equalizer chain. Falls back to the
# default sink's monitor if the ALSA node cannot be found.
audio_monitor() {
    pw-dump 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit()
sinks = [ (o.get("info") or {}).get("props", {}).get("node.name")
          for o in d
          if ((o.get("info") or {}).get("props") or {}).get("media.class") == "Audio/Sink" ]
sinks = [s for s in sinks if s]
hw = next((s for s in sinks if s.startswith("alsa_output")), None)
print((hw or (sinks[0] if sinks else "")) + ".monitor" if (hw or sinks) else "")
' 2>/dev/null
}

AUDIO_ARGS=()
if [[ $AUDIO -eq 1 ]]; then
    MON=$(audio_monitor)
    if [[ -n ${MON:-} ]]; then
        AUDIO_ARGS=(--audio --audio-device "$MON" --audio-codec aac)
        echo "audio: $MON"
    else
        echo "warning: no monitor source found, recording without audio" >&2
    fi
fi

REC_DIR="$HOME/Videos/ScreenRecordings"
mkdir -p "$REC_DIR"
OUT="${OUT:-$REC_DIR/recording-$(date +%Y%m%d-%H%M%S).mp4}"

REC_PID=""
PREVIEW_PID=""

stop_all() {
    # The tour first, so its cleanup is captured before the recording ends.
    #
    # SIGTERM, not SIGINT: bash sets SIGINT to ignored for background commands
    # in a non-interactive shell, and a shell cannot trap a signal that was
    # ignored on entry — so the tour never saw an INT and ran to completion.
    # Measured 24s to stop with INT, 0.5s with TERM.
    if [[ -n ${PREVIEW_PID:-} ]]; then
        kill -TERM "$PREVIEW_PID" 2>/dev/null
        wait "$PREVIEW_PID" 2>/dev/null
        PREVIEW_PID=""
    fi
    stop_recording
}

stop_recording() {
    [[ -n ${REC_PID:-} ]] || return 0
    # SIGINT, not SIGKILL: wl-screenrec finalises the container on interrupt,
    # and a killed recording leaves an unplayable file.
    kill -INT "$REC_PID" 2>/dev/null
    wait "$REC_PID" 2>/dev/null
    REC_PID=""
}

# Reporting the result lives in a function so both exits reach it: stopping
# from the bar sends SIGTERM, and the trap used to exit straight after
# stop_all, skipping this entirely — so a recording ended the normal way was
# the only one that ever announced itself.
REPORTED=0

report() {
    [[ $REPORTED -eq 0 ]] || return 0
    REPORTED=1

    if [[ -s $OUT ]]; then
        ffprobe -v error -select_streams v:0 \
            -show_entries stream=codec_name,width,height \
            -show_entries format=duration,size \
            -of default=noprint_wrappers=1 "$OUT" 2>/dev/null | sed 's/^/  /'
        echo "saved: $OUT"

        local secs bytes length size
        secs=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT" 2>/dev/null)
        bytes=$(stat -c %s "$OUT" 2>/dev/null || echo 0)

        length=$(awk -v s="${secs:-0}" 'BEGIN {
            t = int(s + 0.5)
            h = int(t / 3600); m = int((t % 3600) / 60); sec = t % 60
            if (h > 0) printf "%d:%02d:%02d", h, m, sec
            else       printf "%d:%02d", m, sec
        }')
        size=$(awk -v b="${bytes:-0}" 'BEGIN {
            if (b >= 1073741824) printf "%.1f GB", b / 1073741824
            else                 printf "%.0f MB", b / 1048576
        }')

        notify-send -a "Recorder" -u low \
            "Recording saved · $length" \
            "$(basename "$OUT")
$size — $(dirname "$OUT")" 2>/dev/null
    else
        echo "nothing was recorded" >&2
        notify-send -a "Recorder" -u critical \
            "Recording failed" \
            "Nothing was captured, so no file was written." 2>/dev/null
    fi
}

trap 'stop_all; sleep 0.4; report; exit 0' INT TERM

echo "recording -> $OUT"
wl-screenrec -f "$OUT" --codec avc --max-fps "$FPS" \
    ${AUDIO_ARGS[@]+"${AUDIO_ARGS[@]}"} >/dev/null 2>&1 &
REC_PID=$!

# Give the encoder a moment to come up before anything worth capturing starts.
sleep 1.5

if [[ $WITH_PREVIEW -eq 1 ]]; then
    preview_args=()
    [[ $PREVIEW_MODE != full ]] && preview_args=("--$PREVIEW_MODE")
    "$(dirname "$0")/preview.sh" ${preview_args[@]+"${preview_args[@]}"} &
    PREVIEW_PID=$!
    wait "$PREVIEW_PID"
    PREVIEW_PID=""
elif [[ -n ${SECONDS_LIMIT:-} ]]; then
    sleep "$SECONDS_LIMIT"
else
    echo "recording… Ctrl-C to stop"
    wait "$REC_PID"
    REC_PID=""
fi

stop_all
sleep 0.5
report
[[ -s $OUT ]] || exit 1
