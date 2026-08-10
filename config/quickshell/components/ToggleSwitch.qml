import QtQuick
import "root:/"

Item {
    id: sw

    property string label: ""
    property bool checked: false

    signal toggled

    width: parent.width
    height: 24

    Caption {
        anchors.left: parent.left
        anchors.right: knob.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: sw.label
        color: sw.checked ? Theme.subtext0 : Theme.overlay0
        size: 11
    }

    Rectangle {
        id: knob
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 17
        radius: 8.5
        color: sw.checked ? Theme.icon : Theme.surface1

        Behavior on color {
            ColorAnimation {
                duration: Theme.anim
            }
        }

        Rectangle {
            x: sw.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 11
            height: 11
            radius: 5.5
            color: sw.checked ? Theme.crust : Theme.overlay2

            Behavior on x {
                NumberAnimation {
                    duration: Theme.anim
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}

