import QtQuick
import QtQuick.Shapes
import "root:/"

// A small history graph: a bare line with a soft wash falling away beneath it.
Item {
    id: root

    // Values are 0..100, oldest first.
    property var values: []
    property color accent: Theme.icon

    // Two filled traces in one circle compound into a wash, so a secondary
    // series draws its line only.
    property bool filled: true

    // How far the wash spills below the 0% baseline before it dies out.
    property real overshoot: 20

    // When set, the graph spans a circle of this radius and every point is
    // clamped to it, so the trace runs edge to edge of the ring and the wash
    // never spills outside. Cheaper and sharper than masking the item.
    property real circleRadius: 0
    readonly property bool circular: circleRadius > 0

    readonly property int count: values ? values.length : 0

    // Vertical band the data is mapped into, inset from the ring.
    readonly property real inset: 6
    readonly property real bandHalf: circular ? Math.max(1, circleRadius - inset) : height / 2

    function _yFor(value) {
        const level = Math.max(0, Math.min(100, value)) / 100;
        if (!root.circular)
            return root.height - level * root.height;
        return (root.circleRadius + root.bandHalf) - level * root.bandHalf * 2;
    }

    // Vertical half-extent of the circle at a given x.
    function _edgeOffsetAtX(x) {
        const dx = x - root.circleRadius;
        const inside = root.circleRadius * root.circleRadius - dx * dx;
        return inside > 0 ? Math.sqrt(inside) : 0;
    }

    // Horizontal distance from the circle's centre to its edge at height y.
    function _edgeOffsetAt(y) {
        const dy = y - root.circleRadius;
        const inside = root.circleRadius * root.circleRadius - dy * dy;
        return inside > 0 ? Math.sqrt(inside) : 0;
    }

    // The trace runs from the circle's edge at the first sample's height to
    // its edge at the last sample's height, so neither end rises or falls to
    // meet the ring — they meet it flat.
    readonly property var samplePoints: {
        if (root.count < 2)
            return [];

        const ys = [];
        for (let i = 0; i < root.count; ++i)
            ys.push(root._yFor(root.values[i]));

        let x0 = 0;
        let x1 = root.width;
        if (root.circular) {
            const r = root.circleRadius;
            x0 = r - root._edgeOffsetAt(ys[0]);
            x1 = r + root._edgeOffsetAt(ys[ys.length - 1]);
        }

        const pts = [];
        for (let i = 0; i < root.count; ++i) {
            const t = i / (root.count - 1);
            const x = x0 + t * (x1 - x0);
            let y = ys[i];

            if (root.circular) {
                // Vertical room actually available at this x, inset so the
                // stroke never touches the ring itself.
                const half = Math.max(0, root._edgeOffsetAtX(x) - 2);
                const cy = root.circleRadius;
                y = Math.max(cy - half, Math.min(cy + half, y));
            }

            pts.push(Qt.point(x, y));
        }
        return pts;
    }

    // Closed below: a flat floor normally, the circle's lower arc when round.
    readonly property var fillPoints: {
        const pts = root.samplePoints;
        if (pts.length < 2)
            return [];

        if (!root.circular) {
            const floor = root.height + root.overshoot;
            return pts.concat([
                Qt.point(root.width, floor),
                Qt.point(0, floor)
            ]);
        }

        const r = root.circleRadius;
        const xStart = pts[0].x;
        const xEnd = pts[pts.length - 1].x;

        // Closed along the lower arc between the curve's own endpoints only.
        // Extending out to the circle's full width fills the whole lens when
        // the trace sits low, which on the network ring — two stacked
        // sparklines — compounded into a solid wash.
        const arc = [];
        const steps = 24;
        for (let i = 0; i <= steps; ++i) {
            const x = xEnd + (xStart - xEnd) * (i / steps);
            arc.push(Qt.point(x, r + Math.max(0, root._edgeOffsetAtX(x) - 2)));
        }

        return pts.concat(arc);
    }

    Shape {
        // Extends past the item so the wash is not cut off at the baseline.
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.height + root.overshoot
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"

            // Several stops rather than two, so the falloff reads as a smooth
            // glow instead of a visible linear ramp.
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: root.circular ? root.circleRadius * 2 : root.height + root.overshoot

                GradientStop {
                    position: 0.0
                    color: Theme.alpha(root.accent, 0.40)
                }
                GradientStop {
                    position: 0.2
                    color: Theme.alpha(root.accent, 0.26)
                }
                GradientStop {
                    position: 0.4
                    color: Theme.alpha(root.accent, 0.14)
                }
                GradientStop {
                    position: 0.6
                    color: Theme.alpha(root.accent, 0.06)
                }
                GradientStop {
                    position: 0.8
                    color: Theme.alpha(root.accent, 0.02)
                }
                GradientStop {
                    position: 1.0
                    color: Theme.alpha(root.accent, 0.0)
                }
            }

            PathPolyline {
                path: root.filled ? root.fillPoints : []
            }
        }

        // The trace itself — no drop lines at the ends.
        ShapePath {
            strokeColor: root.accent
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: root.samplePoints
            }
        }
    }
}
