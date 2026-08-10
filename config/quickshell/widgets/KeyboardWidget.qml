import QtQuick
import "root:/"

// Icon-only, like the other buttons. Click or scroll cycles the xkb layout.
Pill {
    id: root

    visible: Niri.layoutNames.length > 1
    padding: 9

    onClicked: Niri.nextLayout()
    onScrolled: Niri.nextLayout()

    Glyph {
        text: "󰌌"
    }
}
