import QtQuick
import Quickshell
import "root:/"

// Appearance: the look of the bar, and how far that look is pushed out into
// the rest of the session.
//
// Two wide columns of stacked sections rather than three narrow ones. Three
// columns left each only ~200px, which is what forced the accent swatches to
// overlap; at ~314px a section can hold a full row of swatches and a slider
// with its readout without either being cramped.
DashPage {
    id: page

    readonly property int cols: 2
    readonly property int colWidth: Math.floor((page.dash.bodyWidth - 36 - 14 - (page.cols - 1) * 22) / page.cols)

    contentHeight: sheet.implicitHeight

    Flickable {
        id: sheetView

        anchors.fill: parent
        // Gutter for the scrollbar, which sits to the right of this.
        anchors.rightMargin: 14
        contentHeight: sheet.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: sheet
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 22

            // ── Left: the bar's own look ─────────────────────────────────
            Column {
                spacing: 16

                SettingsCol {
                    colWidth: page.colWidth
                    title: "Colour"
                    group: "appearance"

                    Caption {
                        vcenter: false
                        text: "Accent"
                        color: Theme.subtext0
                        size: 11
                    }

                    Grid {
                        id: accentGrid

                        readonly property int swatch: 28

                        width: parent.width
                        spacing: 7
                        // Derived rather than fixed: a hardcoded count
                        // overflowed the column and drew the swatches on top
                        // of each other when this page was three columns wide.
                        columns: Math.max(4, Math.floor((width + spacing) / (accentGrid.swatch + spacing)))

                        Repeater {
                            model: Theme.accentKeys

                            Rectangle {
                                required property string modelData

                                readonly property bool picked: Settings.accent === modelData

                                width: accentGrid.swatch
                                height: accentGrid.swatch
                                radius: width / 2
                                color: Theme.accentFor(modelData)
                                // The selection ring is drawn inside the
                                // swatch: a halo around it overflowed the grid
                                // cell and clipped at the column's edge.
                                border.width: picked ? 3 : (modelData === "black" ? 1 : 0)
                                border.color: picked ? Theme.base : Theme.overlay0

                                Rectangle {
                                    anchors.fill: parent
                                    visible: parent.picked
                                    radius: parent.radius
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Theme.icon
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Settings.set("accent", parent.modelData)
                                }
                            }
                        }
                    }

                    Item {
                        width: 1
                        height: 4
                    }

                    Caption {
                        vcenter: false
                        text: "Flavour"
                        color: Theme.subtext0
                        size: 11
                    }

                    // All four fit on one row at this width, so the light one
                    // is no longer stranded on a second line.
                    Row {
                        width: parent.width
                        spacing: 5

                        Choice {
                            label: "Mocha"
                            perRow: 4
                            picked: Settings.flavour === "mocha"
                            onTriggered: Settings.set("flavour", "mocha")
                        }
                        Choice {
                            label: "Macchiato"
                            perRow: 4
                            picked: Settings.flavour === "macchiato"
                            onTriggered: Settings.set("flavour", "macchiato")
                        }
                        Choice {
                            label: "Frappé"
                            perRow: 4
                            picked: Settings.flavour === "frappe"
                            onTriggered: Settings.set("flavour", "frappe")
                        }
                        Choice {
                            label: "Latte"
                            perRow: 4
                            picked: Settings.flavour === "latte"
                            onTriggered: Settings.set("flavour", "latte")
                        }
                    }
                }

                SettingsCol {
                    colWidth: page.colWidth
                    title: "Surfaces"
                    group: "appearance"
                    showReset: false

                    Pct {
                        label: "Bar opacity"
                        value: Settings.barOpacity
                        onPicked: v => Settings.set("barOpacity", v)
                    }
                    Pct {
                        label: "Container opacity"
                        value: Settings.containerOpacity
                        onPicked: v => Settings.set("containerOpacity", v)
                    }
                    Pct {
                        label: "Panel opacity"
                        value: Settings.panelOpacity
                        onPicked: v => Settings.set("panelOpacity", v)
                    }
                }

                SettingsCol {
                    colWidth: page.colWidth
                    title: "Shadow"
                    group: "appearance"
                    showReset: false

                    ToggleSwitch {
                        label: "Drop shadow"
                        checked: Settings.shadowEnabled
                        onToggled: Settings.set("shadowEnabled", !Settings.shadowEnabled)
                    }
                    Pct {
                        label: "Strength"
                        value: Settings.shadowOpacity
                        dimmed: !Settings.shadowEnabled
                        onPicked: v => Settings.set("shadowOpacity", v)
                    }
                    Pct {
                        label: "Blur"
                        value: Settings.shadowBlur
                        dimmed: !Settings.shadowEnabled
                        onPicked: v => Settings.set("shadowBlur", v)
                    }
                }
            }

            // ── Right: everything outside the bar ────────────────────────
            Column {
                spacing: 16

                SystemThemeCol {
                    colWidth: page.colWidth
                }

                WindowChromeCol {
                    colWidth: page.colWidth
                }

                CursorsCol {
                    colWidth: page.colWidth
                }

                PresetsCol {
                    colWidth: page.colWidth
                }

                PreviewCol {
                    colWidth: page.colWidth
                }
            }
        }
    }

    ScrollTrack {
        view: sheetView
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }
}
