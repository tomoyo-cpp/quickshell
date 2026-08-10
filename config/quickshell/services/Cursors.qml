pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// The cursor themes offered in the Appearance tab.
//
// The list and its preview images come from scripts/cursor-themes.sh, which
// curates the ~200 directories the installed packages provide down to a
// gridful and renders one PNG each with xcur2png. Previews are cached, so
// this is cheap after the first run.
//
// Applying is split in two, because the two halves have different owners:
// niri's own pointer is a `cursor` block in config.kdl, written by
// NiriTheme.qml so that file keeps a single writer; everything else — the
// Xcursor fallback, GTK, dconf — is scripts/set-cursor.sh.
Singleton {
    id: root

    property var themes: []
    readonly property bool ready: root.themes.length > 0

    readonly property string current: Settings.cursorTheme

    function refresh() {
        if (!scan.running)
            scan.running = true;
    }

    function apply(name) {
        if (!name)
            return;
        // Settings first: NiriTheme watches it and rewrites config.kdl, which
        // is what moves the compositor's own pointer.
        Settings.set("cursorTheme", name);
        setter.command = [`${Quickshell.shellDir}/scripts/set-cursor.sh`, name, String(Settings.cursorSize)];
        setter.running = true;
    }

    // Re-runs the client half when only the size changes; the theme is
    // unchanged so NiriTheme picks the size up on its own.
    Connections {
        target: Settings
        function onCursorSizeChanged() {
            if (Settings.cursorTheme)
                root.apply(Settings.cursorTheme);
        }
    }

    Process {
        id: scan
        command: ["sh", `${Quickshell.shellDir}/scripts/cursor-themes.sh`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.themes = JSON.parse(text);
                } catch (e) {
                    root.themes = [];
                }
            }
        }
    }

    Process {
        id: setter
    }

    Component.onCompleted: root.refresh()
}
