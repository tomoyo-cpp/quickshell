import QtQuick
import "root:/"

Rectangle {
    id: mc

    property string label: ""
    property bool on: false

    signal toggled

    width: mcLabel.implicitWidth + 20
    height: 26
    radius: 9
    color: mc.on ? Theme.alpha(Theme.icon, 0.22) : mcMouse.containsMouse ? Theme.surface0 : Theme.alpha(Theme.surface0, 0.5)

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }

    Caption {
        id: mcLabel
        anchors.centerIn: parent
        text: mc.label
        color: mc.on ? Theme.icon : Theme.subtext0
        size: 10
        font.bold: mc.on
    }

    MouseArea {
        id: mcMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mc.toggled()
    }
}
