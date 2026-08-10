import QtQuick
import "root:/"

Item {
    id: ir

    property string glyph: ""
    property string label: ""
    property string value: ""
    property color accent: Theme.overlay1

    width: parent.width
    height: 20

    Text {
        id: irIcon
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        text: ir.glyph
        font.family: Theme.iconFont
        font.pixelSize: 12
        color: ir.accent
    }

    Caption {
        anchors.left: irIcon.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: ir.label
        color: Theme.overlay1
        size: 11
    }

    Caption {
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        text: ir.value
        color: Theme.subtext0
        size: 11
    }
}
