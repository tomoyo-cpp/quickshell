import QtQuick
import Quickshell
import "root:/"

// Drives niri's own screenshot UI over IPC rather than a private
// grim/slurp/satty pipeline, so the button behaves exactly like the Print
// key. The three clicks mirror the three binds in config.kdl:
//
//   left   → Print        (screenshot UI: freeze, select, save or copy)
//   right  → Ctrl+Print   (focused screen)
//   middle → Alt+Print    (focused window)
Pill {
    id: root

    padding: 9

    onClicked: Quickshell.execDetached(["niri", "msg", "action", "screenshot"])

    onRightClicked: Quickshell.execDetached(["niri", "msg", "action", "screenshot-screen"])

    onMiddleClicked: Quickshell.execDetached(["niri", "msg", "action", "screenshot-window"])

    Glyph {
        text: "󰆞"
        color: Theme.icon
    }
}
