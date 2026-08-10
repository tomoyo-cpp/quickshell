pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// Wallpapers available in ~/Pictures/Wallpapers, and the one in use.
Singleton {
    id: root

    readonly property string directory: `${Quickshell.env("HOME")}/Pictures/Wallpapers`

    // [{ path, thumb, name }, ...] sorted by name.
    property var files: []
    property string current: ""

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
        currentProc.running = true;
    }

    function apply(path) {
        // Optimistic, so the selection highlights immediately.
        root.current = path;
        setProc.exec([`${Quickshell.shellDir}/scripts/set-wallpaper.sh`, path]);
    }

    Process {
        id: setProc

        // The script failing quietly is hard to spot, so surface anything it
        // writes to stderr and confirm what actually got applied.
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "")
                console.warn("set-wallpaper:", text.trim())
        }

        onExited: (code, status) => {
            if (code !== 0)
                console.warn("set-wallpaper exited", code);
            // Re-read the persisted choice so `current` reflects reality
            // rather than the optimistic guess.
            currentProc.running = true;
        }
    }

    Process {
        id: listProc
        running: true
        command: [`${Quickshell.shellDir}/scripts/wallpaper-thumbs.sh`]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const path = line.slice(0, tab);
                    out.push({
                        path: path,
                        thumb: line.slice(tab + 1),
                        name: path.split("/").pop()
                    });
                }
                root.files = out;
            }
        }
    }

    // The active wallpaper is whatever start-awww.sh is pinned to.
    Process {
        id: currentProc
        running: true
        command: ["sh", "-c", `sed -n 's/^WALLPAPER="\\(.*\\)"/\\1/p' "${Quickshell.env("HOME")}/.config/niri/start-awww.sh" | head -1`]

        stdout: StdioCollector {
            onStreamFinished: root.current = text.trim()
        }
    }
}
