import QtQuick
import Quickshell.Services.UPower
import "root:/"

Pill {
    id: root

    required property var bar

    readonly property var device: UPower.displayDevice
    readonly property int percent: device ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: device && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.FullyCharged)
    readonly property bool low: percent <= Settings.batteryMid && !charging
    readonly property bool critical: percent <= Settings.batteryLow && !charging

    // The bar stays monochrome; the critical-low pulse below is the only cue.
    // The popup still uses this to colour its details.
    readonly property color statusColor: critical ? Theme.red : low ? Theme.peach : charging ? Theme.green : Theme.text

    readonly property string remaining: {
        if (!device)
            return "";
        const secs = charging ? device.timeToFull : device.timeToEmpty;
        if (!secs || secs <= 0)
            return charging && percent >= 99 ? "full" : "";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    // Nerd Font battery ramp, 0–100 in tens.
    readonly property string batteryGlyph: {
        if (charging)
            return "󰂄";
        const ramp = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        return ramp[Math.min(10, Math.max(0, Math.round(percent / 10)))];
    }

    visible: device !== null && device.isLaptopBattery
    interactive: false
    accent: Theme.icon
    innerSpacing: 5

    // Number on the left, charge ring on the right — mirrors the CPU/RAM
    // gauges, which read the other way round.
    Caption {
        text: root.percent
        color: Theme.subtext0
        size: 13
        visible: Settings.batteryShowPercent
    }

    // Standalone button — the number beside it is not clickable.
    Item {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: ring.implicitWidth
        implicitHeight: ring.implicitHeight

        CircleGauge {
        // Bar rings are small, so the gap needs a wider angle to read.
        gapDegrees: 20
            id: ring
            anchors.centerIn: parent
            value: root.percent / 100
            glyph: root.batteryGlyph
            opacity: batteryMouse.containsMouse || root.bar.openPopup === "battery" ? 1 : 0.85

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim
                }
            }
        }

        MouseArea {
            id: batteryMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.bar.togglePopup("battery")
        }
    }

    // Pulse when critically low.
    SequentialAnimation on opacity {
        running: root.critical && Settings.batteryFlash
        loops: Animation.Infinite
        alwaysRunToEnd: true

        NumberAnimation {
            to: 0.45
            duration: 900
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            to: 1.0
            duration: 900
            easing.type: Easing.InOutQuad
        }
    }
}
