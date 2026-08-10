import QtQuick
import "root:/"

// Nerd Font icon.
//
// Centres itself vertically, which is what you want inside a bar Row. Set
// `vcenter: false` when placing one directly in a Column — vertical anchors
// break Column layout.
Text {
    property real size: Theme.iconSize
    property bool vcenter: true

    font.family: Theme.iconFont
    font.pixelSize: size
    color: Theme.icon
    anchors.verticalCenter: vcenter && parent ? parent.verticalCenter : undefined

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }
}
