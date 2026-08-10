import QtQuick
import "root:/"

// Opens the dashboard's clipboard history.
Pill {
    id: root

    required property var bar

    active: bar.openPopup === "clipboard"
    accent: Theme.icon
    padding: 9

    onClicked: bar.togglePopup("clipboard")

    Glyph {
        text: "󰅍"
    }
}
