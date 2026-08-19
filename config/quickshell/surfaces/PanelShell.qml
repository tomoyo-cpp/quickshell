import QtQuick
import Quickshell
import "root:/"

// Shared chrome for the bar's dropdown panels: the concave flow-out outline,
// the open/close animation, and the anchoring maths.
//
// Extracted because NotificationPanel and ClipboardPanel had grown identical
// copies of all three, and every fix had to be made twice.
PanelWindow {
    id: root

    required property var bar
    required property string popupName

    // Screen x of the button this hangs from.
    property real anchorX: 0

    property int bodyWidth: 340
    property int bodyHeight: 300
    readonly property int notch: 18

    default property alias content: body.data

    readonly property bool open: bar.openPopup === root.popupName

    // Published for the click-catcher.
    readonly property int panelWidth: bodyWidth + notch * 2
    readonly property int panelLeft: Math.max(Theme.barSideMargin + Theme.barRadius, Math.min((root.screen ? root.screen.width : 1920) - Theme.barSideMargin - Theme.barRadius - panelWidth, Math.round(root.anchorX - panelWidth / 2)))

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

    anchors {
        top: true
        left: true
    }

    // The bar reserves an exclusive zone; without ignoring it this would be
    // pushed down by a full bar height.
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    margins {
        top: Theme.barMargin + Theme.barHeight
        left: root.panelLeft
    }

    implicitWidth: panelWidth
    implicitHeight: bodyHeight + Theme.shadowPad
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
            duration: Theme.dur(150)
            easing.type: Easing.OutQuad
        }
    }

    SequentialAnimation {
        id: closeAnim

        // Contents clear first, then the panel retracts into the bar.
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
        width: root.panelWidth
        height: root.bodyHeight + Theme.shadowPad

        PanelOutline {
            anchors.fill: parent
            notch: root.notch
            bodyWidth: root.bodyWidth
            smoothHeight: root.smoothHeight
            reveal: root.reveal
        }

        Item {
            id: body
            x: root.notch
            y: (1 - root.contentFade) * -8
            width: root.bodyWidth
            height: root.bodyHeight
            opacity: root.contentFade
            // Composited once as a texture while animating, rather than alpha-
            // blending every child separately each frame. Dropped again at rest so
            // nothing pays for an offscreen buffer when it is not moving.
            layer.enabled: openAnim.running || closeAnim.running
        }
    }
}
