import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "root:/"

// Battery detail, hanging off the battery widget in the bar.
//
// Most of this comes from UPower's QML binding; the fields it does not carry
// — vendor, technology, voltage, design capacity, cycle count — are read from
// `upower -i` by scripts/battery-info.sh.
PanelShell {
    id: root

    popupName: "battery"
    bodyWidth: 340

    readonly property var device: UPower.displayDevice
    readonly property int percent: root.device ? Math.round(root.device.percentage * 100) : 0

    readonly property bool charging: root.device && (root.device.state === UPowerDeviceState.Charging || root.device.state === UPowerDeviceState.FullyCharged)
    readonly property bool full: root.device && root.device.state === UPowerDeviceState.FullyCharged

    // Four bands, as asked: green / yellow / orange / red. Charging always
    // reads green — the level is on its way up, so a red ring would be a lie.
    readonly property color statusColor: {
        if (root.charging)
            return Theme.green;
        if (root.percent <= Settings.batteryLow)
            return Theme.red;
        if (root.percent <= Settings.batteryMid)
            return Theme.peach;
        if (root.percent <= Settings.batteryHigh)
            return Theme.yellow;
        return Theme.green;
    }

    readonly property string statusLabel: {
        if (!root.device)
            return "No battery";
        switch (root.device.state) {
        case UPowerDeviceState.Charging:
            return "Charging";
        case UPowerDeviceState.Discharging:
            return "Discharging";
        case UPowerDeviceState.FullyCharged:
            return "Fully charged";
        case UPowerDeviceState.PendingCharge:
            return "Pending charge";
        case UPowerDeviceState.PendingDischarge:
            return "Pending discharge";
        case UPowerDeviceState.Empty:
            return "Empty";
        default:
            return "Unknown";
        }
    }

    function _duration(secs) {
        if (!secs || secs <= 0)
            return "";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    readonly property string remaining: {
        if (!root.device)
            return "—";
        if (root.full)
            return "Full";
        const s = root._duration(root.charging ? root.device.timeToFull : root.device.timeToEmpty);
        return s === "" ? "Estimating…" : s;
    }

    // Watts. UPower reports the rate unsigned, so the direction comes from the
    // charge state rather than the sign.
    readonly property real rate: root.device ? Math.abs(root.device.changeRate) : 0

    // ── Fields only `upower -i` carries ──────────────────────────────────
    property var extra: ({})

    function ex(key, fallback) {
        const v = root.extra[key];
        return v === undefined || v === "" ? (fallback ?? "—") : v;
    }

    // Health from the script's own figures when present, else UPower's.
    readonly property real health: {
        const c = parseFloat(root.extra.capacity);
        if (!isNaN(c) && c > 0)
            return c;
        if (root.device && root.device.healthSupported)
            return root.device.healthPercentage;
        return 0;
    }

    onOpenChanged: if (open)
        info.running = true

    // Refreshed while open: rate and voltage move under load.
    Timer {
        running: root.open
        interval: 10000
        repeat: true
        onTriggered: if (!info.running)
            info.running = true
    }

    Process {
        id: info
        command: [`${Quickshell.shellDir}/scripts/battery-info.sh`]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.split("\n")) {
                    const eq = line.indexOf("=");
                    if (eq > 0)
                        out[line.slice(0, eq)] = line.slice(eq + 1);
                }
                root.extra = out;
            }
        }
    }

    bodyHeight: 14 + 132 + 14 + detailGrid.implicitHeight + 14 + 18 + 40 + 14

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 0

        // ── Ring + headline ──────────────────────────────────────────────
        Item {
            width: parent.width
            height: 132

            CircleGauge {
                id: ring

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                vcenter: false
                diameter: 118
                thickness: 7
                value: root.percent / 100
                accent: root.statusColor

                // Flash below 15% — but not while charging, when the level is
                // already recovering and a flashing ring is just noise.
                SequentialAnimation on opacity {
                    running: root.percent <= Settings.batteryLow && !root.charging && Settings.batteryFlash
                    loops: Animation.Infinite
                    alwaysRunToEnd: true

                    NumberAnimation {
                        to: 0.35
                        duration: 620
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        to: 1
                        duration: 620
                        easing.type: Easing.InOutQuad
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: -2

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 1

                        Caption {
                            vcenter: false
                            text: root.percent
                            color: root.statusColor
                            size: 30
                            font.bold: true
                        }

                        Caption {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                            vcenter: false
                            text: "%"
                            color: root.statusColor
                            size: 13
                            font.bold: true
                        }
                    }

                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        vcenter: false
                        text: root.charging ? "󰂄" : "󰁹"
                        color: Theme.overlay1
                        size: 13
                    }
                }
            }

            Column {
                anchors.left: ring.right
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Caption {
                    vcenter: false
                    width: parent.width
                    text: root.statusLabel
                    color: root.statusColor
                    size: 15
                    font.bold: true
                    elide: Text.ElideRight
                }

                Caption {
                    vcenter: false
                    width: parent.width
                    text: root.full ? "" : root.charging ? `${root.remaining} until full` : `${root.remaining} remaining`
                    visible: text !== ""
                    color: Theme.subtext0
                    size: 12
                    elide: Text.ElideRight
                }

                Caption {
                    vcenter: false
                    width: parent.width
                    text: `${root.rate.toFixed(2)} W ${root.charging ? "in" : "draw"}`
                    color: Theme.overlay1
                    size: 11
                }

                Caption {
                    vcenter: false
                    width: parent.width
                    text: UPower.onBattery ? "On battery" : "Plugged in"
                    color: Theme.overlay1
                    size: 11
                }
            }
        }

        Item {
            width: 1
            height: 14
        }

        // ── Everything the daemons will tell us ──────────────────────────
        Grid {
            id: detailGrid

            width: parent.width
            columns: 2
            columnSpacing: 10
            rowSpacing: 5

            readonly property real cellWidth: (detailGrid.width - detailGrid.columnSpacing) / 2

            Detail {
                label: "Health"
                value: root.health > 0 ? `${root.health.toFixed(1)}%` : "—"
                accent: root.health >= 80 ? Theme.green : root.health >= 60 ? Theme.yellow : root.health >= 40 ? Theme.peach : Theme.red
            }
            Detail {
                label: "Cycles"
                value: root.ex("cycles")
            }
            Detail {
                label: "Energy"
                value: root.device ? `${root.device.energy.toFixed(1)} Wh` : "—"
            }
            Detail {
                label: "Capacity"
                value: root.device ? `${root.device.energyCapacity.toFixed(1)} Wh` : "—"
            }
            Detail {
                label: "Design"
                value: root.extra.design ? `${parseFloat(root.extra.design).toFixed(1)} Wh` : "—"
            }
            Detail {
                label: "Voltage"
                value: root.extra.voltage ? `${parseFloat(root.extra.voltage).toFixed(2)} V` : "—"
            }
            Detail {
                label: "Technology"
                value: root.ex("technology").replace("lithium-", "Li-")
            }
            Detail {
                label: "Vendor"
                value: root.ex("vendor")
            }
            Detail {
                label: "Model"
                value: root.ex("model")
            }
            Detail {
                label: "Serial"
                value: root.ex("serial")
            }
        }

        Item {
            width: 1
            height: 14
        }

        // ── Power profile ────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 18

            Caption {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Power mode"
                color: Theme.icon
                size: 12
                font.bold: true
            }

            // Firmware sometimes refuses a profile (thermal or on battery);
            // saying so beats a button that silently does nothing.
            Caption {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
                text: PowerProfiles.degradationReason === PerformanceDegradationReason.LapDetected ? "lap detected" : "thermally limited"
                color: Theme.peach
                size: 10
            }
        }

        Item {
            width: 1
            height: 6
        }

        Row {
            width: parent.width
            spacing: 5

            ProfileButton {
                glyph: "󰾆"
                label: "Saver"
                profile: PowerProfile.PowerSaver
            }
            ProfileButton {
                glyph: "󰾅"
                label: "Balanced"
                profile: PowerProfile.Balanced
            }
            ProfileButton {
                glyph: "󰓅"
                label: "Performance"
                profile: PowerProfile.Performance
                // Not every machine offers a performance profile.
                enabled: PowerProfiles.hasPerformanceProfile
            }
        }
    }

    // ── Local components ─────────────────────────────────────────────────
    component Detail: Item {
        property string label: ""
        property string value: ""
        property color accent: Theme.subtext0

        width: detailGrid.cellWidth
        height: 17

        Caption {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: Theme.overlay0
            size: 11
        }

        Caption {
            anchors.right: parent.right
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: parent.value
            color: parent.accent
            size: 11
            elide: Text.ElideRight
        }
    }

    component ProfileButton: Rectangle {
        id: pb

        property string glyph: ""
        property string label: ""
        property int profile: 0

        readonly property bool selected: PowerProfiles.profile === pb.profile

        width: (parent.width - 10) / 3
        height: 40
        radius: 11
        opacity: pb.enabled ? 1 : 0.4
        color: pb.selected ? Theme.alpha(Theme.icon, 0.16) : pbMouse.containsMouse && pb.enabled ? Theme.surface0 : Theme.alpha(Theme.surface0, 0.5)

        Behavior on color {
            ColorAnimation {
                duration: Theme.anim
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 1

            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                vcenter: false
                text: pb.glyph
                color: pb.selected ? Theme.icon : Theme.subtext0
                size: 14
            }

            Caption {
                anchors.horizontalCenter: parent.horizontalCenter
                vcenter: false
                text: pb.label
                color: pb.selected ? Theme.icon : Theme.subtext0
                size: 9
            }
        }

        MouseArea {
            id: pbMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: pb.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: PowerProfiles.profile = pb.profile
        }
    }
}
