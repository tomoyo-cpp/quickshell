import QtQuick
import QtQuick.Shapes
import "root:/"

Rectangle {
    id: ch

    property string label: ""
    property bool picked: false

    // How many of these share a row, so they divide the width evenly. Two by
    // default, which is what every existing caller expects.
    property int perRow: 2
    property int gap: 5

    signal triggered

    width: (parent.width - (ch.perRow - 1) * ch.gap) / ch.perRow
    height: 26
    radius: 9
    color: ch.picked ? Theme.alpha(Theme.icon, 0.18) : chMouse.containsMouse ? Theme.surface0 : Theme.alpha(Theme.surface0, 0.5)

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }

    Caption {
        anchors.centerIn: parent
        text: ch.label
        color: ch.picked ? Theme.icon : Theme.subtext0
        size: 11
        font.bold: ch.picked
    }

    MouseArea {
        id: chMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ch.triggered()
    }
}
