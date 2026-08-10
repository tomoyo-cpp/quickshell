import QtQuick
import "root:/"

// Scrollbar for a Flickable or ListView.
//
// Declared as a *sibling* of the view, anchored over its frame, rather than
// inside it. A child of a ListView is reparented to the view and its
// coordinate space is easy to get wrong; a sibling is unambiguous.
//
// The track spans the whole frame at a constant size, so the control reads the
// same whatever the list is doing; only the thumb changes.
Rectangle {
    id: root

    required property var view

    property int thickness: 3
    property int minThumb: 24

    readonly property bool needed: root.view && root.view.contentHeight > root.view.height
    readonly property real span: Math.max(1, root.view ? root.view.contentHeight - root.view.height : 1)

    // A ListView's top is originY, not 0 — it drifts as items are added at the
    // front, which cliphist does on every new clip. Measuring contentY from
    // zero left the thumb short of the top of its track.
    readonly property real offset: root.view ? root.view.contentY - root.view.originY : 0

    width: root.thickness
    radius: root.thickness / 2
    color: Theme.alpha(Theme.surface2, 0.55)
    visible: root.needed
    opacity: root.needed ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.anim
        }
    }

    Rectangle {
        id: thumb

        width: parent.width
        radius: parent.radius
        color: Theme.alpha(Theme.icon, 0.6)

        // Proportional, but never so small it cannot be seen or grabbed.
        height: root.needed ? Math.max(root.minThumb, root.height * (root.view.height / root.view.contentHeight)) : 0

        // Clamped into the track: a Flickable can overshoot its own bounds
        // during a flick, which otherwise drives the thumb past either end.
        y: root.needed ? Math.max(0, Math.min(root.height - thumb.height, (root.offset / root.span) * (root.height - thumb.height))) : 0
    }
}
