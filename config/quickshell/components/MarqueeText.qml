import QtQuick
import "root:/"

// Text that scrolls when it is too long to fit. Short text just sits still.
//
// Changing the text fades the old string out, swaps it, then fades the new one
// in, while the width eases between the two. A straight reassignment snapped
// the item to its new width mid-word, which shoved everything to its right
// along the bar in one frame.
Item {
    id: root

    property string text: ""
    property color color: Theme.subtext1
    property real size: Theme.fontSize
    property int gap: 40
    property real pixelsPerSecond: Settings.mediaScrollSpeed

    // What is actually drawn. Lags `text` by the fade-out, so the swap lands
    // while nothing is on screen to be seen changing. Everything downstream —
    // the metrics, the scroll, both visible copies — reads this rather than
    // `text`, or the width would jump ahead of the letters.
    property string displayText: ""

    readonly property bool overflowing: metrics.implicitWidth > root.width

    implicitWidth: Math.min(metrics.implicitWidth, Settings.mediaMaxWidth)
    implicitHeight: metrics.implicitHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    clip: true

    // Eased rather than stepped, so a longer or shorter title slides the items
    // beside it along instead of teleporting them.
    Behavior on implicitWidth {
        enabled: Settings.animationsEnabled
        NumberAnimation {
            duration: Theme.dur(220)
            easing.type: Easing.OutCubic
        }
    }

    onTextChanged: {
        if (root.displayText === root.text)
            return;
        // Nothing to cross-fade from on the first fill, and no point staging
        // the swap when animations are off.
        if (root.displayText === "" || !Settings.animationsEnabled) {
            root.displayText = root.text;
            return;
        }
        swap.restart();
    }

    Component.onCompleted: root.displayText = root.text

    SequentialAnimation {
        id: swap

        NumberAnimation {
            target: viewport
            property: "opacity"
            to: 0
            duration: Theme.dur(110)
            easing.type: Easing.InQuad
        }
        // Reads `text` at the moment it runs, not when the animation was
        // queued, so a burst of track changes settles on the last one.
        ScriptAction {
            script: root.displayText = root.text
        }
        NumberAnimation {
            target: viewport
            property: "opacity"
            to: 1
            duration: Theme.dur(170)
            easing.type: Easing.OutQuad
        }
    }

    // Measures the natural width without ever being drawn.
    Caption {
        id: metrics
        vcenter: false
        visible: false
        text: root.displayText
        size: root.size
    }

    Item {
        id: viewport
        anchors.fill: parent

        // Two copies chase each other so the loop has no visible seam.
        Row {
            id: strip
            spacing: root.gap
            y: (viewport.height - height) / 2

            Caption {
                vcenter: false
                text: root.displayText
                color: root.color
                size: root.size
            }

            Caption {
                vcenter: false
                visible: root.overflowing
                text: root.displayText
                color: root.color
                size: root.size
            }
        }

        // Restart whenever the track or the available width changes.
        NumberAnimation {
            id: scroll
            target: strip
            property: "x"
            from: 0
            to: -(metrics.implicitWidth + root.gap)
            duration: Math.max(1, (metrics.implicitWidth + root.gap) / root.pixelsPerSecond * 1000)
            loops: Animation.Infinite
            // Held off through the swap so it restarts from `from: 0` for the
            // new title. Stopping it declaratively rather than calling stop()
            // keeps the binding intact — a manual stop/start would sever it and
            // scrolling would never resume on a later width change.
            running: root.overflowing && !swap.running
        }

        // Also pinned during the swap, or the incoming title fades in at
        // whatever offset the outgoing one had scrolled to.
        Binding {
            target: strip
            property: "x"
            value: 0
            when: !root.overflowing || swap.running
        }
    }
}
