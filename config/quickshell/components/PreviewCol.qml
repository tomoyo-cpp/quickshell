import QtQuick
import "root:/"

// Starts the guided tour. The stop control lives in its own bottom-left
// overlay rather than here, because the tour closes this panel as it runs.
SettingsCol {
    id: col

    title: "Preview"
    group: ""
    showReset: false

    Caption {
        vcenter: false
        text: Preview.running ? "Running — stop from the bottom-left." : "A guided tour of the panels, tiling and workspaces."
        color: Theme.overlay0
        size: 10
        wrapMode: Text.WordWrap
        width: parent.width
    }

    Row {
        width: parent.width
        spacing: 5

        Choice {
            label: "Full tour"
            perRow: 2
            picked: Preview.running && Preview.mode === "full"
            onTriggered: Preview.toggle("full")
        }
        Choice {
            label: "Panels only"
            perRow: 2
            picked: Preview.running && Preview.mode === "panels"
            onTriggered: Preview.toggle("panels")
        }
    }

    // Recording is not optional here, so say so before the button is pressed
    // rather than leaving a file to be discovered later.
    Row {
        width: parent.width
        spacing: 6

        Glyph {
            vcenter: false
            text: "󰑊"
            size: 11
            color: Preview.running ? Theme.red : Theme.overlay0
        }

        Caption {
            vcenter: false
            width: parent.width - 17
            text: "Screen and audio are recorded to ~/Videos/ScreenRecordings"
            color: Theme.overlay0
            size: 10
            wrapMode: Text.WordWrap
        }
    }
}
