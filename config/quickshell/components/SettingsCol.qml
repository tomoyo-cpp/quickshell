import QtQuick
import "root:/"

Column {
    id: sc

    property string title: ""
    property string group: ""
    property bool showReset: true

    // Set by the page that lays these out; the column count varies per tab.
    property real colWidth: 200

    default property alias body: inner.data

    width: sc.colWidth
    spacing: 6

    Item {
        width: parent.width
        height: 20

        Caption {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: sc.title
            color: Theme.icon
            font.bold: true
            size: 13
        }

        ChipButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: sc.showReset && sc.group !== ""
            label: "Reset"
            accent: Theme.red
            onTriggered: Settings.resetGroup(sc.group)
        }
    }

    Column {
        id: inner
        width: parent.width
        spacing: 6
    }
}

// A labelled bar, for the process rows.
