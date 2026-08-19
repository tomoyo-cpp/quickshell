import QtQuick
import QtQuick.Shapes
import "root:/"

// The silhouette every dropdown panel is drawn as: a rounded body hanging
// below the bar, with a notch cut into each top corner so the panel appears
// to flow out of the bar strip rather than sit under it.
//
// Traced by hand as a single filled path rather than composed from rounded
// rectangles, because the notches are concave — an inward curve no
// Rectangle radius can express.
//
// This was duplicated verbatim in PanelShell, ClipboardPanel and
// NotificationPanel. The two latter panels are their own PanelWindows rather
// than PanelShell subclasses, so they had no base class to inherit it from.
Shape {
    id: outlineShape

    // Radius of the concave corner notches.
    required property int notch
    // Width of the panel body, excluding both notches.
    required property int bodyWidth
    // Height the body is animating toward.
    required property real smoothHeight
    // 0 while closed, 1 when fully open. Drives the reveal.
    required property real reveal

    preferredRendererType: Shape.CurveRenderer

    readonly property int n: outlineShape.notch
    readonly property int w: outlineShape.bodyWidth
    readonly property real minH: outlineShape.notch + Theme.popupRadius + 1
    // Interpolated from the minimum, not clamped to it: the clamp pinned h
    // flat and then released it at the curve's steepest point, which showed
    // as a kink partway through.
    readonly property real h: outlineShape.minH + Math.max(0, outlineShape.smoothHeight - outlineShape.minH) * outlineShape.reveal
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

        // Top-left notch, curving inward from the bar.
        PathArc {
            x: outline.n
            y: outline.n
            radiusX: outline.n
            radiusY: outline.n
            direction: PathArc.Clockwise
        }
        // Down the left edge, then round the bottom-left corner.
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
        // Across the bottom, then round the bottom-right corner.
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
        // Up the right edge, then the top-right notch.
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
        // Back along the top, under the bar.
        PathLine {
            x: 0
            y: 0
        }
    }
}
