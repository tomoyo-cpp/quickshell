import QtQuick
import QtQuick.Shapes
import Quickshell
import "root:/"

// Clipboard history, flowing out of the bar beneath its button. Mirrors
// NotificationPanel, but anchored from the right.
PanelWindow {
    id: root

    required property var bar

    // Screen x of the button, so the panel lines up under it.
    property real anchorX: 0

    readonly property int bodyWidth: 340
    readonly property int notch: 18

    // Never past the middle of the screen; the list scrolls beyond that.
    readonly property int maxBodyHeight: Math.max(160, Math.round((root.screen ? root.screen.height : 1080) / 2) - (Theme.barMargin + Theme.barHeight))

    readonly property int bodyPadding: 12
    readonly property int rowGap: 10

    // Measured from the items themselves rather than a hand-kept constant for
    // the chrome. That constant counted the margins, the header and a divider
    // that no longer exists, but never the two section labels or the empty
    // state — so with nothing copied the outline stopped short and "Recent"
    // and "Nothing copied yet" drew outside the panel, on the wallpaper.
    readonly property int bodyHeight: Math.min(maxBodyHeight, Math.ceil(root.bodyPadding * 2 + head.implicitHeight + (clipBox.visible ? root.rowGap + clipBox.height : 0)))

    // Published for the click-catcher.
    readonly property int panelWidth: bodyWidth + notch * 2
    readonly property int panelLeft: Math.min((root.screen ? root.screen.width : 1920) - Theme.barSideMargin - Theme.barRadius - panelWidth, Math.round(root.anchorX - panelWidth / 2))

    // The outline follows this rather than bodyHeight directly. Lists fill in
    // their delegates lazily, so bodyHeight can grow mid-animation; easing to
    // the new value absorbs that instead of stepping to it.
    property real smoothHeight: root.bodyHeight

    Behavior on smoothHeight {
        NumberAnimation {
            duration: Theme.dur(140)
            easing.type: Easing.OutCubic
        }
    }

    property bool closing: false
    property real reveal: 0
    property real contentFade: 0

    readonly property bool open: bar.openPopup === "clipboard"

    anchors {
        top: true
        left: true
    }

    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    margins {
        top: Theme.barMargin + Theme.barHeight
        left: Math.max(0, root.panelLeft)
    }

    implicitWidth: panelWidth
    implicitHeight: maxBodyHeight + Theme.shadowPad
    color: "transparent"
    visible: open || closing

    mask: Region {
        item: panel
    }

    // Poll only while the list is on screen.
    Binding {
        target: Cliphist
        property: "watching"
        value: root.open
    }

    onOpenChanged: {
        if (open) {
            root.closing = false;
            closeAnim.stop();
            openAnim.restart();
            Cliphist.refresh();
        } else if (root.reveal > 0) {
            openAnim.stop();
            root.closing = true;
            closeAnim.restart();
        }
    }

    SequentialAnimation {
        id: openAnim

        // Strictly ordered: the container forms first, then the contents fade
        // in. Overlapping them let text appear over a half-formed, still
        // translucent panel.
        NumberAnimation {
            target: root
            property: "reveal"
            to: 1
            duration: Theme.dur(240)
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "contentFade"
            to: 1
            duration: Theme.dur(170)
            easing.type: Easing.OutQuad
        }
    }

    SequentialAnimation {
        id: closeAnim

        NumberAnimation {
            target: root
            property: "contentFade"
            to: 0
            duration: Theme.dur(70)
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: root
            property: "reveal"
            to: 0
            duration: Theme.dur(120)
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: root.closing = false
        }
    }

    component Chip: Rectangle {
        id: cb

        property string label: ""
        property color accent: Theme.icon

        signal triggered

        width: cbLabel.implicitWidth + 18
        height: 22
        radius: 11
        color: cbMouse.containsMouse ? Theme.surface1 : Theme.alpha(Theme.surface0, 0.6)

        Caption {
            id: cbLabel
            anchors.centerIn: parent
            text: cb.label
            color: cb.accent
            size: 10
        }

        MouseArea {
            id: cbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cb.triggered()
        }
    }

    Item {
        id: panel
        width: root.panelWidth
        height: root.bodyHeight + Theme.shadowPad

        Shape {
            id: outlineShape

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            readonly property int n: root.notch
            readonly property int w: root.bodyWidth
            readonly property real minH: root.notch + Theme.popupRadius + 1
            // Interpolated from the minimum, not clamped to it: the clamp
            // pinned h flat and then released it at the curve's steepest
            // point, which showed as a kink partway through.
            readonly property real h: outlineShape.minH + Math.max(0, root.smoothHeight - outlineShape.minH) * root.reveal
            readonly property int r: Theme.popupRadius

            ShapePath {
                id: outline
                fillColor: Theme.panelBg
                strokeWidth: 0
                strokeColor: "transparent"

                readonly property int n: outlineShape.n
                readonly property int w: outlineShape.w
                readonly property real h: outlineShape.h
                readonly property int r: outlineShape.r

                startX: 0
                startY: 0

                PathArc {
                    x: outline.n
                    y: outline.n
                    radiusX: outline.n
                    radiusY: outline.n
                    direction: PathArc.Clockwise
                }
                PathLine {
                    x: outline.n
                    y: outline.h - outline.r
                }
                PathArc {
                    x: outline.n + outline.r
                    y: outline.h
                    radiusX: outline.r
                    radiusY: outline.r
                    direction: PathArc.Counterclockwise
                }
                PathLine {
                    x: outline.n + outline.w - outline.r
                    y: outline.h
                }
                PathArc {
                    x: outline.n + outline.w
                    y: outline.h - outline.r
                    radiusX: outline.r
                    radiusY: outline.r
                    direction: PathArc.Counterclockwise
                }
                PathLine {
                    x: outline.n + outline.w
                    y: outline.n
                }
                PathArc {
                    x: outline.n + outline.w + outline.n
                    y: 0
                    radiusX: outline.n
                    radiusY: outline.n
                    direction: PathArc.Clockwise
                }
                PathLine {
                    x: 0
                    y: 0
                }
            }
        }

        Item {
            x: root.notch
            y: (1 - root.contentFade) * -8
            width: root.bodyWidth
            height: root.bodyHeight
            opacity: root.contentFade
            // Composited once as a texture while animating, rather than alpha-
            // blending every child separately each frame. Dropped again at rest so
            // nothing pays for an offscreen buffer when it is not moving.
            layer.enabled: openAnim.running || closeAnim.running

            Column {
                x: root.bodyPadding
                y: root.bodyPadding
                width: parent.width - root.bodyPadding * 2
                spacing: root.rowGap

                // Everything whose height does not depend on how much room is
                // left over. Grouped so the panel can measure it in one go and
                // size itself from it, without the recent list — which is sized
                // from what remains — feeding back into the total.
                Column {
                    id: head

                    width: parent.width
                    spacing: root.rowGap

                    // ── Header ───────────────────────────────────────────────
                    Item {
                        width: parent.width
                        height: 24

                        Glyph {
                            id: headIcon
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰅍"
                            size: 15
                        }

                        Caption {
                            anchors.left: headIcon.right
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Clipboard"
                            color: Theme.icon
                            size: 13
                            font.bold: true
                        }

                        Caption {
                            anchors.right: wipeBtn.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: `${Cliphist.entries.length}`
                            color: Theme.overlay1
                            size: 11
                        }

                        // Wipe reduced to an icon; the word took a third of the
                        // header for something used rarely.
                        Rectangle {
                            id: wipeBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            radius: 12
                            color: wipeMouse.containsMouse ? Theme.alpha(Theme.red, 0.25) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰩹"
                                font.family: Theme.iconFont
                                font.pixelSize: 12
                                color: wipeMouse.containsMouse ? Theme.red : Theme.overlay1
                            }

                            MouseArea {
                                id: wipeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Cliphist.wipe()
                            }
                        }
                    }

                    // ── Pinned ───────────────────────────────────────────────
                    SectionLabel {
                        text: "Pinned"
                        count: Cliphist.pinned.length
                        visible: Cliphist.pinned.length > 0
                    }

                    Item {
                        width: parent.width
                        height: Math.min(108, pinnedList.contentHeight)
                        visible: Cliphist.pinned.length > 0

                        ScrollTrack {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            view: pinnedList
                        }

                        ListView {
                            id: pinnedList

                            anchors.fill: parent
                            anchors.rightMargin: 8
                            clip: true
                            spacing: 4
                            model: Cliphist.pinned
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Entry {
                                required property var modelData

                                width: ListView.view.width
                                preview: modelData.preview
                                pinned: true
                                onActivated: {
                                    Cliphist.copyText(modelData.text);
                                    root.bar.closePopup();
                                }
                                onSecondary: Cliphist.unpin(modelData.text)
                            }
                        }
                    }

                    // ── Recent ───────────────────────────────────────────────
                    SectionLabel {
                        text: "Recent"
                        count: Cliphist.entries.length
                    }

                    Caption {
                        width: parent.width
                        vcenter: false
                        visible: Cliphist.entries.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        text: Cliphist.loading ? "Loading…" : "Nothing copied yet"
                        color: Theme.overlay0
                        size: 11
                    }
                }

                Item {
                    id: clipBox

                    // Whatever is left beneath the fixed part, and never more
                    // than the list actually needs. Hidden outright when empty
                    // so the Column drops its spacing too, instead of leaving a
                    // gap under the "Nothing copied yet" notice.
                    readonly property real available: root.maxBodyHeight - root.bodyPadding * 2 - head.implicitHeight - root.rowGap

                    width: parent.width
                    visible: Cliphist.entries.length > 0
                    height: Math.max(0, Math.min(clipList.contentHeight, clipBox.available))

                    ScrollTrack {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        view: clipList
                    }

                    ListView {
                        id: clipList

                        anchors.fill: parent
                        // Gutter for the track, so entries never run under it.
                        anchors.rightMargin: 8
                        clip: true
                        spacing: 4
                        model: Cliphist.entries
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Entry {
                            required property var modelData

                            width: ListView.view.width
                            preview: modelData.preview
                            entryId: modelData.id
                            onActivated: {
                                Cliphist.copy(modelData.id);
                                root.bar.closePopup();
                            }
                            onPin: Cliphist.pin(modelData)
                            onSecondary: Cliphist.remove(modelData.line)
                        }
                    }
                }
            }
        }
    }

    component SectionLabel: Item {
        property string text: ""
        property int count: 0

        width: parent.width
        height: 14

        Caption {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: parent.text.toUpperCase()
            color: Theme.overlay0
            size: 9
            font.bold: true
            font.letterSpacing: 1
        }

        Caption {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: parent.count
            color: Theme.overlay0
            size: 9
        }
    }

    // One clipboard row. Images are recognised from cliphist's own
    // "[[ binary data ... ]]" placeholder and given a friendlier label.
    component Entry: Rectangle {
        id: entry

        property string preview: ""
        property bool pinned: false
        // Empty for pinned entries: those keep their own copy of the text and
        // have no cliphist id to decode a thumbnail from.
        property string entryId: ""

        signal activated
        signal pin
        signal secondary

        readonly property var binary: /^\[\[\s*binary data\s+(\S+\s+\S+)\s+(\w+)\s+(\S+)/.exec(entry.preview)
        readonly property bool isImage: binary !== null

        // Split across two lines for image rows: the thumbnail leaves roughly
        // 130px of text column, and kind/dimensions/size on one line elides
        // away exactly the dimensions and file size worth reading.
        readonly property string label: isImage ? `${binary[2].toUpperCase()} image` : entry.preview
        readonly property string stats: isImage ? `${binary[3].replace("x", "×")} · ${binary[1]}` : ""

        // Re-evaluated when a thumbnailing pass finishes, so a row built
        // before its thumbnail existed picks it up.
        readonly property string thumbSource: {
            if (!Settings.clipboardThumbnails || !entry.isImage || entry.entryId === "")
                return "";
            Cliphist.thumbRev;   // dependency, deliberately
            return `file://${Cliphist.thumbFor(entry.entryId)}`;
        }

        readonly property bool hasThumb: thumb.ready

        readonly property bool hovered: rowMouse.containsMouse || pinMouse.containsMouse || secondMouse.containsMouse

        // Follows the thumbnail rather than a constant, so a wider-than-16:9
        // image does not leave dead space under it. Safe from a loop: the
        // thumbnail's width is fixed, so its height never depends on this.
        height: entry.hasThumb ? thumb.height + 14 : 34
        radius: 9
        color: hovered ? Theme.alpha(Theme.surface1, 0.85) : Theme.alpha(Theme.surface0, 0.45)

        Behavior on color {
            ColorAnimation {
                duration: Theme.anim
            }
        }

        // Full-width click target, declared first so the buttons sit on top.
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: entry.activated()
        }

        // Loaded for every image entry; the row only grows once it is ready,
        // so a missing or still-rendering thumbnail leaves the compact layout
        // untouched rather than opening a gap.
        Thumbnail {
            id: thumb

            anchors.left: parent.left
            anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            width: entry.hasThumb ? 100 : 0
            // 16:9, floored the same way as the notification previews.
            height: entry.hasThumb ? Math.round(100 / Math.max(16 / 9, thumb.aspect)) : 0
            visible: entry.hasThumb
            corner: 7
            source: entry.thumbSource
        }

        Text {
            id: kind
            anchors.left: entry.hasThumb ? thumb.right : parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: entry.pinned ? "󰐃" : entry.isImage ? "󰋩" : "󰉿"
            font.family: Theme.iconFont
            font.pixelSize: 12
            color: entry.pinned ? Theme.icon : Theme.overlay1
        }

        Column {
            anchors.left: kind.right
            anchors.leftMargin: 9
            anchors.right: actions.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Caption {
                vcenter: false
                width: parent.width
                text: entry.label
                color: entry.isImage ? Theme.overlay1 : (entry.hovered ? Theme.icon : Theme.subtext0)
                font.italic: entry.isImage
                size: 11
            }

            Caption {
                vcenter: false
                width: parent.width
                visible: entry.stats !== ""
                text: entry.stats
                color: Theme.overlay0
                size: 10
            }
        }

        Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            // Kept hit-testable while hidden, so hovering them works.
            opacity: entry.hovered ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim
                }
            }

            Rectangle {
                width: 22
                height: 22
                radius: 11
                visible: !entry.pinned
                color: pinMouse.containsMouse ? Theme.alpha(Theme.icon, 0.22) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰐃"
                    font.family: Theme.iconFont
                    font.pixelSize: 11
                    color: Theme.icon
                }

                MouseArea {
                    id: pinMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: entry.pin()
                }
            }

            Rectangle {
                width: 22
                height: 22
                radius: 11
                color: secondMouse.containsMouse ? Theme.alpha(Theme.red, 0.3) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: Theme.iconFont
                    font.pixelSize: 11
                    color: secondMouse.containsMouse ? Theme.red : Theme.overlay1
                }

                MouseArea {
                    id: secondMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: entry.secondary()
                }
            }
        }
    }
}
