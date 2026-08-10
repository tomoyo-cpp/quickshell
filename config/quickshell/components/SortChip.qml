import QtQuick
import QtQuick.Shapes
import "root:/"

Rectangle {
    id: sc2

    property string label: ""
    property string key: ""

    readonly property bool picked: Procs.sortBy === sc2.key

    width: sc2Label.implicitWidth + 14
    height: 20
    radius: 7
    color: sc2.picked ? Theme.alpha(Theme.icon, 0.2) : sc2Mouse.containsMouse ? Theme.surface0 : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim
        }
    }

    Caption {
        id: sc2Label
        anchors.centerIn: parent
        text: sc2.label
        color: sc2.picked ? Theme.icon : Theme.overlay1
        size: 9
        font.bold: sc2.picked
    }

    MouseArea {
        id: sc2Mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Procs.sortBy = sc2.key
    }
}
