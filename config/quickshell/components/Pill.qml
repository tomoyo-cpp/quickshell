import QtQuick
import "root:/"

// A bar item. Flat by default — the bar itself provides the surface, so a pill
// only paints when hovered or active. Children are laid out in a centred row.
//
// Internals are attached through the explicit `children:` list so they bypass
// the default property, which is aliased to the inner row.
Rectangle {
    id: root

    default property alias pillContent: layout.data

    // Sits behind the row, clipped to the pill — for things like the media
    // widget's visualiser.
    property alias backgroundContent: bg.data

    // Exposed so background content can line itself up with a particular
    // child of the row rather than the whole pill.
    readonly property alias contentRow: layout

    property bool active: false
    property bool interactive: true
    property color accent: Theme.text
    property int innerSpacing: 6
    property int padding: Theme.pillPadding

    readonly property bool hovered: mouse.containsMouse

    signal clicked
    signal rightClicked
    signal middleClicked
    signal scrolled(int delta)

    implicitWidth: layout.implicitWidth + padding * 2
    implicitHeight: Theme.pillHeight
    radius: Theme.pillRadius

    color: active ? Theme.alpha(accent, 0.2) : (hovered && interactive ? Theme.pillBgHover : "transparent")

    border.width: active ? 1 : 0
    border.color: Theme.alpha(accent, 0.4)

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }

    children: [
        Item {
            id: bg
            anchors.fill: root
            clip: true
        },

        Row {
            id: layout
            anchors.centerIn: root
            spacing: root.innerSpacing
        },

        MouseArea {
            id: mouse
            anchors.fill: root
            hoverEnabled: true
            enabled: root.interactive
            cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onClicked: event => {
                if (event.button === Qt.RightButton)
                    root.rightClicked();
                else if (event.button === Qt.MiddleButton)
                    root.middleClicked();
                else
                    root.clicked();
            }

            onWheel: event => root.scrolled(event.angleDelta.y)
        }
    ]
}
