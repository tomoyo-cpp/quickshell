pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// Per-process CPU, memory and I/O, sampled by scripts/proclist.py.
//
// Only runs while something is watching: walking /proc every few seconds is
// cheap but not free, and nothing needs it when the page is closed.
Singleton {
    id: root

    // [{ pid, name, cpu, mem, rss, io }], busiest first.
    property var list: []

    // Set by whatever wants process data. Sampling continues briefly after it
    // clears, so reopening the page shows the last rows immediately instead of
    // an empty list — walking /proc for a few more seconds is cheaper than
    // making every visit wait.
    property bool watching: false

    readonly property bool sampling: root.watching || grace.running

    Timer {
        id: grace
        interval: 30000
    }

    // "cpu" | "mem" | "io"
    property string sortBy: "cpu"

    readonly property var sorted: {
        const l = root.list.slice();
        if (root.sortBy === "mem")
            l.sort((a, b) => b.rss - a.rss);
        else if (root.sortBy === "io")
            l.sort((a, b) => b.io - a.io);
        else
            l.sort((a, b) => b.cpu - a.cpu);
        return l;
    }

    function kill(pid) {
        killProc.exec(["kill", String(pid)]);
    }

    Process {
        id: killProc
    }

    Process {
        running: root.sampling
        command: ["python3", `${Quickshell.shellDir}/scripts/proclist.py`]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: line => {
                if (line === "")
                    return;
                try {
                    root.list = JSON.parse(line);
                } catch (e) {
                    // A partial line during shutdown is not worth logging.
                }
            }
        }
    }

    onWatchingChanged: {
        if (root.watching)
            grace.stop();
        else
            grace.restart();
    }

    // Only cleared once sampling has actually stopped, so the rows survive the
    // grace window and are there on the next visit.
    onSamplingChanged: if (!root.sampling)
        root.list = []
}
