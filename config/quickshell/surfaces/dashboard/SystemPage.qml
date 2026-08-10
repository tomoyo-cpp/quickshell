import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import "root:/"

DashPage {
    id: page



    Row {
        anchors.fill: parent
        spacing: 16

        // ── Left: gauges, disk, stats, controls ──────────
        Column {
            width: 350
            spacing: 10

            // Four rings across: load, memory, network, power.
            Row {
                width: parent.width
                spacing: 8

                readonly property real cell: (width - spacing * 3) / 4

                SysGauge {
                    width: parent.cell
                    diameter: 74
                    label: "CPU"
                    value: SysMon.cpu
                    readout: `${SysMon.cpu}%`
                    history: SysMon.cpuHistory
                }
                SysGauge {
                    width: parent.cell
                    diameter: 74
                    label: "Memory"
                    value: SysMon.memory
                    readout: `${SysMon.memory}%`
                    history: SysMon.memoryHistory
                }
                SysGauge {
                    width: parent.cell
                    diameter: 74
                    label: "Network"
                    // Download outer, upload inner.
                    value: SysMon.rxRate / SysMon.netScale * 100
                    accent: Theme.blue
                    secondValue: SysMon.txRate / SysMon.netScale
                    secondAccent: Theme.mauve
                    readout: SysMon.formatRate(SysMon.rxRate)
                    readoutSize: 10
                    readoutColor: Theme.blue
                    readoutSecond: SysMon.formatRate(SysMon.txRate)
                    readoutSecondColor: Theme.mauve
                    history: SysMon.rxPercentHistory
                    secondHistory: SysMon.txPercentHistory
                }
                SysGauge {
                    width: parent.cell
                    diameter: 74
                    label: page.dash.batteryCharging ? "Charging" : "Battery"
                    value: page.dash.batteryPercent
                    accent: page.dash.batteryColor
                    readout: `${page.dash.batteryPercent}%`
                    readoutColor: page.dash.batteryColor
                    // Stacked into the same fixed-height block
                    // the network ring uses, so adding this
                    // moves nothing.
                    readoutSecond: page.dash.batteryRemainingShort
                    readoutSecondSize: 9
                    readoutSecondColor: Theme.overlay1
                }
            }

            // ── Disk ─────────────────────────────────────
            Column {
                width: parent.width
                spacing: 5

                Item {
                    width: parent.width
                    height: 14

                    Caption {
                        anchors.left: parent.left
                        text: "Disk"
                        color: Theme.subtext0
                        size: 11
                    }

                    Caption {
                        anchors.right: parent.right
                        text: `${SysMon.disk}% \u00b7 ${SysMon.formatSize(SysMon.diskFreeKb)} free`
                        color: Theme.subtext0
                        size: 11
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.surface1

                    Rectangle {
                        width: parent.width * Math.min(1, SysMon.disk / 100)
                        height: parent.height
                        radius: 3
                        color: SysMon.disk >= 90 ? Theme.red : SysMon.disk >= 75 ? Theme.peach : Theme.icon

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.dur(300)
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surface0
            }

            // ── Stats, two per line ──────────────────────
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 14
                rowSpacing: 1

                readonly property real cell: (width - columnSpacing) / 2

                InfoRow {
                    width: parent.cell
                    glyph: "\udb81\udd0f"
                    label: "CPU temp"
                    value: SysMon.temperature > 0 ? `${SysMon.temperature}\u00b0C` : "\u2014"
                    accent: SysMon.temperature >= 85 ? Theme.red : SysMon.temperature >= 70 ? Theme.peach : Theme.text
                }
                InfoRow {
                    width: parent.cell
                    glyph: "\udb81\udcc5"
                    label: "Clock"
                    value: SysMon.cpuMhz > 0 ? `${(SysMon.cpuMhz / 1000).toFixed(2)} GHz` : "\u2014"
                }
                InfoRow {
                    width: parent.cell
                    glyph: "\udb80\ude9a"
                    label: "Load"
                    value: SysMon.load1.toFixed(2)
                }
                InfoRow {
                    width: parent.cell
                    glyph: "\udb80\udc3b"
                    label: "Processes"
                    value: `${SysMon.processes}`
                }
                InfoRow {
                    width: parent.cell
                    glyph: "\udb80\udf5b"
                    label: "Free RAM"
                    value: SysMon.formatSize(SysMon.memAvailKb)
                }
                InfoRow {
                    width: parent.cell
                    glyph: "\udb81\udce1"
                    label: "Swap"
                    value: `${SysMon.swap}%`
                    accent: SysMon.swap >= 50 ? Theme.peach : Theme.text
                }
                InfoRow {
                    width: parent.cell
                    glyph: "\udb81\ude2c"
                    label: "Threads"
                    value: `${SysMon.threads}`
                }
                InfoRow {
                    width: parent.cell
                    glyph: "\udb80\udd50"
                    label: "Uptime"
                    value: SysMon.uptimeText
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surface0
            }

            // ── Display controls ─────────────────────────
            SliderRow {
                label: "\udb80\udce0  Brightness"
                readout: `${Backlight.percent}%`
                dimmed: !Backlight.available
                value: Backlight.percent / 100
                onMoved: v => Backlight.set(Math.round(v * 100))
            }

            Item {
                width: parent.width
                height: 26

                Caption {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\udb84\udd04  Night light"
                    color: NightLight.active ? Theme.subtext0 : Theme.overlay0
                    size: 11
                }

                Caption {
                    anchors.right: nightSwitch.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: NightLight.active
                    text: `${Settings.nightTemp}K`
                    color: Theme.overlay1
                    size: 10
                }

                ToggleSwitch {
                    id: nightSwitch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    checked: NightLight.active
                    onToggled: NightLight.toggle()
                }
            }
        }

        VDivider {}

        // ── Right: processes ─────────────────────────────
        Column {
            width: 300
            spacing: 8

            Item {
                width: parent.width
                height: 22

                Caption {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Processes"
                    color: Theme.icon
                    font.bold: true
                    size: 13
                }

                Row {
                    anchors.right: parent.right
                    // Clear of the column edge, matching the
                    // gutter the list below reserves.
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    SortChip {
                        label: "CPU"
                        key: "cpu"
                    }
                    SortChip {
                        label: "RAM"
                        key: "mem"
                    }
                    SortChip {
                        label: "I/O"
                        key: "io"
                    }
                }
            }

            Item {
                width: parent.width
                height: 14

                Caption {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    text: "name"
                    color: Theme.overlay0
                    size: 9
                }
                Caption {
                    anchors.right: parent.right
                    anchors.rightMargin: 42
                    text: "cpu \u00b7 ram \u00b7 i/o"
                    color: Theme.overlay0
                    size: 9
                }
            }

            Item {
                width: parent.width
                height: pages.height - 74

                ScrollTrack {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    view: procList
                }

                ListView {
                    id: procList

                    anchors.fill: parent
                    // Clear of the scroll track on the right,
                    // and off the panel edge on the left.
                    anchors.rightMargin: 12
                    anchors.leftMargin: 2
                    clip: true
                    spacing: 2
                    model: Procs.sorted
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: proc
                        required property var modelData

                        width: ListView.view.width
                        height: 34
                        radius: 8
                        color: procMouse.containsMouse ? Theme.alpha(Theme.surface0, 0.8) : "transparent"

                        MouseArea {
                            id: procMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        // vcenter must be off on both: a
                        // Caption anchors its own vertical
                        // centre by default, which overrode
                        // these and stacked them on top of
                        // each other.
                        Caption {
                            vcenter: false
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.right: loadCol.left
                            anchors.rightMargin: 10
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            text: proc.modelData.name
                            color: Theme.text
                            size: 11
                            elide: Text.ElideRight
                        }

                        Caption {
                            vcenter: false
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            text: proc.modelData.pid
                            color: Theme.overlay0
                            size: 9
                        }

                        // Bars rather than three columns of
                        // digits: relative load is the thing
                        // being read here.
                        Column {
                            id: loadCol

                            anchors.right: killBtn.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            MiniBar {
                                accent: Theme.icon
                                fraction: Math.min(1, proc.modelData.cpu / 100)
                                text: `${proc.modelData.cpu}%`
                            }
                            MiniBar {
                                accent: Theme.mauve
                                fraction: Math.min(1, proc.modelData.mem / 25)
                                text: SysMon.formatSize(proc.modelData.rss)
                            }
                            MiniBar {
                                accent: Theme.blue
                                fraction: Math.min(1, proc.modelData.io / 5242880)
                                text: proc.modelData.io > 0 ? SysMon.formatRate(proc.modelData.io) : "\u2014"
                            }
                        }

                        Rectangle {
                            id: killBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            radius: 10
                            opacity: procMouse.containsMouse || killMouse.containsMouse ? 1 : 0
                            color: killMouse.containsMouse ? Theme.alpha(Theme.red, 0.3) : "transparent"

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.anim
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\udb80\udd56"
                                font.family: Theme.iconFont
                                font.pixelSize: 10
                                color: killMouse.containsMouse ? Theme.red : Theme.overlay1
                            }

                            MouseArea {
                                id: killMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // SIGTERM, not SIGKILL: give
                                // it the chance to save.
                                onClicked: Procs.kill(proc.modelData.pid)
                            }
                        }
                    }
                }

                Caption {
                    anchors.centerIn: parent
                    vcenter: false
                    visible: Procs.list.length === 0
                    text: "Sampling\u2026"
                    color: Theme.overlay0
                    size: 11
                }
            }
        }
    }
}
