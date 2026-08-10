pragma Singleton

import Quickshell
import Quickshell.Io
import "root:/"

// Blue-light filter via wlsunset. Running it with identical sunrise/sunset
// times (-S/-s) pins it to the night temperature permanently, which is what a
// manual on/off toggle wants — no geo-clock involved.
Singleton {
    id: root

    property int temperature: Settings.nightTemp

    readonly property bool active: sunset.running

    function toggle() {
        if (root.active)
            sunset.running = false;
        else
            sunset.running = true;
    }

    Process {
        id: sunset
        running: false
        command: ["wlsunset", "-S", "00:00", "-s", "23:59", "-t", String(root.temperature), "-T", String(root.temperature + 1)]
    }
}
