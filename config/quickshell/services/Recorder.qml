pragma Singleton

import QtQuick
import Quickshell
import "root:/"
import Quickshell.Io

// Screen recording, driven from the bar.
//
// Shares scripts/record.sh with the guided tour, so both go through the same
// VA-API path and the same graceful shutdown — the file is finalised on the
// way out rather than truncated.
Singleton {
    id: root

    readonly property bool running: proc.running

    // Seconds since the recording started, for the widget's readout.
    property int elapsed: 0

    readonly property string elapsedText: {
        const m = Math.floor(root.elapsed / 60);
        const s = root.elapsed % 60;
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }

    // The tour records through the same script; two recorders would fight over
    // the encoder and write two files at once.
    readonly property bool blocked: Preview.running

    function start() {
        if (proc.running || root.blocked)
            return;

        root.elapsed = 0;
        proc.command = [`${Quickshell.shellDir}/scripts/record.sh`];
        proc.running = true;
    }

    function stop() {
        if (!proc.running)
            return;
        // 15 = SIGTERM, which record.sh traps: it finalises the container
        // before exiting, where a kill would leave an unplayable file. Not
        // SIGINT — bash ignores that in backgrounded children.
        proc.signal(15);
    }

    function toggle() {
        if (proc.running)
            root.stop();
        else
            root.start();
    }

    Process {
        id: proc

        onExited: root.elapsed = 0
    }

    Timer {
        running: root.running
        interval: 1000
        repeat: true
        onTriggered: root.elapsed++
    }
}
