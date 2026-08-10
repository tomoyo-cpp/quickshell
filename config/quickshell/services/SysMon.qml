pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// CPU and memory load, sampled by scripts/sysmon.sh.
Singleton {
    id: root

    property int cpu: 0
    property int memory: 0
    property int disk: 0
    property int temperature: 0
    property int uptimeSeconds: 0
    property int rxRate: 0        // bytes/s
    property int txRate: 0        // bytes/s

    property real load1: 0
    property int processes: 0
    property int threads: 0
    property int swap: 0          // percent used
    property int cpuMhz: 0
    property int memAvailKb: 0
    property int memTotalKb: 0
    property int diskFreeKb: 0

    // Rolling history for the sparklines, oldest first.
    readonly property int historyLength: 32
    property var cpuHistory: []
    property var memoryHistory: []
    property var diskHistory: []
    property var rxHistory: []
    property var txHistory: []

    // Network rates have no natural ceiling, so they are scaled against the
    // busiest sample in the window. A small floor keeps an idle link flat
    // rather than amplifying noise into a full-scale graph.
    // Highest rate seen this session, so the rings keep a stable reference
    // instead of rescaling every time the window's busiest sample ages out.
    // The 8 KB/s floor stops an idle link amplifying noise to full scale.
    property real netPeak: 8192

    readonly property real netScale: root.netPeak

    readonly property var rxPercentHistory: root.rxHistory.map(v => v / root.netScale * 100)
    readonly property var txPercentHistory: root.txHistory.map(v => v / root.netScale * 100)

    function _push(list, value) {
        const next = list.concat([value]);
        return next.length > root.historyLength ? next.slice(next.length - root.historyLength) : next;
    }

    readonly property string uptimeText: {
        const s = root.uptimeSeconds;
        if (s <= 0)
            return "—";
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0)
            return `${d}d ${h}h`;
        if (h > 0)
            return `${h}h ${m}m`;
        return `${m}m`;
    }

    function formatSize(kb) {
        if (kb >= 1048576)
            return `${(kb / 1048576).toFixed(1)} GB`;
        if (kb >= 1024)
            return `${Math.round(kb / 1024)} MB`;
        return `${kb} KB`;
    }

    function formatRate(bytes) {
        if (bytes >= 1048576)
            return `${(bytes / 1048576).toFixed(1)} MB/s`;
        if (bytes >= 1024)
            return `${Math.round(bytes / 1024)} KB/s`;
        return `${bytes} B/s`;
    }

    Process {
        id: monitor
        running: true
        command: [`${Quickshell.shellDir}/scripts/sysmon.sh`]

        stdout: SplitParser {
            // cpu mem disk temp uptime rx tx
            onRead: line => {
                const parts = line.trim().split(" ");
                // Grew from 7 to 15 fields; older shorter samples are ignored
                // rather than half-applied.
                if (parts.length < 15)
                    return;
                root.cpu = parseInt(parts[0]) || 0;
                root.memory = parseInt(parts[1]) || 0;
                root.disk = parseInt(parts[2]) || 0;
                root.temperature = parseInt(parts[3]) || 0;
                root.uptimeSeconds = parseInt(parts[4]) || 0;
                root.rxRate = parseInt(parts[5]) || 0;
                root.txRate = parseInt(parts[6]) || 0;
                root.load1 = parseFloat(parts[7]) || 0;
                root.processes = parseInt(parts[8]) || 0;
                root.swap = parseInt(parts[9]) || 0;
                root.cpuMhz = parseInt(parts[10]) || 0;
                root.memAvailKb = parseInt(parts[11]) || 0;
                root.memTotalKb = parseInt(parts[12]) || 0;
                root.diskFreeKb = parseInt(parts[13]) || 0;
                root.threads = parseInt(parts[14]) || 0;

                root.cpuHistory = root._push(root.cpuHistory, root.cpu);
                root.memoryHistory = root._push(root.memoryHistory, root.memory);
                root.diskHistory = root._push(root.diskHistory, root.disk);
                root.rxHistory = root._push(root.rxHistory, root.rxRate);
                root.txHistory = root._push(root.txHistory, root.txRate);
                root.netPeak = Math.max(root.netPeak, root.rxRate, root.txRate);
            }
        }

        onRunningChanged: if (!running)
            respawn.start()
    }

    Timer {
        id: respawn
        interval: 2000
        onTriggered: monitor.running = true
    }
}
