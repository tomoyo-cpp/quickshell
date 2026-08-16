#!/bin/sh
# Emits one space-separated sample every two seconds, for SysMon.qml:
#
#   <cpu%> <mem%> <disk%> <tempC> <uptime_s> <rx_B/s> <tx_B/s> \
#   <load1> <procs> <swap%> <cpu_mhz> <mem_avail_kb> <mem_total_kb> \
#   <disk_free_kb> <threads>
#
# CPU and the network rates are deltas between samples, so the first line
# reports 0 for them.

# coretemp exposes "Package id 0" as the whole-package reading; fall back to
# whichever hwmon looks like a CPU sensor, then to a thermal zone.
find_temp_input() {
    for hw in /sys/class/hwmon/hwmon*; do
        name=$(cat "$hw/name" 2>/dev/null)
        case "$name" in
            coretemp | k10temp | zenpower)
                for label in "$hw"/temp*_label; do
                    [ -e "$label" ] || continue
                    case "$(cat "$label")" in
                        "Package id"* | Tctl | Tdie)
                            echo "${label%_label}_input"
                            return
                            ;;
                    esac
                done
                [ -e "$hw/temp1_input" ] && { echo "$hw/temp1_input"; return; }
                ;;
        esac
    done
    for zone in /sys/class/thermal/thermal_zone*; do
        [ "$(cat "$zone/type" 2>/dev/null)" = "x86_pkg_temp" ] && {
            echo "$zone/temp"
            return
        }
    done
}

temp_input=$(find_temp_input)

prev_total=0
prev_idle=0
prev_rx=0
prev_tx=0
first=1

while :; do
    # ── CPU ──────────────────────────────────────────────────────────────
    # /proc/stat's first line is: cpu user nice system idle iowait irq ...
    # Splitting it into positional parameters is the point, so the word
    # splitting here is deliberate rather than an oversight. This is /bin/sh,
    # so there are no arrays to read it into instead.
    # shellcheck disable=SC2046
    set -- $(head -n1 /proc/stat)
    shift          # drop the "cpu" label, leaving $1=user $2=nice $3=system
    idle=$4
    total=0
    for field in "$@"; do
        total=$((total + field))
    done

    d_total=$((total - prev_total))
    d_idle=$((idle - prev_idle))
    if [ "$d_total" -gt 0 ]; then
        cpu=$((100 * (d_total - d_idle) / d_total))
    else
        cpu=0
    fi
    prev_total=$total
    prev_idle=$idle

    # ── Memory ───────────────────────────────────────────────────────────
    mem_total=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
    mem_avail=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)
    mem=$((100 * (mem_total - mem_avail) / mem_total))

    # ── Disk (root filesystem) ───────────────────────────────────────────
    disk=$(df -P / | awk 'NR == 2 { sub(/%/, "", $5); print $5 }')

    # ── Temperature ──────────────────────────────────────────────────────
    if [ -n "$temp_input" ] && [ -r "$temp_input" ]; then
        temp=$(($(cat "$temp_input") / 1000))
    else
        temp=0
    fi

    # ── Uptime ───────────────────────────────────────────────────────────
    uptime_s=$(awk '{ printf "%d", $1 }' /proc/uptime)

    # ── Network (all interfaces except loopback) ─────────────────────────
    rx=0
    tx=0
    while read -r line; do
        case "$line" in
            *:*)
                iface=${line%%:*}
                iface=$(echo "$iface" | tr -d ' ')
                [ "$iface" = "lo" ] && continue
                set -- ${line#*:}
                rx=$((rx + $1))
                tx=$((tx + $9))
                ;;
        esac
    done < /proc/net/dev

    if [ "$first" -eq 1 ]; then
        rx_rate=0
        tx_rate=0
        first=0
    else
        rx_rate=$(((rx - prev_rx) / 2))
        tx_rate=$(((tx - prev_tx) / 2))
    fi
    [ "$rx_rate" -lt 0 ] && rx_rate=0
    [ "$tx_rate" -lt 0 ] && tx_rate=0
    prev_rx=$rx
    prev_tx=$tx

    # ── Extra metrics ───────────────────────────────────────────────────
    load1=$(awk '{ print $1 }' /proc/loadavg)
    procs=$(awk -F/ '{ print $2 }' /proc/loadavg | awk '{ print $1 }')
    threads=$(awk '/^Threads/ { n += $2 } END { print n+0 }' /proc/stat 2>/dev/null)
    [ -z "$threads" ] || [ "$threads" = "0" ] && threads=$(ls /proc/*/task 2>/dev/null | wc -l)

    swap=$(awk '/SwapTotal/ { t = $2 } /SwapFree/ { f = $2 } END { print (t > 0) ? int((t - f) * 100 / t) : 0 }' /proc/meminfo)
    mem_avail=$(awk '/MemAvailable/ { print $2; exit }' /proc/meminfo)
    mem_total=$(awk '/MemTotal/ { print $2; exit }' /proc/meminfo)

    # Average across cores; individual cores drift apart under load.
    cpu_mhz=$(awk '/cpu MHz/ { s += $4; n++ } END { print (n > 0) ? int(s / n) : 0 }' /proc/cpuinfo)

    disk_free=$(df -Pk / 2>/dev/null | awk 'NR == 2 { print $4 }')

    echo "$cpu $mem $disk $temp $uptime_s $rx_rate $tx_rate ${load1:-0} ${procs:-0} ${swap:-0} ${cpu_mhz:-0} ${mem_avail:-0} ${mem_total:-0} ${disk_free:-0} ${threads:-0}"
    sleep 2
done
