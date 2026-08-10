import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "root:/"

// Application launcher: slides up out of the bottom edge of the screen.
//
// Drawn with the same concave fillets the bar panels use, mirrored — they flow
// out of the bar's bottom edge, this flows out of the screen's.
//
// A layer surface rather than a popup, because it needs keyboard focus for the
// search field: a grabbing popup requires its parent surface to have already
// received input, which a keybind-triggered open never satisfies.
PanelWindow {
    id: root

    required property var bar

    readonly property bool open: bar.openPopup === "launcher"

    readonly property int bodyWidth: 440
    readonly property int notch: 18
    readonly property int rowHeight: 38
    readonly property int headerHeight: 48
    readonly property int maxRows: 6

    // With no query: recents first, then everything else alphabetically, as
    // one list. Searching replaces it with ranked matches.
    readonly property bool showingRecent: Apps.query.trim() === "" && Apps.recent.length > 0
    readonly property int recentCount: showingRecent ? Apps.recent.length : 0

    readonly property var shown: {
        if (Apps.query.trim() !== "")
            return Apps.results;

        const recent = Apps.recent;
        const ids = recent.map(a => a.id);
        // `all` is already name-sorted by the scan script.
        const rest = Apps.all.filter(a => !ids.includes(a.id));
        return recent.concat(rest);
    }

    readonly property int rows: Math.min(root.maxRows, Math.max(1, root.shown.length))
    readonly property int bodyHeight: headerHeight + rows * rowHeight + 12

    property int selected: 0

    property bool closing: false
    property real reveal: 0

    // Contents arrive after the panel has travelled, so they are not read
    // mid-slide.
    property real contentFade: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    // `focusable: true` maps to on-demand keyboard focus, which only arrives
    // once the surface is clicked — so a keybind-opened launcher never got
    // any key events. Exclusive takes focus as soon as it maps, which is what
    // a search field needs.
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: open || closing

    onOpenChanged: {
        if (open) {
            Apps.refresh();
            root.selected = 0;
            search.text = "";
            root.closing = false;
            closeAnim.stop();
            openAnim.restart();
            focusGrab.restart();
        } else if (root.reveal > 0) {
            openAnim.stop();
            root.closing = true;
            closeAnim.restart();
        }
    }

    // forceActiveFocus() before the surface maps is a no-op, so it is deferred
    // a frame.
    Timer {
        id: focusGrab
        interval: 30
        repeat: false
        onTriggered: search.forceActiveFocus()
    }

    // Run in parallel rather than end-to-end: the fade starts just before the
    // slide finishes, so the contents are there the moment the panel lands
    // instead of after a visible beat.
    ParallelAnimation {
        id: openAnim

        NumberAnimation {
            target: root
            property: "reveal"
            to: 1
            duration: Theme.dur(180)
            // A slight overshoot gives the panel some weight as it lands.
            easing.type: Easing.OutBack
            easing.overshoot: 0.6
        }

        // No delay: the contents come up with the panel rather than waiting
        // for it to land.
        NumberAnimation {
            target: root
            property: "contentFade"
            to: 1
            duration: Theme.dur(90)
            easing.type: Easing.OutQuad
        }
    }

    SequentialAnimation {
        id: closeAnim

        // Contents clear first, then the panel drops away.
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
            duration: Theme.dur(150)
            easing.type: Easing.InCubic
        }

        ScriptAction {
            script: root.closing = false
        }
    }

    function moveSelection(delta) {
        const n = root.shown.length;
        if (n === 0)
            return;
        root.selected = (root.selected + delta + n) % n;
        list.positionViewAtIndex(root.selected, ListView.Contain);
    }

    function activate(index) {
        const app = root.shown[index];
        if (!app)
            return;
        Apps.launch(app);
        root.bar.closePopup();
    }

    // Clicking anywhere outside the panel dismisses.
    MouseArea {
        anchors.fill: parent
        onPressed: root.bar.closePopup()
    }

    // The dim rises from the bottom edge with the panel rather than fading in
    // across the whole screen at once.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * root.reveal
        color: Theme.alpha(Theme.crust, 0.45)

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.alpha(Theme.crust, 0.0)
            }
            GradientStop {
                position: 0.35
                color: Theme.alpha(Theme.crust, 0.42)
            }
            GradientStop {
                position: 1
                color: Theme.alpha(Theme.crust, 0.55)
            }
        }
    }

    // The panel occupies the bottom of the screen; `reveal` slides it up.
    Item {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: root.bodyWidth + root.notch * 2
        height: root.bodyHeight + root.notch

        y: (1 - root.reveal) * height

        Behavior on height {
            NumberAnimation {
                duration: Theme.dur(130)
                easing.type: Easing.OutCubic
            }
        }

        Shape {
            id: outlineShape

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            readonly property int n: root.notch
            readonly property int w: root.bodyWidth
            readonly property int h: panel.height
            readonly property int r: Theme.popupRadius

            ShapePath {
                id: outline

                fillColor: Theme.panelBg
                strokeWidth: 0
                strokeColor: "transparent"

                readonly property int n: outlineShape.n
                readonly property int w: outlineShape.w
                readonly property int h: outlineShape.h
                readonly property int r: outlineShape.r

                startX: 0
                startY: outline.h

                // Concave fillet flaring into the screen edge, bottom left.
                PathArc {
                    x: outline.n
                    y: outline.h - outline.n
                    radiusX: outline.n
                    radiusY: outline.n
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: outline.n
                    y: outline.r
                }

                PathArc {
                    x: outline.n + outline.r
                    y: 0
                    radiusX: outline.r
                    radiusY: outline.r
                    direction: PathArc.Clockwise
                }

                PathLine {
                    x: outline.n + outline.w - outline.r
                    y: 0
                }

                PathArc {
                    x: outline.n + outline.w
                    y: outline.r
                    radiusX: outline.r
                    radiusY: outline.r
                    direction: PathArc.Clockwise
                }

                PathLine {
                    x: outline.n + outline.w
                    y: outline.h - outline.n
                }

                // ...and bottom right.
                PathArc {
                    x: outline.n + outline.w + outline.n
                    y: outline.h
                    radiusX: outline.n
                    radiusY: outline.n
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: 0
                    y: outline.h
                }
            }
        }

        // ── Contents ─────────────────────────────────────────────────────
        Item {
            x: root.notch
            width: root.bodyWidth
            height: root.bodyHeight

            opacity: root.contentFade

            // ── Search ───────────────────────────────────────────────────
            Item {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: root.headerHeight

                Glyph {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍉"
                    size: 17
                    color: Theme.overlay1
                }

                TextInput {
                    id: search
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 14
                    anchors.right: countLabel.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 24

                    font.family: Theme.font
                    font.pixelSize: 14
                    color: Theme.text
                    selectByMouse: true
                    clip: true
                    focus: true

                    onTextChanged: {
                        Apps.query = text;
                        root.selected = 0;
                    }

                    Keys.onEscapePressed: root.bar.closePopup()
                    Keys.onReturnPressed: root.activate(root.selected)
                    Keys.onEnterPressed: root.activate(root.selected)
                    Keys.onDownPressed: root.moveSelection(1)
                    Keys.onUpPressed: root.moveSelection(-1)
                    Keys.onTabPressed: root.moveSelection(1)

                    Caption {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text === ""
                        text: "Search applications…"
                        color: Theme.overlay0
                        size: 14
                    }
                }

                Caption {
                    id: countLabel
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: Apps.results.length
                    color: Theme.overlay0
                    size: 12
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    height: 1
                    color: Theme.surface0
                }
            }

            // ── Results ──────────────────────────────────────────────────
            ListView {
                id: list
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 6
                clip: true
                model: root.shown
                boundsBehavior: Flickable.StopAtBounds

                // Only appears when the list runs past the bottom, so it
                // doubles as the cue that there is more below.
                //
                // ListView reparents non-delegate children to itself rather
                // than to contentItem, so this is already stationary in the
                // viewport; offsetting it by contentY makes it drift.
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 1
                    width: 3
                    radius: 1.5
                    color: Theme.alpha(Theme.icon, 0.4)

                    visible: list.contentHeight > list.height
                    height: Math.max(24, list.height * (list.height / Math.max(1, list.contentHeight)))
                    y: list.contentHeight > list.height ? Math.max(0, Math.min(list.height - height, (list.contentY / (list.contentHeight - list.height)) * (list.height - height))) : 0
                }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index

                    readonly property bool current: root.selected === row.index
                    readonly property string iconSource: Apps.iconFor(row.modelData)

                    width: ListView.view.width
                    height: root.rowHeight
                    radius: 11
                    color: current ? Theme.alpha(Theme.icon, 0.14) : rowMouse.containsMouse ? Theme.surface0 : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.anim
                        }
                    }

                    Image {
                        id: rowIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        sourceSize.width: 44
                        sourceSize.height: 44
                        fillMode: Image.PreserveAspectFit
                        visible: row.iconSource !== ""
                        source: row.iconSource
                    }

                    // Themeless apps fall back to an initial, as in workspaces.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        radius: 6
                        visible: row.iconSource === ""
                        color: Theme.alpha(Theme.overlay0, 0.55)

                        Caption {
                            anchors.centerIn: parent
                            text: (row.modelData.name || "?").charAt(0).toUpperCase()
                            color: Theme.text
                            size: 13
                            font.bold: true
                        }
                    }

                    Caption {
                        anchors.left: rowIcon.right
                        anchors.leftMargin: 13
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        color: row.current ? Theme.icon : Theme.subtext0
                        size: 13
                    }

                    // Closes the recent group off from the alphabetical rest.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        height: 1
                        visible: root.recentCount > 0 && row.index === root.recentCount - 1
                        color: Theme.surface0
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selected = row.index
                        onClicked: root.activate(row.index)
                    }
                }
            }

            Caption {
                anchors.centerIn: list
                visible: root.shown.length === 0
                text: Apps.all.length === 0 ? "No applications found" : "No matches"
                color: Theme.overlay0
                size: 12
            }
        }
    }
}
