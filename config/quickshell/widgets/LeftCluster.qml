import QtQuick
import Quickshell.Services.Pipewire
import "root:/"

// The left end of the bar: launcher and overview buttons, the focused window,
// and small indicators for things that are already running.
Row {
    id: root

    required property var bar

    spacing: 2

    // A stream linked to the default source means something is listening.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSource]
    }

    PwNodeLinkTracker {
        id: micLinks
        node: Pipewire.defaultAudioSource
    }

    Pill {
        visible: Settings.showOverview
        padding: 9
        active: Niri.overviewOpen
        accent: Theme.icon
        onClicked: Niri.toggleOverview()

        Glyph {
            text: "󰕰"
        }
    }

    Pill {
        visible: Settings.showLauncher
        padding: 9
        accent: Theme.icon
        active: root.bar.openPopup === "launcher"
        onClicked: root.bar.togglePopup("launcher")

        Glyph {
            text: "󰍉"
        }
    }

    SettingsWidget {
        bar: root.bar
    }

    // ── Indicators ───────────────────────────────────────────────────────
    Pill {
        padding: 8
        visible: Niri.castCount > 0
        interactive: false

        Glyph {
            text: "󰑊"
            color: Theme.red
            size: 15
        }
    }

    Pill {
        padding: 8
        visible: micLinks.linkGroups.length > 0
        interactive: false

        Glyph {
            text: "󰍬"
            color: Theme.green
            size: 15
        }
    }

    // Exposed so the notification panel can line up beneath it.
    property alias bellItem: bell

    Pill {
        id: bell

        padding: 9
        accent: Theme.icon
        active: root.bar.openPopup === "notifications"

        onClicked: root.bar.togglePopup("notifications")

        Glyph {
            text: Notifs.dnd ? "󰂛" : Notifs.unread > 0 ? "󱅫" : "󰂚"
            color: Notifs.dnd ? Theme.overlay0 : Theme.icon
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifs.unread > 0 && !Notifs.dnd
            width: 7
            height: 7
            radius: 3.5
            color: Theme.red
        }
    }
}
