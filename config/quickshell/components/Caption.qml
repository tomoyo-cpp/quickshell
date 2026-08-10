import QtQuick
import "root:/"

// Body text.
//
// Centres itself vertically, which is what you want inside a bar Row. Set
// `vcenter: false` when placing one directly in a Column — vertical anchors
// break Column layout.
Text {
    property real size: Theme.fontSize
    property bool vcenter: true

    font.family: Theme.font
    font.pixelSize: size
    color: Theme.text
    elide: Text.ElideRight
    anchors.verticalCenter: vcenter && parent ? parent.verticalCenter : undefined

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }
}
