pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// Screen backlight.
//
// Reads sysfs directly on a fast poll rather than shelling out to
// `brightnessctl -m` every couple of seconds — spawning a process was both too
// slow for the OSD to feel responsive and too expensive to poll quickly.
// Writes still go through brightnessctl, which owns the permission handling.
Singleton {
    id: root

    readonly property string device: "/sys/class/backlight/intel_backlight"

    property int raw: 0
    property int max: 0

    readonly property bool available: max > 0
    readonly property int percent: max > 0 ? Math.round(raw * 100 / max) : 0

    function set(value) {
        const v = Math.max(1, Math.min(100, Math.round(value)));
        // Optimistic, so the OSD reacts on the same frame as the input.
        root.raw = Math.round(v * root.max / 100);
        setProc.exec(["brightnessctl", "-q", "set", `${v}%`]);
    }

    Process {
        id: setProc
    }

    FileView {
        id: maxFile
        path: `${root.device}/max_brightness`
        preload: true
        onLoaded: root.max = parseInt(text().trim()) || 0
    }

    FileView {
        id: currentFile
        path: `${root.device}/brightness`
        preload: true
        onLoaded: root.raw = parseInt(text().trim()) || 0
    }

    // sysfs does not deliver inotify events, so it has to be re-read. A plain
    // file read is cheap enough to do several times a second, which is what
    // makes hardware brightness keys show up in the OSD immediately.
    Timer {
        running: true
        interval: 150
        repeat: true
        onTriggered: currentFile.reload()
    }
}
