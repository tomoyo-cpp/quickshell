import QtQuick
import "root:/"

Column {
    id: sr

    property string label: ""
    property string readout: ""
    property real value: 0
    property bool dimmed: false

    signal moved(real value)
    signal labelClicked

    width: parent.width
    spacing: 5

    Item {
        width: parent.width
        height: 16

        Caption {
            anchors.left: parent.left
            text: sr.label
            color: sr.dimmed ? Theme.overlay0 : Theme.subtext0
            size: 11

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sr.labelClicked()
            }
        }

        Caption {
            anchors.right: parent.right
            text: sr.readout
            color: Theme.subtext0
            size: 11
        }
    }

    LevelSlider {
        width: parent.width
        accent: sr.dimmed ? Theme.overlay0 : Theme.icon
        value: sr.value
        onMoved: v => sr.moved(v)
    }
}

