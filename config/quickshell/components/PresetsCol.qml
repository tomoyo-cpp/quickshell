import QtQuick
import "root:/"

// Named snapshots of the whole look.
SettingsCol {
    id: col

    title: "Presets"
    group: ""
    showReset: false

    function _save() {
        if (Presets.save(nameInput.text))
            nameInput.text = "";
    }

    // Name field plus save. Saving under an existing name overwrites it.
    Rectangle {
        width: parent.width
        height: 26
        radius: 13
        color: Theme.alpha(Theme.surface0, 0.6)
        border.width: nameInput.activeFocus ? 1 : 0
        border.color: Theme.icon

        TextInput {
            id: nameInput
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 44
            verticalAlignment: Text.AlignVCenter
            clip: true
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 11
            selectionColor: Theme.alpha(Theme.icon, 0.35)
            selectedTextColor: Theme.text

            onAccepted: col._save()

            Caption {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: nameInput.text.length === 0 && !nameInput.activeFocus
                text: "Preset name"
                color: Theme.overlay0
                size: 11
            }
        }

        ChipButton {
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            label: "Save"
            accent: Theme.green
            onTriggered: col._save()
        }
    }

    Caption {
        vcenter: false
        visible: Presets.presets.length === 0
        text: "Set up a look, then name and save it."
        color: Theme.overlay0
        size: 10
        wrapMode: Text.WordWrap
        width: parent.width
    }

    // Bounded and scrollable: an unbounded list grew the column, which grew
    // the page, which grew the panel every time a preset was added.
    Item {
        id: presetFrame

        readonly property int rowHeight: 26
        readonly property int rowSpacing: 2
        readonly property int visibleRows: 2

        // Exactly two rows and the gap between them — not a round number that
        // would leave a sliver of a third row showing.
        readonly property int maxHeight: presetFrame.visibleRows * presetFrame.rowHeight + (presetFrame.visibleRows - 1) * presetFrame.rowSpacing

        width: parent.width
        height: Math.min(presetList.contentHeight, presetFrame.maxHeight)
        visible: Presets.presets.length > 0

        ListView {
            id: presetList

            anchors.fill: parent
            // Gutter so the scrollbar never sits on the delete buttons.
            anchors.rightMargin: presetList.contentHeight > presetList.height ? 8 : 0
            clip: true
            spacing: presetFrame.rowSpacing
            boundsBehavior: Flickable.StopAtBounds
            model: Presets.presets

            delegate: Rectangle {
                id: row

                required property var modelData

                readonly property bool active: Presets.isActive(row.modelData.name)

                width: presetList.width - presetList.anchors.rightMargin
                height: presetFrame.rowHeight
                radius: height / 2
                color: row.active ? Theme.alpha(Theme.icon, 0.18) : rowMouse.containsMouse ? Theme.surface0 : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.anim
                    }
                }

                // Declared before the delete button so it never paints over it.
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    anchors.rightMargin: 26
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Presets.apply(row.modelData.name)
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // The accent the preset carries, so its look is readable
                    // without applying it.
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.accentFor(row.modelData.values.accent ?? "text")
                    }

                    Caption {
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        color: row.active ? Theme.icon : Theme.subtext0
                        size: 11
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 10
                    color: delMouse.containsMouse ? Theme.alpha(Theme.red, 0.3) : "transparent"

                    Glyph {
                        // vcenter off: Glyph anchors verticalCenter by
                        // default, which conflicts with centerIn.
                        vcenter: false
                        anchors.centerIn: parent
                        text: "󰩺"
                        size: 10
                        color: delMouse.containsMouse ? Theme.red : Theme.overlay0
                    }

                    MouseArea {
                        id: delMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Presets.remove(row.modelData.name)
                    }
                }
            }
        }

        ScrollTrack {
            view: presetList
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }
    }
}
