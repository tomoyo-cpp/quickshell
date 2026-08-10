pragma Singleton

import QtQuick
import Quickshell
import "root:/"
import Quickshell.Io

// Runs the guided tour in scripts/preview.sh and exposes a clean way to stop
// it.
//
// Stopping sends SIGINT rather than killing the process: the script traps it
// and runs its own cleanup, closing the windows it opened and restoring the
// workspace. A hard kill would leave those behind.
Singleton {
    id: root

    readonly property bool running: proc.running

    // "full" | "panels" | "windows"
    property string mode: "full"

    // Every run is recorded — record.sh starts the capture, runs the tour, and
    // finalises the file when the tour ends or is stopped.
    function start(mode) {
        if (proc.running)
            return;

        root.mode = mode ?? "full";
        proc.command = [`${Quickshell.shellDir}/scripts/record.sh`, "--preview", root.mode];
        proc.running = true;
    }

    function stop() {
        if (!proc.running)
            return;
        // 15 = SIGTERM. record.sh traps it, stops the tour so its cleanup is
        // captured, then finalises the container — a hard kill would leave an
        // unplayable file. TERM rather than INT because bash ignores INT in
        // backgrounded children and cannot re-trap it.
        proc.signal(15);
        // If the trap somehow does not fire, make sure the tour's windows do
        // not outlive it.
        failsafe.restart();
    }

    function toggle(mode) {
        if (proc.running)
            root.stop();
        else
            root.start(mode);
    }

    Process {
        id: proc

        // The tour spawns its terminals into their own systemd scopes, so they
        // survive this process ending either way.
        onExited: failsafe.stop()
    }

    Timer {
        id: failsafe
        interval: 4000
        onTriggered: {
            if (proc.running)
                proc.signal(9);
            sweeper.running = true;
        }
    }

    // Same cleanup the script does, for the case where it never got to run it.
    Process {
        id: sweeper
        command: ["sh", "-c", `${Quickshell.shellDir}/scripts/preview.sh --clean`]
    }
}
