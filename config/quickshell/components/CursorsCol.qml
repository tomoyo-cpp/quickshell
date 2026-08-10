import QtQuick
import "root:/"

// Pointer theme picker.
//
// The tiles are deliberately small. A cursor is a 24px object in use, and a
// grid of blown-up arrows tells you less about how it will actually look than
// one drawn near its real size does.
SettingsCol {
    id: col

    title: "Cursor"
    group: "cursor"

    readonly property int tile: 54
    readonly property int art: 26

    Caption {
        vcenter: false
        visible: !Cursors.ready
        text: "No cursor themes found."
        color: Theme.overlay0
        size: 10
        wrapMode: Text.WordWrap
        width: parent.width
    }

    // Bounded and scrollable, for the same reason the presets list is: an
    // unbounded grid grows the column, which grows the page, which grows the
    // panel. Three rows visible, the rest scrolls.
    Item {
        id: frame

        readonly property int cols: Math.max(3, Math.floor((col.width + grid.spacing) / (col.tile + grid.spacing)))
        readonly property int rows: 3
        readonly property int maxHeight: frame.rows * col.tile + (frame.rows - 1) * grid.spacing

        width: parent.width
        height: Math.min(flick.contentHeight, frame.maxHeight)
        visible: Cursors.ready

        Flickable {
            id: flick

            anchors.fill: parent
            anchors.rightMargin: flick.contentHeight > flick.height ? 8 : 0
            contentHeight: grid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Grid {
                id: grid

                width: flick.width
                columns: frame.cols
                spacing: 6

                Repeater {
                    model: Cursors.themes

                    Rectangle {
                        id: tile

                        required property var modelData

                        readonly property bool picked: Settings.cursorTheme === tile.modelData.name

                        width: col.tile
                        height: col.tile
                        radius: 8
                        color: tile.picked ? Theme.alpha(Theme.icon, 0.18) : tileMouse.containsMouse ? Theme.alpha(Theme.surface0, 0.7) : Theme.alpha(Theme.surface0, 0.35)
                        border.width: tile.picked ? 1 : 0
                        border.color: Theme.alpha(Theme.icon, 0.55)

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.anim
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: col.art
                                height: col.art
                                // Rendered at 48px and drawn at 26, so it stays
                                // sharp on a scaled display rather than being
                                // upscaled from the size it is shown at.
                                sourceSize.width: col.art * 2
                                sourceSize.height: col.art * 2
                                fillMode: Image.PreserveAspectFit
                                source: tile.modelData.preview ? `file://${tile.modelData.preview}` : ""
                                visible: tile.modelData.preview !== ""
                            }

                            Caption {
                                vcenter: false
                                width: col.tile - 6
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: tile.modelData.label
                                color: tile.picked ? Theme.icon : Theme.overlay1
                                size: 8
                            }
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Cursors.apply(tile.modelData.name)
                        }
                    }
                }
            }
        }
    }

    Setting {
        label: "Cursor size"
        value: Settings.cursorSize
        from: 16
        to: 48
        onMoved: v => Settings.set("cursorSize", v)
    }

    // Says so rather than looking broken: a theme change reaches the
    // compositor and most toolkits at once, but anything that reads the cursor
    // once at startup keeps the old pointer until it restarts.
    Caption {
        vcenter: false
        visible: Cursors.ready
        width: parent.width
        text: "Some apps keep the old pointer until restarted."
        color: Theme.overlay0
        size: 9
        wrapMode: Text.WordWrap
    }
}
