import QtQuick
import QtQuick.Effects
import "root:/"

// An image with rounded corners.
//
// Qt Quick's `clip` is a rectangular scissor, so a radius on a parent does not
// round the image inside it — the corners need a mask layer instead.
Item {
    id: root

    property alias source: img.source
    property alias status: img.status
    property int corner: 9
    // Fit rather than crop: when the box is sized from `aspect` the two are
    // identical, and when it is not, letterboxing beats cutting the picture.
    property int mode: Image.PreserveAspectFit

    // Decode width. Deliberately NOT derived from `width`: consumers size
    // themselves from `ready`, so width → sourceSize → load → status → ready
    // → width is a binding loop.
    property int decodeWidth: 320

    readonly property bool ready: img.status === Image.Ready

    // The loaded image's own width:height. Consumers size their box from this
    // so a screenshot is shown whole rather than cropped to a fixed height.
    // 16/9 until it loads, which is what a screenshot almost always is.
    readonly property real aspect: img.status === Image.Ready && img.implicitHeight > 0 ? img.implicitWidth / img.implicitHeight : 16 / 9

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            radius: root.corner
            color: "black"
        }
    }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
        }

        Image {
            id: img
            anchors.fill: parent
            fillMode: root.mode
            asynchronous: true
            // Decode small: a full screenshot at native resolution for a
            // 96px strip is pure waste.
            sourceSize.width: root.decodeWidth
        }
    }
}
