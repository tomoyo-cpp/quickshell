pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// Ten-band equalizer driving the PipeWire filter chain declared in
// configuration.nix. Gains are dB, -12..+12.
Singleton {
    id: root

    readonly property var frequencies: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    readonly property real range: 12

    property var gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property string preset: "Flat"

    readonly property var presets: ({
        "Flat": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        "Bass": [8, 7, 5, 2, 0, 0, 0, 0, 0, 0],
        "Treble": [0, 0, 0, 0, 0, 1, 3, 5, 7, 8],
        "Vocal": [-3, -2, 0, 2, 4, 5, 4, 2, 0, -1],
        "Pop": [-1, 1, 3, 5, 4, 2, 0, -1, -1, 0],
        "Rock": [5, 4, 2, -1, -2, 0, 3, 5, 6, 6],
        "Jazz": [4, 3, 1, 2, -1, -1, 0, 2, 3, 4],
        "Classic": [5, 4, 3, 2, -1, -1, 0, 2, 3, 4]
    })

    // True once the live curve no longer matches the named preset.
    readonly property bool custom: {
        const p = root.presets[root.preset];
        if (!p)
            return true;
        for (let i = 0; i < 10; ++i)
            if (Math.abs(p[i] - root.gains[i]) > 0.01)
                return true;
        return false;
    }

    function setBand(index, value) {
        const next = root.gains.slice();
        next[index] = Math.max(-root.range, Math.min(root.range, value));
        root.gains = next;
        apply();
        saveDebounce.restart();
    }

    function applyPreset(name) {
        const p = root.presets[name];
        if (!p)
            return;
        root.preset = name;
        root.gains = p.slice();
        apply();
        saveDebounce.restart();
    }

    function apply() {
        setProc.exec([`${Quickshell.shellDir}/scripts/set-eq.sh`].concat(root.gains.map(g => String(g))));
    }

    function _save() {
        file.setText(JSON.stringify({
            gains: root.gains,
            preset: root.preset
        }, null, 2));
    }

    Process {
        id: setProc

        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "")
                console.warn("set-eq:", text.trim())
        }
    }

    // Dragging a slider fires continuously; only the settled curve is written.
    Timer {
        id: saveDebounce
        interval: 400
        onTriggered: root._save()
    }

    FileView {
        id: file
        path: `${Quickshell.stateDir}/equalizer.json`
        preload: true
        atomicWrites: true
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data && data.gains && data.gains.length === 10) {
                    root.gains = data.gains;
                    root.preset = data.preset ?? "Flat";
                }
            } catch (e) {}
            // Push the restored curve into the filter chain.
            root.apply();
        }

        onLoadFailed: root.apply()
    }
}
