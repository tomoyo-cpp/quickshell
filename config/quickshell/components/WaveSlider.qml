import QtQuick
import QtQuick.Shapes
import "root:/"

// Volume control drawn as a travelling sine wave. The wave fills the range
// left of the cursor and a flat track continues to the right. Amplitude
// follows the set volume and swells with the live audio peak.
Item {
    id: root

    property real value: 0     // 0..1, the volume
    property real level: 0     // 0..1, live peak from the sink
    property color accent: Theme.icon

    signal moved(real value)

    readonly property real clamped: Math.max(0, Math.min(1, value))

    implicitHeight: 34

    readonly property int sampleCount: 160

    // Fixed amplitude and wavelength: the wave keeps the same shape at every
    // volume, only its length changes as the cursor moves.
    readonly property real amplitude: (height / 2 - 4) * 0.45

    // Ten full cycles across the track, so the wave stays the same shape at
    // any width.
    readonly property real frequency: Math.PI * 20 / Math.max(1, root.width)

    // Travels leftward. A moving phase shifts the zero crossings, so the
    // curve alone would not stay on the knob; `pin` below cancels its value
    // at the cursor and decays away, keeping the join exact.
    property real phase: 0

    // Exponential falloff, so the correction never reads as a straight
    // run-in the way a linear taper did.
    readonly property real pinDecay: 14

    NumberAnimation on phase {
        from: 0
        to: Math.PI * 2
        duration: 2200
        loops: Animation.Infinite
        running: root.visible
    }

    readonly property real cursorX: root.width * root.clamped

    readonly property var points: {
        const pts = [];
        const mid = root.height / 2;
        const end = root.cursorX;
        if (end <= 0)
            return pts;

        for (let i = 0; i < root.sampleCount; ++i) {
            const x = end * (i / (root.sampleCount - 1));
            const wave = Math.sin((x - end) * root.frequency + root.phase);
            const pin = Math.sin(root.phase) * Math.exp(-(end - x) / root.pinDecay);
            pts.push(Qt.point(x, mid + (wave - pin) * root.amplitude));
        }
        return pts;
    }

    // Flat track for the unfilled remainder.
    Rectangle {
        x: root.width * root.clamped
        width: Math.max(0, root.width - x)
        height: 2
        radius: 1
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.alpha(root.accent, 0.22)
    }

    // The wave itself only exists left of the cursor.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.points.length > 1

        ShapePath {
            strokeColor: root.accent
            strokeWidth: 2.6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: root.points
            }
        }
    }

    // Cursor.
    Rectangle {
        x: root.width * root.clamped - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: drag.pressed || drag.containsMouse ? 13 : 10
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
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function emitAt(x) {
            root.moved(Math.max(0, Math.min(1, x / root.width)));
        }

        onPressed: event => emitAt(event.x)
        onPositionChanged: event => {
            if (pressed)
                emitAt(event.x);
        }
    }
}
