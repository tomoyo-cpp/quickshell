#!/bin/sh
# Battery details that Quickshell's UPower binding does not expose, for
# BatteryPanel.qml. One key=value per line:
#
#   vendor=LGC-LGC3.6
#   model=DELL G95J555
#   technology=lithium-polymer
#   serial=37039
#   voltage=8.459
#   design=53.28
#   full=31.9532
#   cycles=42
#   capacity=59.9722
#
# Keys with no value are omitted, so the reader must tolerate absences —
# charge-cycles in particular is commonly "N/A".

dev=$(upower -e 2>/dev/null | grep -m1 'battery_BAT')
[ -n "$dev" ] || exit 0

upower -i "$dev" 2>/dev/null | awk '
    function emit(key, val) {
        gsub(/^[ \t]+|[ \t]+$/, "", val)
        if (val == "" || val == "N/A") return
        # Strip trailing units; the panel formats these itself.
        sub(/[ ]?(Wh|V|W|%)$/, "", val)
        print key "=" val
    }
    /^  vendor:/            { emit("vendor",     substr($0, index($0, ":") + 1)) }
    /^  model:/             { emit("model",      substr($0, index($0, ":") + 1)) }
    /^  serial:/            { emit("serial",     substr($0, index($0, ":") + 1)) }
    /technology:/           { emit("technology", substr($0, index($0, ":") + 1)) }
    /voltage:/              { emit("voltage",    substr($0, index($0, ":") + 1)) }
    /energy-full-design:/   { emit("design",     substr($0, index($0, ":") + 1)) }
    /energy-full:/ && !/design/ { emit("full",   substr($0, index($0, ":") + 1)) }
    /charge-cycles:/        { emit("cycles",     substr($0, index($0, ":") + 1)) }
    /capacity:/             { emit("capacity",   substr($0, index($0, ":") + 1)) }
'
