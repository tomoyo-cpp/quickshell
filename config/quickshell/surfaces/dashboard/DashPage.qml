import QtQuick
import "root:/"

// Base for a Dashboard page: fades in when selected, and reports the height
// it wants so the panel can shrink to fit its contents.
Item {
    id: pg

    default property alias pageContent: pgInner.data
    required property int pageIndex

    // The Dashboard this page belongs to: supplies the selected page index,
    // and receives the height this page wants.
    required property var dash

    // Height this page actually needs. Left at 0 the page fills the panel
    // as before, so existing pages are unaffected; set it and the panel
    // shrinks to fit when this page is showing.
    property real contentHeight: 0

    signal shown

    anchors.fill: parent
    visible: opacity > 0
    opacity: pg.dash.page === pg.pageIndex ? 1 : 0

    onOpacityChanged: if (opacity === 1)
        pg.shown()

    Binding {
        target: pg.dash
        property: "activeContentHeight"
        value: pg.contentHeight
        when: pg.dash.page === pg.pageIndex
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.dur(140)
        }
    }

    children: [
        Item {
            id: pgInner
            anchors.fill: pg
        }
    ]
}
