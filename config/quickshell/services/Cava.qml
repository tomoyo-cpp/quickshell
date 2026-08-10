pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// Real FFT band data from cava.
//
// One process serves every visualiser: cava emits more bands than any of them
// draws (see cava.conf) and each consumer resamples that down to its own bar
// count. Consumers call acquire()/release() so the process only runs while
// something is actually on screen — an idle cava is a constant 60fps wakeup.
Singleton {
    id: root

    // Normalised 0..1, one entry per band, newest frame.
    property var values: []
    readonly property int bands: Settings.cavaBands

    // How many visualisers currently want data.
    property int subscribers: 0

    readonly property bool active: root.subscribers > 0

    function acquire() {
        root.subscribers += 1;
    }

    function release() {
        root.subscribers = Math.max(0, root.subscribers - 1);
    }

    // Resample the band array down to `n` bars, averaging each slice so a
    // narrow visualiser still reflects the whole spectrum rather than a crop
    // of the low end.
    function resample(n) {
        const src = root.values;
        if (!src || src.length === 0 || n <= 0)
            return [];

        const out = [];
        const step = src.length / n;
        for (let i = 0; i < n; ++i) {
            const from = Math.floor(i * step);
            const to = Math.max(from + 1, Math.floor((i + 1) * step));
            let sum = 0;
            for (let j = from; j < to && j < src.length; ++j)
                sum += src[j];
            out.push(sum / (to - from));
        }
        return out;
    }

    // The config is generated rather than shipped, so band count, framerate
    // and smoothing are settable at runtime. cava reads it once at startup,
    // so a change has to bounce the process — hence the revision below.
    readonly property string confPath: `${Quickshell.stateDir}/cava.conf`

    readonly property string conf: `[general]
bars = ${Settings.cavaBands}
framerate = ${Settings.cavaFramerate}
autosens = 1
lower_cutoff_freq = 40
higher_cutoff_freq = 16000

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 255
bar_delimiter = 59
frame_delimiter = 10

[smoothing]
noise_reduction = ${Settings.cavaSmoothing}
`

    Component.onCompleted: confFile.setText(root.conf)

    FileView {
        id: confFile
        path: root.confPath
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: cavaProc
        // Restarted on a settings change: cava only reads its config once.
        running: root.active && root.confReady
        command: ["cava", "-p", root.confPath]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: line => {
                if (line === "")
                    return;
                const parts = line.split(";");
                const out = [];
                for (const p of parts) {
                    if (p === "")
                        continue;
                    // ascii_max_range in cava.conf.
                    out.push(Math.min(1, (parseInt(p) || 0) / 255));
                }
                if (out.length > 0)
                    root.values = out;
            }
        }
    }

    // Held low for a beat after a config change so the Process sees `running`
    // go false and back, which is what actually restarts cava.
    property bool confReady: true

    Timer {
        id: bounce
        interval: 120
        onTriggered: root.confReady = true
    }

    onConfChanged: {
        confFile.setText(root.conf);
        root.confReady = false;
        bounce.restart();
    }

    // Nothing is driving the bars once cava stops, so clear them rather than
    // leaving the last frame frozen on screen.
    onActiveChanged: if (!root.active)
        root.values = []
}
