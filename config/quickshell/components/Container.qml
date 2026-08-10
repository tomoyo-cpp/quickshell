import QtQuick
import "root:/"

// A floating bar island. Each container sizes to its own contents, so a widget
// growing inside one pushes only that container's edge — the others keep their
// position and nothing overlaps.
Rectangle {
    id: root

    default property alias containerContent: layout.data

    property int innerSpacing: 2
    property int padding: 6

    implicitWidth: layout.implicitWidth + padding * 2
    implicitHeight: Theme.containerHeight
    radius: Theme.containerRadius
    color: Theme.containerBg

    children: [
        Row {
            id: layout
            anchors.centerIn: root
            spacing: root.innerSpacing
        }
    ]
}
