import QtQuick
import "root:/"

Rectangle {
    id: cb

    property string label: ""
    property color accent: Theme.icon
    property bool highlighted: false

    signal triggered

    width: cbLabel.implicitWidth + 20
    height: 24
    radius: 12
    color: cb.highlighted ? Theme.alpha(cb.accent, 0.22) : cbMouse.containsMouse ? Theme.alpha(cb.accent, 0.25) : Theme.alpha(Theme.surface0, 0.6)

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }

    Caption {
        id: cbLabel
        anchors.centerIn: parent
        text: cb.label
        color: cb.accent
        size: 11
    }

    MouseArea {
        id: cbMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cb.triggered()
    }
}

