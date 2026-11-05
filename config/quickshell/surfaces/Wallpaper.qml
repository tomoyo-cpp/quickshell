import QtQuick
import QtQuick.Effects
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import "root:/"

// The wallpaper, one of two per monitor (shell.qml makes both):
//
//   - sharp: behind your windows. niri also draws it inside every workspace
//     in the overview, so there it fades out and the workspaces, which are
//     transparent (background-color in config.kdl), show the backdrop.
//   - backdrop: a blurred copy in niri's backdrop (layer-rule
//     "quickshell-backdrop" in config.kdl): around and behind the
//     workspaces in the overview.
//
// Both follow Wallpapers.current and load the same file, so a new wallpaper
// lands on both together. The blur is done here, on the GPU.
PanelWindow {
    id: root

    required property var modelData
    property bool backdrop: false

    screen: modelData

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: root.backdrop ? "quickshell-backdrop" : "quickshell-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: root.backdrop ? Theme.palette.crust : "transparent"
    // Clicks on the desktop go to niri.
    mask: Region {}

    // Which of the two images is showing. A new wallpaper loads into the
    // other one and cross-fades in once it is ready.
    property bool onA: true

    function show(path) {
        const src = path ? "file://" + path : "";
        const back = root.onA ? b : a;
        if ((root.onA ? a : b).source.toString() === src)
            return;
        back.source = src;
        if (back.status === Image.Ready || src === "")
            root.onA = !root.onA;
    }

    Connections {
        target: Wallpapers
        function onCurrentChanged() {
            root.show(Wallpapers.current);
        }
    }
    Component.onCompleted: root.show(Wallpapers.current)

    component Layer: Image {
        property bool front
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        // Decoded at the screen's real pixel size (a quarter of it for the
        // backdrop, which is blurred anyway): sharp, quick to draw, and no
        // 5K bitmap kept in memory for a 1080p screen.
        readonly property real decodeScale: root.backdrop ? 0.25 : Screen.devicePixelRatio
        sourceSize: Qt.size(Math.round(width * decodeScale), Math.round(height * decodeScale))
        opacity: front ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.dur(150)
                easing.type: Easing.OutQuad
            }
        }
        onStatusChanged: if (status === Image.Ready && !front && source.toString() !== "")
            root.onA = !root.onA
    }

    Item {
        anchors.fill: parent
        // The sharp copy is gone in the overview, so the workspaces show
        // the backdrop.
        opacity: !root.backdrop && Niri.overviewOpen ? 0 : 1
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.dur(90)
                easing.type: Easing.OutQuad
            }
        }

        Item {
            id: images
            anchors.fill: parent
            // Blurring pulls in the transparent space past the edges, so the
            // blurred copy is drawn a little past the screen on every side.
            anchors.margins: root.backdrop ? -40 : 0

            layer.enabled: root.backdrop
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: 40
            }

            Layer {
                id: a
                front: root.onA
            }
            Layer {
                id: b
                front: !root.onA
            }
        }
    }
}
