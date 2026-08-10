import QtQuick
import "root:/"

// A labelled bar, for the process rows.
Item {
    id: mb

    property color accent: Theme.icon
    property real fraction: 0
    property string text: ""

    width: 100
    height: 8

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 4
        radius: 2
        color: Theme.alpha(Theme.surface2, 0.6)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, mb.fraction))
            height: parent.height
            radius: 2
            color: mb.accent

            Behavior on width {
                NumberAnimation {
                    duration: Theme.dur(260)
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Caption {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        width: 50
        text: mb.text
        color: Theme.overlay1
        size: 9
        elide: Text.ElideLeft
    }
}
