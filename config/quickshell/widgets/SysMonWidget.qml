import QtQuick
import "root:/"

// CPU and memory load as two small rings.
Pill {
    id: root

    required property var bar

    // System is page 0 now that Overview is gone.
    active: bar.openPopup === "dashboard" && bar.dashboardSource === "sysmon"
    innerSpacing: 10
    padding: 10

    onClicked: bar.openDashboardNamed("system", "sysmon")

    Gauge {
        percent: SysMon.cpu
        glyph: "󰻠"
    }

    Gauge {
        percent: SysMon.memory
        // Font Awesome "memory", U+EFC5.
        glyph: ""
    }

    component Gauge: Row {
        id: g

        // Rings are deliberately monochrome — no load-based colour shifts.
        readonly property color accent: Theme.icon
        property int percent: 0
        property string glyph: ""

        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        CircleGauge {
        // Bar rings are small, so the gap needs a wider angle to read.
        gapDegrees: 20
            value: g.percent / 100
            accent: g.accent
            glyph: g.glyph
        }

        Caption {
            text: g.percent
            color: Theme.subtext0
            size: 13
        }
    }
}
