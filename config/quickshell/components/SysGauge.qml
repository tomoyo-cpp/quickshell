import QtQuick
import "root:/"

Column {
    id: sg

    property string label: ""
    property real value: 0
    property string readout: ""
    property var history: []
    property color accent: Theme.icon
    property int readoutSize: 14
    property color readoutColor: Theme.icon
    property color labelColor: Theme.overlay1

    // Optional second figure shown on the same line, for gauges tracking
    // two values.
    property string readoutSecond: ""
    property color readoutSecondColor: Theme.icon
    // Its own size, so a headline figure can stay large while the line
    // under it stays subordinate. Both still have to fit the fixed 26px
    // block below, or the label under the ring would shift.
    property int readoutSecondSize: sg.readoutSize

    // Optional second value, drawn as a concentric inner ring instead of
    // a second trace — two overlapping fills inside one circle never read
    // cleanly.
    property real secondValue: -1
    property color secondAccent: Theme.mauve
    property var secondHistory: []

    // Settable so a row of four can be sized to leave gaps between them.
    property int diameter: 88

    spacing: 6

    CircleGauge {
        id: gaugeRing

        anchors.horizontalCenter: parent.horizontalCenter
        vcenter: false
        diameter: sg.diameter
        thickness: 5
        value: sg.value / 100
        accent: sg.accent
        secondValue: sg.secondValue
        secondAccent: sg.secondAccent

        // Sized to whatever ring is innermost, so a dual gauge keeps its
        // graph inside the smaller circle rather than under the rings.
        Sparkline {
            anchors.centerIn: parent
            width: gaugeRing.innerDiameter
            height: width
            circleRadius: width / 2
            values: sg.history
            accent: sg.accent
        }

        // Second series, line only — a second fill would compound with
        // the first into a solid wash.
        Sparkline {
            anchors.centerIn: parent
            width: gaugeRing.innerDiameter
            height: width
            circleRadius: width / 2
            visible: sg.secondHistory.length > 1
            filled: false
            values: sg.secondHistory
            accent: sg.secondAccent
        }
    }

    // Fixed height for every gauge, so the label below never shifts —
    // whether the readout is one line or two, and however wide the
    // figures get.
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: sg.parent ? sg.width : 100
        height: 26

        Caption {
            anchors.centerIn: parent
            visible: sg.readoutSecond === ""
            text: sg.readout
            color: sg.readoutColor
            size: sg.readoutSize
            font.bold: true
        }

        // Stacked rather than side by side: two figures on one line kept
        // changing width and shoving the neighbouring gauges about.
        Column {
            anchors.centerIn: parent
            visible: sg.readoutSecond !== ""
            spacing: 1

            Caption {
                anchors.horizontalCenter: parent.horizontalCenter
                vcenter: false
                text: sg.readout
                color: sg.readoutColor
                size: sg.readoutSize
                font.bold: true
            }

            Caption {
                anchors.horizontalCenter: parent.horizontalCenter
                vcenter: false
                // Bounded so a long figure cannot spill sideways into the
                // neighbouring gauge.
                width: Math.min(implicitWidth, sg.diameter - 16)
                horizontalAlignment: Text.AlignHCenter
                text: sg.readoutSecond
                color: sg.readoutSecondColor
                size: sg.readoutSecondSize
                font.bold: true
            }
        }
    }

    Caption {
        anchors.horizontalCenter: parent.horizontalCenter
        vcenter: false
        text: sg.label
        color: sg.labelColor
        size: 11
    }
}
