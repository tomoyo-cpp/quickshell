import QtQuick
import "root:/"

// The bar's two widget clusters as lists: order with the arrows, move to the
// other side of the workspaces, or take out. Taken-out widgets wait under
// Hidden until added back to either side. Writes Settings.barLeft/barRight.
Column {
    id: root

    width: parent ? parent.width : 200
    spacing: 4

    component IconButton: Text {
        id: ib
        property bool enabled_: true
        signal clicked

        font.family: Theme.iconFont
        font.pixelSize: 14
        color: !ib.enabled_ ? Theme.surface2 : ibMouse.containsMouse ? Theme.icon : Theme.overlay1
        width: 20
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter

        MouseArea {
            id: ibMouse
            anchors.fill: parent
            anchors.margins: -3
            hoverEnabled: true
            enabled: ib.enabled_
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
        }
    }

    component Section: Caption {
        vcenter: false
        color: Theme.subtext0
        size: 11
        topPadding: 4
    }

    component Entry: Rectangle {
        id: entry
        required property string key
        required property int index
        required property int count

        width: root.width
        height: 26
        radius: 7
        color: entryMouse.containsMouse ? Theme.alpha(Theme.surface0, 0.6) : "transparent"

        MouseArea {
            id: entryMouse
            anchors.fill: parent
            hoverEnabled: true
        }

        Caption {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: entryButtons.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: Settings.barWidgetNames[entry.key] ?? entry.key
            elide: Text.ElideRight
            size: 12
        }

        Row {
            id: entryButtons
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height

            IconButton {
                text: "󰁝"
                enabled_: entry.index > 0
                onClicked: Settings.barMove(entry.key, -1)
            }
            IconButton {
                text: "󰁅"
                enabled_: entry.index < entry.count - 1
                onClicked: Settings.barMove(entry.key, 1)
            }
            IconButton {
                text: "󰓡"
                onClicked: Settings.barSwapSide(entry.key)
            }
            IconButton {
                text: "󰅖"
                onClicked: Settings.barHide(entry.key)
            }
        }
    }

    Section {
        text: "Left of workspaces"
    }
    Repeater {
        model: Settings.barLeft
        delegate: Entry {
            required property string modelData
            key: modelData
            count: Settings.barLeft.length
        }
    }

    Section {
        text: "Right of workspaces"
    }
    Repeater {
        model: Settings.barRight
        delegate: Entry {
            required property string modelData
            key: modelData
            count: Settings.barRight.length
        }
    }

    Section {
        visible: Settings.barHidden.length > 0
        text: "Hidden — 󰁍 adds left, 󰁔 right"
    }
    Repeater {
        model: Settings.barHidden
        delegate: Item {
            id: hidden
            required property string modelData
            width: root.width
            height: 26

            Caption {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: hiddenButtons.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: Settings.barWidgetNames[hidden.modelData] ?? hidden.modelData
                elide: Text.ElideRight
                color: Theme.overlay1
                size: 12
            }
            // Back onto the bar, left or right of the workspaces — the same
            // icon buttons as the rows above, so it fits the narrow column.
            Row {
                id: hiddenButtons
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                IconButton {
                    text: "󰁍"
                    onClicked: Settings.barShow(hidden.modelData, "barLeft")
                }
                IconButton {
                    text: "󰁔"
                    onClicked: Settings.barShow(hidden.modelData, "barRight")
                }
            }
        }
    }
}
