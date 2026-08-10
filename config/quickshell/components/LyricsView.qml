import QtQuick
import "root:/"

// A five-line window onto the lyrics, the current one centred.
//
// The whole column is translated so the current line sits in the middle slot,
// and the offset is animated — so the lines glide up together rather than a
// row of labels swapping their text. Neighbours dim with distance, which is
// what makes it read as a window onto something longer.
//
// Highlighting is per line, not per word: LRC carries one timestamp per line,
// and the word-level extension is not something lrclib serves.
Item {
    id: root

    // 5 x 32 = 160px, which is exactly what the equalizer pane occupies
    // (96px of band sliders + 10px gap + 54px of presets). Matching it means
    // swapping panes does not resize the panel, and it uses the space the
    // shorter version was leaving empty at the bottom.
    readonly property int lineHeight: 32
    readonly property int visibleLines: 5

    readonly property int currentSize: 14
    readonly property int nearbySize: 12

    // Index of the slot the current line occupies — the middle one.
    readonly property int centreSlot: Math.floor(root.visibleLines / 2)

    implicitHeight: root.lineHeight * root.visibleLines

    clip: true

    // Nothing to show: say which of the two reasons it is, rather than
    // leaving an empty box that looks broken.
    Caption {
        anchors.centerIn: parent
        visible: !Lyrics.hasLyrics
        width: parent.width - 20
        horizontalAlignment: Text.AlignHCenter
        text: Lyrics.loading ? "Looking for lyrics…" : (Lyrics.player ? "No lyrics available for this track" : "Nothing playing")
        color: Theme.overlay0
        size: 12
    }

    // ── Synced: the column slides, the current line is centred ───────────
    Item {
        anchors.fill: parent
        visible: Lyrics.hasLyrics && Lyrics.synced

        Column {
            id: scroller

            width: parent.width

            // Centre the current line in the middle slot. Before the first cue
            // the index is -1, which parks the opening line in the centre
            // ready to move.
            y: root.lineHeight * (root.centreSlot - Math.max(0, Lyrics.currentIndex))

            Behavior on y {
                NumberAnimation {
                    duration: Theme.dur(420)
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                model: Lyrics.lines

                Item {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property int distance: Math.abs(row.index - Math.max(0, Lyrics.currentIndex))
                    readonly property bool current: row.index === Lyrics.currentIndex

                    width: scroller.width
                    height: root.lineHeight

                    Caption {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight

                        text: row.modelData.text.length > 0 ? row.modelData.text : "♪"
                        color: row.current ? Theme.icon : Theme.subtext0
                        font.bold: row.current
                        size: row.current ? root.currentSize : root.nearbySize

                        Behavior on font.pixelSize {
                            NumberAnimation {
                                duration: Theme.dur(300)
                            }
                        }

                        // Fades out with distance, so only the immediate
                        // neighbours are legible and the rest suggests depth.
                        opacity: row.distance === 0 ? 1 : row.distance === 1 ? 0.5 : row.distance === 2 ? 0.22 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.dur(300)
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.dur(300)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Plain: no timing to follow, so let it be read by hand ────────────
    Flickable {
        id: plainView

        anchors.fill: parent
        visible: Lyrics.hasLyrics && !Lyrics.synced
        contentHeight: plainCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: plainCol
            width: plainView.width

            Repeater {
                model: Lyrics.lines

                Caption {
                    required property var modelData

                    // vcenter off: Caption anchors verticalCenter by default,
                    // and a vertical anchor inside a Column makes every line
                    // stack on the same row.
                    vcenter: false
                    width: plainCol.width
                    height: root.lineHeight
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: modelData.text
                    color: Theme.subtext0
                    size: root.nearbySize
                }
            }
        }
    }

    ScrollTrack {
        view: plainView
        visible: plainView.visible
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }
}
