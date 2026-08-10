import QtQuick
import QtQuick.Shapes
import "root:/"

// A circular 0..1 progress ring. Children are centred inside the ring.
Item {
    id: root

    default property alias centerContent: center.data

    property real value: 0
    // Monochrome by default — gauges never change colour with their value.
    property color accent: Theme.icon
    property color track: Theme.alpha(accent, 0.25)
    property real thickness: Math.max(2, diameter * 0.096)
    // Derived from the pill height so bar rings scale with the bar when the
    // size settings change. Panels that want a fixed size set it explicitly.
    property real diameter: Theme.pillHeight + 2
    // Set false when placing one directly in a Column — vertical anchors
    // break Column layout.
    property bool vcenter: true

    // Centred glyph slot. Sizing it here rather than at each call site is what
    // keeps every ring's symbol identical and properly centred.
    property string glyph: ""
    readonly property int glyphSize: Math.round(diameter * 0.58)

    // Optional concentric inner ring, for gauges tracking two values. Negative
    // means none, so single-value gauges are unaffected.
    property real secondValue: -1
    property color secondAccent: Theme.mauve
    property real ringGap: 3

    readonly property bool dual: secondValue >= 0

    // Clear space inside the innermost ring, for whatever is centred in it.
    readonly property real innerDiameter: ((dual ? secondRadius : radius) - thickness / 2) * 2 - 4
    readonly property real secondClamped: Math.max(0, Math.min(1, secondValue))
    readonly property real secondRadius: radius - thickness - ringGap

    // Below this an arc is shorter than its own round cap and just reads as
    // a stray dot, so it is not drawn at all.
    readonly property real minVisible: 0.02

    // Wide enough that the two arcs read as separate pieces of the ring
    // rather than one circle with a nick out of it. Overridable, because the
    // same angle is a far shorter arc on a small ring than a large one.
    property real gapDegrees: 11

    // With nothing active there is no second arc to separate from, so the
    // track closes into a plain full circle instead of a ring with a nick.
    function trackStart(fraction) {
        return fraction <= 0 ? 0 : -90 + 360 * fraction + root.gapDegrees;
    }

    function trackSweep(fraction) {
        return fraction <= 0 ? 360 : Math.max(0, 360 - 360 * fraction - root.gapDegrees * 2);
    }

    readonly property real clamped: Math.max(0, Math.min(1, value))
    readonly property real radius: (diameter - thickness) / 2

    implicitWidth: diameter
    implicitHeight: diameter
    anchors.verticalCenter: vcenter && parent ? parent.verticalCenter : undefined

    children: [
        Shape {
            anchors.fill: root
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.track
                strokeWidth: root.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: root.diameter / 2
                    centerY: root.diameter / 2
                    radiusX: root.radius
                    radiusY: root.radius
                    startAngle: root.trackStart(root.clamped >= root.minVisible ? root.clamped : 0)
                    sweepAngle: root.trackSweep(root.clamped >= root.minVisible ? root.clamped : 0)

                    Behavior on startAngle {
                        NumberAnimation {
                            duration: Theme.dur(400)
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on sweepAngle {
                        NumberAnimation {
                            duration: Theme.dur(400)
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            ShapePath {
                strokeColor: root.dual ? Theme.alpha(root.secondAccent, 0.25) : "transparent"
                strokeWidth: root.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: root.diameter / 2
                    centerY: root.diameter / 2
                    radiusX: root.dual ? root.secondRadius : 0
                    radiusY: root.dual ? root.secondRadius : 0
                    startAngle: root.trackStart(root.secondClamped >= root.minVisible ? root.secondClamped : 0)
                    sweepAngle: root.dual ? root.trackSweep(root.secondClamped >= root.minVisible ? root.secondClamped : 0) : 0

                    Behavior on startAngle {
                        NumberAnimation {
                            duration: Theme.dur(400)
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on sweepAngle {
                        NumberAnimation {
                            duration: Theme.dur(400)
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            ShapePath {
                // A round cap on a zero-length arc still paints, showing as a
                // stray dot when the value is negligible.
                strokeColor: root.dual && root.secondClamped >= root.minVisible ? root.secondAccent : "transparent"
                strokeWidth: root.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: root.diameter / 2
                    centerY: root.diameter / 2
                    radiusX: root.dual ? root.secondRadius : 0
                    radiusY: root.dual ? root.secondRadius : 0
                    startAngle: -90
                    sweepAngle: root.dual ? 360 * root.secondClamped : 0

                    Behavior on sweepAngle {
                        NumberAnimation {
                            duration: Theme.dur(400)
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            ShapePath {
                strokeColor: root.clamped >= root.minVisible ? root.accent : "transparent"
                strokeWidth: root.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    id: arc
                    centerX: root.diameter / 2
                    centerY: root.diameter / 2
                    radiusX: root.radius
                    radiusY: root.radius
                    startAngle: -90
                    sweepAngle: 360 * root.clamped

                    Behavior on sweepAngle {
                        NumberAnimation {
                            duration: Theme.dur(400)
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        },

        Item {
            id: center
            anchors.fill: root

            Text {
                anchors.centerIn: parent
                visible: root.glyph !== ""
                text: root.glyph
                font.family: Theme.iconFont
                font.pixelSize: root.glyphSize
                color: root.accent
            }
        }
    ]
}
