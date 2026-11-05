import QtQuick
import "root:/"

// A floating bar island. Each container sizes to its own contents, so a widget
// growing inside one pushes only that container's edge — the others keep their
// position and nothing overlaps.
Rectangle {
    id: root

    default property alias containerContent: layout.data
    // The row itself, for the bar to reorder its widgets.
    readonly property alias row: layout

    property int innerSpacing: 2
    property int padding: 6

    implicitWidth: layout.implicitWidth + padding * 2
    // Nothing in it, nothing drawn — no empty capsule on the bar. (Counts
    // children, not visibleChildren: those are invisible while the container
    // is, so it would never show again.)
    visible: layout.children.length > 0
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
