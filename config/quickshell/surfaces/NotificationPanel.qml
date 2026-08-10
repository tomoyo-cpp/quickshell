import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Notifications
import "root:/"

// Notification history, flowing out of the bar beneath the bell. Same
// construction as the dashboard — concave fillets so it reads as part of the
// bar — but narrow, and anchored to the left rather than centred.
PanelWindow {
    id: root

    required property var bar

    // Screen x of the bell, so the panel lines up under it.
    property real anchorX: 0

    // Narrow enough to stay clear of the centred dashboard.
    readonly property int bodyWidth: 300
    readonly property int notch: 18
    // Never past the middle of the screen; the list scrolls beyond that.
    readonly property int maxBodyHeight: Math.max(160, Math.round((root.screen ? root.screen.height : 1080) / 2) - (Theme.barMargin + Theme.barHeight))

    // Chrome above the list: card margins, header row, spacing, rule.
    // Published for the click-catcher.
    readonly property int panelLeft: Math.max(Theme.barSideMargin + Theme.barRadius, root.anchorX - root.bodyWidth / 2)
    readonly property int panelWidth: bodyWidth + notch * 2

    readonly property int chrome: 14 * 2 + 24 + 8 + 1 + 8

    // Measured from the list itself rather than guessed from a per-card
    // constant, so cards that wrap to two lines are accounted for.
    readonly property int bodyHeight: Math.min(maxBodyHeight, chrome + Math.max(18, Math.ceil(notifList.contentHeight)))

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

    readonly property bool open: bar.openPopup === "notifications"

    anchors {
        top: true
        left: true
    }

    // The bar reserves an exclusive zone; without ignoring it the panel would
    // be pushed down by the bar's own height.
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    margins {
        // Flush with the bar's bottom edge. The dark band you may see at
        // the join is the bar's own drop shadow, not a gap — overlapping to
        // hide it just covers the bar instead.
        top: Theme.barMargin + Theme.barHeight
        // Centred on the bell, but the *fillet* — not the body — is what has
        // to stay inside the bar. It flares outward from the body, so the
        // whole window must start at the bar's edge, putting the body a notch
        // further in. Offset by the bar's corner radius too, or the fillet
        // lands where the bar's own rounded corner has already curved away.
        left: root.panelLeft
    }

    implicitWidth: bodyWidth + notch * 2
    implicitHeight: maxBodyHeight + Theme.shadowPad
    color: "transparent"
    visible: open || closing

    mask: Region {
        item: panel
    }

    onOpenChanged: {
        if (open) {
            root.closing = false;
            closeAnim.stop();
            openAnim.restart();
            Notifs.markAllSeen();
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

    Item {
        id: panel
        x: 0
        width: root.bodyWidth + root.notch * 2
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
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                Item {
                    width: parent.width
                    height: 24

                    Caption {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: Notifs.history.length > 0 ? `${Notifs.history.length} notifications` : "All caught up"
                        color: Theme.subtext0
                        size: 12
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Chip {
                            label: Notifs.dnd ? "󰂛  Silent" : "󰂚  Alerts"
                            highlighted: Notifs.dnd
                            onTriggered: Notifs.dnd = !Notifs.dnd
                        }
                        Chip {
                            label: "Clear"
                            accent: Theme.red
                            onTriggered: Notifs.clearHistory()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.surface0
                }

                // Diffed by identity so removing one card leaves the other
                // delegates — and their in-flight animations — alone.
                ScriptModel {
                    id: historyModel
                    values: Notifs.history
                }

                ListView {
                    id: notifList

                    width: parent.width
                    height: parent.height - y
                    clip: true
                    spacing: 8
                    model: historyModel
                    boundsBehavior: Flickable.StopAtBounds

                    // Only shown when there is actually something to scroll.
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 1
                        width: 3
                        radius: 1.5
                        color: Theme.alpha(Theme.icon, 0.35)

                        visible: notifList.contentHeight > notifList.height
                        height: notifList.height * (notifList.height / Math.max(1, notifList.contentHeight))
                        y: notifList.contentHeight > 0 ? notifList.contentY / notifList.contentHeight * notifList.height : 0
                    }

                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        required property int index

                        readonly property color urgencyColor: modelData.urgency === NotificationUrgency.Critical ? Theme.red : modelData.urgency === NotificationUrgency.Low ? Theme.overlay1 : Theme.icon

                        // Same shape as the toasts: animate, then let the
                        // model drop the entry. Removing first would destroy
                        // the delegate with nothing to animate.
                        property bool leaving: false
                        property real collapse: 1

                        function close() {
                            if (card.leaving)
                                return;
                            card.leaving = true;
                            cardExit.start();
                        }

                        SequentialAnimation {
                            id: cardExit

                            ParallelAnimation {
                                NumberAnimation {
                                    target: card
                                    property: "opacity"
                                    to: 0
                                    duration: Theme.dur(110)
                                    easing.type: Easing.InQuad
                                }
                                NumberAnimation {
                                    target: card
                                    property: "x"
                                    to: card.width * 0.35
                                    duration: Theme.dur(120)
                                    easing.type: Easing.InCubic
                                }
                            }

                            // Collapse last so the cards below slide up into
                            // the gap instead of snapping.
                            NumberAnimation {
                                target: card
                                property: "collapse"
                                to: 0
                                duration: Theme.dur(95)
                                easing.type: Easing.InQuad
                            }

                            ScriptAction {
                                // By id, not index: a notification arriving
                                // mid-animation would shift every position.
                                script: Notifs.removeById(card.modelData.uid)
                            }
                        }

                        width: ListView.view.width
                        height: Math.max(0, (body.implicitHeight + 16) * card.collapse)
                        visible: card.collapse > 0.01
                        clip: card.leaving
                        radius: 11
                        color: Theme.alpha(Theme.surface0, 0.55)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: parent.height - 14
                            radius: 2
                            color: card.urgencyColor
                        }

                        Rectangle {
                            id: trash
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.top: parent.top
                            anchors.topMargin: 8
                            width: 22
                            height: 22
                            radius: 11
                            // Always shown rather than revealed on hover: a
                            // hover-gated button is easy to make unreachable,
                            // and in a notification centre it is wanted often
                            // enough to earn permanent space.
                            color: trashMouse.containsMouse ? Theme.alpha(Theme.red, 0.3) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.family: Theme.iconFont
                                font.pixelSize: 11
                                color: trashMouse.containsMouse ? Theme.red : Theme.overlay1
                            }

                            MouseArea {
                                id: trashMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: card.close()
                            }
                        }

                        Column {
                            id: body
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Item {
                                width: parent.width
                                height: 13

                                Caption {
                                    anchors.left: parent.left
                                    text: card.modelData.appName || "system"
                                    color: card.urgencyColor
                                    size: 9
                                    font.bold: true
                                }
                                Caption {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 22
                                    text: Qt.formatTime(card.modelData.time, "HH:mm")
                                    color: Theme.overlay0
                                    size: 9
                                }
                            }

                            Caption {
                                vcenter: false
                                width: parent.width
                                text: card.modelData.summary
                                color: Theme.icon
                                size: 11
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Caption {
                                vcenter: false
                                width: parent.width
                                visible: text !== ""
                                text: card.modelData.body
                                color: Theme.subtext0
                                size: 10
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }

                            // Screenshots and any other image-bearing
                            // notification: shown wide rather than as a
                            // 34px chip, since the picture is the point.
                            Item {
                                width: parent.width

                                // Sized from the image's own ratio so a 16:9
                                // screenshot is shown whole. Never taller than
                                // 16:9 — a portrait image letterboxes instead
                                // of turning the card into a column.
                                height: preview.ready ? Math.round(width / Math.max(16 / 9, preview.aspect)) + 4 : 0
                                visible: preview.ready

                                Thumbnail {
                                    id: preview

                                    anchors.fill: parent
                                    anchors.topMargin: 4
                                    corner: 8
                                    decodeWidth: 640
                                    source: Notifs.previewOf(card.modelData)
                                }

                                MouseArea {
                                    anchors.fill: preview
                                    cursorShape: Qt.PointingHandCursor
                                    // Opens in the default image viewer.
                                    onClicked: Quickshell.execDetached(["xdg-open", decodeURIComponent(String(preview.source).replace("file://", ""))])
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component Chip: Rectangle {
        id: cb

        property string label: ""
        property color accent: Theme.icon
        property bool highlighted: false

        signal triggered

        width: cbLabel.implicitWidth + 18
        height: 22
        radius: 11
        color: cb.highlighted ? Theme.alpha(cb.accent, 0.22) : cbMouse.containsMouse ? Theme.surface1 : Theme.alpha(Theme.surface0, 0.6)

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
}
