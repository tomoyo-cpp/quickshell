import QtQuick
import "root:/"

// Minimal 0..1 slider. Emits `moved` while dragging; the owner writes back.
Item {
    id: root

    property real value: 0
    property color accent: Theme.blue

    // Commit on release rather than continuously.
    //
    // For volume, writing on every mouse-move is what you want. For a seek bar
    // it is not: each write repositions the decoder, and at one per mouse-move
    // frame the audio audibly stutters while dragging. With this set the knob
    // still follows the cursor — from `dragValue` — but `moved` fires once,
    // when the drag ends.
    property bool commitOnRelease: false

    // Where the drag currently is, whether or not it has been committed. Owners
    // can show this to preview the position being scrubbed to.
    property real dragValue: 0
    readonly property bool dragging: drag.pressed

    signal moved(real value)

    // While scrubbing, the knob tracks the drag instead of the owner's value —
    // the owner has not been told about it yet.
    readonly property real shown: root.dragging && root.commitOnRelease ? root.dragValue : root.value
    readonly property real clamped: Math.max(0, Math.min(1, root.shown))

    // The knob is centred on its position, so at 0 and 1 half of it would hang
    // past the track and get clipped. Travel is inset by half the knob at each
    // end instead. Based on the *hover* size, not the current one, so growing
    // on hover does not also shift the knob along the track.
    readonly property real knobMax: 14
    readonly property real travel: Math.max(1, track.width - knobMax)
    readonly property real knobX: knobMax / 2 + travel * root.clamped

    implicitHeight: 18

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.surface1

        Rectangle {
            // Ends under the knob's centre rather than at the raw fraction, or
            // the fill and the knob disagree at both extremes.
            width: root.knobX
            height: parent.height
            radius: 3
            color: root.accent

            Behavior on width {
                enabled: !drag.pressed
                NumberAnimation {
                    duration: Theme.dur(110)
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Rectangle {
        x: root.knobX - width / 2
        anchors.verticalCenter: parent.verticalCenter

        // Must match the fill's Behavior exactly, or the knob outruns it.
        Behavior on x {
            enabled: !drag.pressed
            NumberAnimation {
                duration: Theme.dur(110)
                easing.type: Easing.OutCubic
            }
        }
        width: drag.pressed || drag.containsMouse ? 14 : 11
        height: width
        radius: width / 2
        color: Theme.text
        border.width: 2
        border.color: root.accent

        Behavior on width {
            NumberAnimation {
                duration: Theme.anim
            }
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // Inverse of knobX, so a click lands the knob under the cursor.
        function valueAt(x) {
            return Math.max(0, Math.min(1, (x - root.knobMax / 2) / root.travel));
        }

        function emitAt(x) {
            const v = valueAt(x);
            root.dragValue = v;
            if (!root.commitOnRelease)
                root.moved(v);
        }

        onPressed: event => emitAt(event.x)
        onPositionChanged: event => {
            if (pressed)
                emitAt(event.x);
        }
        onReleased: {
            if (root.commitOnRelease)
                root.moved(root.dragValue);
        }
        // A drag cancelled by the window losing the grab should not seek.
        onCanceled: {
            if (root.commitOnRelease)
                root.dragValue = root.value;
        }
    }
}
