import QtQuick
import QtQuick.Effects
import "root:/"

DashPage {
    id: wallpaperPage
    onShown: Wallpapers.refresh()

    // Header plus however many thumbnail rows there are, so an
    // empty bottom half collapses instead of being padding.
    readonly property int rows: Math.max(1, Math.ceil(Wallpapers.files.length / 3))
    readonly property int cell: Math.round(Math.floor(width / 3) * 0.62)
    contentHeight: 22 + 10 + rows * cell

    Column {
        anchors.fill: parent
        spacing: 10

        Item {
            width: parent.width
            height: 22

            Caption {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Wallpapers.files.length > 0 ? `${Wallpapers.files.length} wallpapers` : "No images in ~/Pictures/Wallpapers"
                color: Theme.subtext0
                size: 12
            }

            ChipButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                label: "Rescan"
                onTriggered: Wallpapers.refresh()
            }
        }

        GridView {
            id: wallGrid

            width: parent.width
            height: parent.height - y
            clip: true
            cellWidth: Math.floor(width / 3)
            cellHeight: Math.round(cellWidth * 0.62)
            model: Wallpapers.files
            boundsBehavior: Flickable.StopAtBounds

            // Shown only when the grid overflows, so it also
            // signals that there is more below.
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 1
                width: 3
                radius: 1.5
                color: Theme.alpha(Theme.icon, 0.4)

                visible: wallGrid.contentHeight > wallGrid.height
                height: Math.max(24, wallGrid.height * (wallGrid.height / Math.max(1, wallGrid.contentHeight)))
                y: wallGrid.contentHeight > wallGrid.height ? Math.max(0, Math.min(wallGrid.height - height, (wallGrid.contentY / (wallGrid.contentHeight - wallGrid.height)) * (wallGrid.height - height))) : 0
            }

            delegate: Item {
                id: wp
                required property var modelData

                readonly property bool selected: Wallpapers.current === wp.modelData.path

                width: GridView.view.cellWidth
                height: GridView.view.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 10
                    color: Theme.alpha(Theme.surface0, 0.6)
                    border.width: wp.selected ? 2 : (wpMouse.containsMouse ? 1 : 0)
                    border.color: wp.selected ? Theme.icon : Theme.overlay1

                    // Rectangle clipping is rectangular, so the
                    // thumbnail is masked to the same radius
                    // instead — otherwise its square corners
                    // poke out of the rounded frame.
                    Item {
                        id: thumbMask
                        anchors.fill: parent
                        anchors.margins: wp.selected ? 2 : 0
                        visible: false
                        layer.enabled: true

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: "black"
                        }
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: wp.selected ? 2 : 0
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: thumbMask
                        }

                        Image {
                            anchors.fill: parent
                            source: `file://${wp.modelData.thumb}`
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 400
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            height: 20
                            color: Theme.alpha(Theme.crust, 0.75)
                            visible: wpMouse.containsMouse || wp.selected

                            Caption {
                                anchors.centerIn: parent
                                width: parent.width - 12
                                horizontalAlignment: Text.AlignHCenter
                                text: wp.modelData.name
                                color: Theme.icon
                                size: 10
                            }
                        }
                    }

                    MouseArea {
                        id: wpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.apply(wp.modelData.path)
                    }
                }
            }
        }
    }
}
