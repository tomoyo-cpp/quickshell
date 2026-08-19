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

    // Which sub-tab the Settings page shows.
    property int settingsTab: 0
    property string bindFilter: ""
    readonly property string modPrefix: {
        const p = [];
        if (page.dash.modSuper)
            p.push("Mod");
        if (page.dash.modCtrl)
            p.push("Ctrl");
        if (page.dash.modAlt)
            p.push("Alt");
        if (page.dash.modShift)
            p.push("Shift");
        return p.join("+");
    }
    // Every panel the bar can open over IPC. Mirrors the handler in Bar.qml;
    // shown in the Keys tab so the commands are discoverable without reading
    // the source, and clickable so they can be bound without retyping.
    readonly property var panelCommands: [
        {
            label: "Control centre",
            cmd: "qs ipc call bar toggle dashboard"
        },
        {
            label: "App launcher",
            cmd: "qs ipc call bar toggle launcher"
        },
        {
            label: "Notifications",
            cmd: "qs ipc call bar toggle notifications"
        },
        {
            label: "Clipboard",
            cmd: "qs ipc call bar toggle clipboard"
        },
        {
            label: "Media",
            cmd: "qs ipc call bar toggle media"
        },
        {
            label: "Calendar",
            cmd: "qs ipc call bar toggle calendar"
        },
        {
            label: "Wi-Fi / Bluetooth",
            cmd: "qs ipc call bar toggle network"
        },
        {
            label: "Battery",
            cmd: "qs ipc call bar toggle battery"
        },
        {
            label: "Close any panel",
            cmd: "qs ipc call bar close"
        },
        {
            label: "Dashboard \u00b7 System",
            cmd: "qs ipc call bar tab system"
        },
        {
            label: "Dashboard \u00b7 Wallpaper",
            cmd: "qs ipc call bar tab wallpaper"
        },
        {
            label: "Dashboard \u00b7 Appearance",
            cmd: "qs ipc call bar tab appearance"
        },
        {
            label: "Dashboard \u00b7 Settings",
            cmd: "qs ipc call bar tab settings"
        }
    ]
    readonly property int settingsCols: page.settingsTab === 3 ? 1 : page.settingsTab === 1 ? 3 : 2
    readonly property int settingsColWidth: Math.floor((page.dash.bodyWidth - 36 - 14 - (page.settingsCols - 1) * 22) / page.settingsCols)

    Column {
        anchors.fill: parent
        spacing: 10

        // ── Sub-tabs ─────────────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            SubTab {
                glyph: "󰙀"
                label: "Layout"
                index: 0
            }
            SubTab {
                glyph: "󰀻"
                label: "Widgets"
                index: 1
            }
            SubTab {
                glyph: "󰒓"
                label: "Behaviour"
                index: 2
            }
            SubTab {
                glyph: "󰌌"
                label: "Keys"
                index: 3
            }
        }

        // ── Content ──────────────────────────────────────
        Item {
            width: parent.width
            height: parent.height - 46

            // Brings the add-bind form back into view when a
            // command is picked from the list below it.
            NumberAnimation {
                id: toTop
                target: sheetView
                property: "contentY"
                to: 0
                duration: Theme.dur(220)
                easing.type: Easing.OutCubic
            }

            Flickable {
                id: sheetView

                anchors.fill: parent
                // Gutter for the scrollbar, which sits in the
                // space to the right of this.
                anchors.rightMargin: 14
                contentHeight: sheet.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

            Row {
                id: sheet
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 22

                // ── Layout ───────────────────────────────
                SettingsCol {
                    colWidth: page.settingsColWidth
                    visible: page.settingsTab === 0
                    title: "Bar"
                    group: "sizing"

                    Setting {
                        label: "Bar height"
                        value: Settings.barHeight
                        from: 28
                        to: 56
                        onMoved: v => Settings.set("barHeight", v)
                    }
                    Setting {
                        label: "Top margin"
                        value: Settings.barMargin
                        from: 0
                        to: 24
                        onMoved: v => Settings.set("barMargin", v)
                    }
                    Setting {
                        label: "Bar corner radius"
                        value: Settings.barRadius
                        from: 0
                        to: 24
                        onMoved: v => Settings.set("barRadius", v)
                    }
                    // Its own control rather than following the bar: squaring
                    // the strip off used to square off every dropdown with it.
                    Setting {
                        label: "Panel corner radius"
                        value: Settings.panelRadius
                        from: 0
                        to: 28
                        onMoved: v => Settings.set("panelRadius", v)
                    }
                    Setting {
                        label: "Window gap"
                        value: Settings.reservedMargin
                        from: 0
                        to: 32
                        onMoved: v => Settings.set("reservedMargin", v)
                    }

                    ToggleSwitch {
                        label: "Link side margins"
                        checked: Settings.linkSideMargins
                        onToggled: Settings.set("linkSideMargins", !Settings.linkSideMargins)
                    }
                    Setting {
                        label: Settings.linkSideMargins ? "Side margin" : "Left margin"
                        value: Settings.barSideMargin
                        from: 0
                        to: 48
                        onMoved: v => Settings.set("barSideMargin", v)
                    }
                    Setting {
                        label: "Right margin"
                        visible: !Settings.linkSideMargins
                        value: Settings.barSideMarginRight
                        from: 0
                        to: 48
                        onMoved: v => Settings.set("barSideMarginRight", v)
                    }
                }

                SettingsCol {

                    colWidth: page.settingsColWidth
                    visible: page.settingsTab === 0
                    title: "Inner"
                    group: "inner"

                    Setting {
                        label: "Gap between groups"
                        value: Settings.gap
                        from: 0
                        to: 20
                        onMoved: v => Settings.set("gap", v)
                    }
                    Setting {
                        label: "Container inset"
                        value: Settings.containerInset
                        from: 0
                        to: 10
                        onMoved: v => Settings.set("containerInset", v)
                    }
                    Setting {
                        label: "Container radius"
                        value: Settings.containerRadius
                        from: 0
                        to: 20
                        onMoved: v => Settings.set("containerRadius", v)
                    }
                    Setting {
                        label: "Pill padding"
                        value: Settings.pillPadding
                        from: 2
                        to: 18
                        onMoved: v => Settings.set("pillPadding", v)
                    }
                    Setting {
                        label: "Icon size"
                        value: Settings.iconSize
                        from: 10
                        to: 26
                        onMoved: v => Settings.set("iconSize", v)
                    }
                    Setting {
                        label: "Font size"
                        value: Settings.fontSize
                        from: 9
                        to: 18
                        onMoved: v => Settings.set("fontSize", v)
                    }
                    Setting {
                        label: "Workspace icon size"
                        value: Settings.workspaceIconSize
                        from: 8
                        to: 24
                        onMoved: v => Settings.set("workspaceIconSize", v)
                    }
                }

                // ── Widgets ──────────────────────────────
                SettingsCol {
                    colWidth: page.settingsColWidth
                    visible: page.settingsTab === 1
                    title: "Shown"
                    group: "widgets"

                    ToggleSwitch {
                        label: "System load"
                        checked: Settings.showSysMon
                        onToggled: Settings.set("showSysMon", !Settings.showSysMon)
                    }
                    ToggleSwitch {
                        label: "Media"
                        checked: Settings.showMedia
                        onToggled: Settings.set("showMedia", !Settings.showMedia)
                    }
                    ToggleSwitch {
                        label: "Launcher"
                        checked: Settings.showLauncher
                        onToggled: Settings.set("showLauncher", !Settings.showLauncher)
                    }
                    ToggleSwitch {
                        label: "Overview"
                        checked: Settings.showOverview
                        onToggled: Settings.set("showOverview", !Settings.showOverview)
                    }
                    ToggleSwitch {
                        label: "Screenshot"
                        checked: Settings.showScreenshot
                        onToggled: Settings.set("showScreenshot", !Settings.showScreenshot)
                    }
                    ToggleSwitch {
                        label: "Screen recorder"
                        checked: Settings.showRecorder
                        onToggled: Settings.set("showRecorder", !Settings.showRecorder)
                    }
                    ToggleSwitch {
                        label: "Keyboard"
                        checked: Settings.showKeyboard
                        onToggled: Settings.set("showKeyboard", !Settings.showKeyboard)
                    }
                    ToggleSwitch {
                        label: "Clipboard"
                        checked: Settings.showClipboard
                        onToggled: Settings.set("showClipboard", !Settings.showClipboard)
                    }
                    ToggleSwitch {
                        label: "Battery"
                        checked: Settings.showBattery
                        onToggled: Settings.set("showBattery", !Settings.showBattery)
                    }
                    ToggleSwitch {
                        label: "Wi-Fi / Bluetooth"
                        checked: Settings.showNetwork
                        onToggled: Settings.set("showNetwork", !Settings.showNetwork)
                    }

                    Item {
                        width: 1
                        height: 6
                    }

                    Caption {
                        vcenter: false
                        text: "Workspaces"
                        color: Theme.subtext0
                        size: 11
                    }

                    ToggleSwitch {
                        label: "App icons"
                        checked: Settings.workspaceShowIcons
                        onToggled: Settings.set("workspaceShowIcons", !Settings.workspaceShowIcons)
                    }
                    ToggleSwitch {
                        label: "Show empty"
                        checked: Settings.workspaceShowEmpty
                        onToggled: Settings.set("workspaceShowEmpty", !Settings.workspaceShowEmpty)
                    }
                    Setting {
                        label: "Max icons"
                        value: Settings.workspaceMaxIcons
                        from: 1
                        to: 10
                        onMoved: v => Settings.set("workspaceMaxIcons", v)
                    }
                }

                SettingsCol {

                    colWidth: page.settingsColWidth
                    visible: page.settingsTab === 1
                    title: "Clock"
                    group: "clock"

                    ToggleSwitch {
                        label: "24-hour"
                        checked: Settings.clockUse24h
                        onToggled: Settings.set("clockUse24h", !Settings.clockUse24h)
                    }
                    ToggleSwitch {
                        label: "Seconds"
                        checked: Settings.clockShowSeconds
                        onToggled: Settings.set("clockShowSeconds", !Settings.clockShowSeconds)
                    }
                    ToggleSwitch {
                        label: "Show date"
                        checked: Settings.clockShowDate
                        onToggled: Settings.set("clockShowDate", !Settings.clockShowDate)
                    }

                    Item {
                        width: 1
                        height: 10
                    }

                    Caption {
                        vcenter: false
                        text: "Media"
                        color: Theme.subtext0
                        size: 11
                    }

                    ToggleSwitch {
                        label: "Show artist"
                        checked: Settings.mediaShowArtist
                        onToggled: Settings.set("mediaShowArtist", !Settings.mediaShowArtist)
                    }
                    ToggleSwitch {
                        label: "Visualiser"
                        checked: Settings.showVisualiser
                        onToggled: Settings.set("showVisualiser", !Settings.showVisualiser)
                    }
                    Setting {
                        label: "Title width"
                        value: Settings.mediaMaxWidth
                        from: 80
                        to: 400
                        onMoved: v => Settings.set("mediaMaxWidth", v)
                    }
                    Setting {
                        label: "Scroll speed"
                        value: Settings.mediaScrollSpeed
                        from: 8
                        to: 80
                        onMoved: v => Settings.set("mediaScrollSpeed", v)
                    }
                    Setting {
                        label: "Visualiser thickness"
                        value: Settings.visualiserBarWidth
                        from: 1
                        to: 8
                        onMoved: v => Settings.set("visualiserBarWidth", v)
                    }
                    Pct {
                        label: "Visualiser opacity"
                        value: Settings.visualiserOpacity
                        onPicked: v => Settings.set("visualiserOpacity", v)
                    }
                }

                SettingsCol {

                    colWidth: page.settingsColWidth
                    visible: page.settingsTab === 1
                    title: "Battery"
                    group: "battery"

                    ToggleSwitch {
                        label: "Show percentage"
                        checked: Settings.batteryShowPercent
                        onToggled: Settings.set("batteryShowPercent", !Settings.batteryShowPercent)
                    }
                    ToggleSwitch {
                        label: "Flash when critical"
                        checked: Settings.batteryFlash
                        onToggled: Settings.set("batteryFlash", !Settings.batteryFlash)
                    }
                    ToggleSwitch {
                        label: "Low battery alerts"
                        checked: Settings.batteryAlerts
                        onToggled: Settings.set("batteryAlerts", !Settings.batteryAlerts)
                    }
                    Setting {
                        label: "Critical below"
                        value: Settings.batteryLow
                        from: 5
                        to: 40
                        onMoved: v => Settings.set("batteryLow", v)
                    }
                    Setting {
                        label: "Low below"
                        value: Settings.batteryMid
                        from: 10
                        to: 60
                        onMoved: v => Settings.set("batteryMid", v)
                    }
                    Setting {
                        label: "Medium below"
                        value: Settings.batteryHigh
                        from: 30
                        to: 90
                        onMoved: v => Settings.set("batteryHigh", v)
                    }
                }

                // ── Behaviour ────────────────────────────
                SettingsCol {
                    colWidth: page.settingsColWidth
                    visible: page.settingsTab === 2
                    title: "Motion"
                    group: "behaviour"

                    ToggleSwitch {
                        label: "Animations"
                        checked: Settings.animationsEnabled
                        onToggled: Settings.set("animationsEnabled", !Settings.animationsEnabled)
                    }

                    // Presets, because aiming a bare
                    // multiplier at "snappy" is guesswork.
                    // Higher is slower, so the labels invert.
                    Row {
                        width: parent.width
                        spacing: 5

                        Choice {
                            label: "Snappy"
                            picked: Settings.animationsEnabled && Math.abs(Settings.animSpeed - 1.8) < 0.05
                            onTriggered: {
                                Settings.set("animationsEnabled", true);
                                Settings.set("animSpeed", 1.8);
                            }
                        }
                        Choice {
                            label: "Normal"
                            picked: Settings.animationsEnabled && Math.abs(Settings.animSpeed - 1) < 0.05
                            onTriggered: {
                                Settings.set("animationsEnabled", true);
                                Settings.set("animSpeed", 1.0);
                            }
                        }
                    }

                    SliderRow {
                        // Higher is faster: the value is a
                        // speed factor that divides each
                        // duration, so 2x runs twice as quick.
                        label: "Animation speed"
                        readout: Settings.animationsEnabled ? `${Settings.animSpeed.toFixed(1)}\u00d7` : "off"
                        dimmed: !Settings.animationsEnabled
                        // 0.4x drags, 4x is near-instant; past
                        // either end there is nothing to see.
                        value: (Settings.animSpeed - 0.4) / 3.6
                        onMoved: v => Settings.set("animSpeed", Math.round((0.4 + v * 3.6) * 20) / 20)
                    }

                    Item {
                        width: 1
                        height: 10
                    }

                    Caption {
                        vcenter: false
                        text: "Popups"
                        color: Theme.subtext0
                        size: 11
                    }

                    ToggleSwitch {
                        label: "On-screen display"
                        checked: Settings.osdEnabled
                        onToggled: Settings.set("osdEnabled", !Settings.osdEnabled)
                    }
                    ToggleSwitch {
                        label: "Notification toasts"
                        checked: Settings.toastsEnabled
                        onToggled: Settings.set("toastsEnabled", !Settings.toastsEnabled)
                    }
                    ToggleSwitch {
                        label: "Do not disturb"
                        checked: Settings.dnd
                        onToggled: Settings.set("dnd", !Settings.dnd)
                    }

                    Row {
                        width: parent.width
                        spacing: 5

                        Choice {
                            label: "Left"
                            picked: Settings.toastPosition === "left"
                            onTriggered: Settings.set("toastPosition", "left")
                        }
                        Choice {
                            label: "Right"
                            picked: Settings.toastPosition === "right"
                            onTriggered: Settings.set("toastPosition", "right")
                        }
                    }

                    SliderRow {
                        label: "Toast duration"
                        readout: `${(Settings.toastDuration / 1000).toFixed(0)}s`
                        value: Settings.toastDuration / 20000
                        onMoved: v => Settings.set("toastDuration", Math.max(1000, Math.round(v * 20000 / 500) * 500))
                    }
                    Setting {
                        label: "Max toasts"
                        value: Settings.toastMaxVisible
                        from: 1
                        to: 10
                        onMoved: v => Settings.set("toastMaxVisible", v)
                    }
                }

                // ── Keys ─────────────────────────────
                SettingsCol {
                    colWidth: page.settingsColWidth
                    id: keysCol

                    visible: page.settingsTab === 3
                    title: "Keybinds"
                    showReset: false

                    // Grouped by category, with the filter
                    // applied inside each section so a search
                    // does not leave empty headings behind.
                    readonly property var sections: {
                        const q = page.bindFilter.trim().toLowerCase();
                        const out = [];
                        for (const g of Keybinds.grouped) {
                            const items = q === "" ? g.items : g.items.filter(b => b.key.toLowerCase().includes(q) || b.action.toLowerCase().includes(q));
                            if (items.length > 0)
                                out.push({
                                    title: g.title,
                                    items: items
                                });
                        }
                        return out;
                    }

                    readonly property int shownCount: {
                        let n = 0;
                        for (const g of keysCol.sections)
                            n += g.items.length;
                        return n;
                    }

                    Caption {
                        vcenter: false
                        width: parent.width
                        text: Keybinds.error !== "" ? Keybinds.error : `${keysCol.shownCount} of ${Keybinds.binds.length} binds \u00b7 click a key to change it`
                        color: Keybinds.error !== "" ? Theme.red : Theme.overlay0
                        size: 11
                    }

                    // ── Modifiers ────────────────────────
                    Row {
                        width: parent.width
                        height: 26
                        spacing: 5

                        ModChip {
                            label: "Mod"
                            on: page.dash.modSuper
                            onToggled: page.dash.modSuper = !page.dash.modSuper
                        }
                        ModChip {
                            label: "Ctrl"
                            on: page.dash.modCtrl
                            onToggled: page.dash.modCtrl = !page.dash.modCtrl
                        }
                        ModChip {
                            label: "Alt"
                            on: page.dash.modAlt
                            onToggled: page.dash.modAlt = !page.dash.modAlt
                        }
                        ModChip {
                            label: "Shift"
                            on: page.dash.modShift
                            onToggled: page.dash.modShift = !page.dash.modShift
                        }

                        Caption {
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.modPrefix === "" ? "pick modifiers here, then press a bare key" : `${page.modPrefix}+ \u2026 press a bare key`
                            color: page.modPrefix === "" ? Theme.overlay0 : Theme.icon
                            size: 10
                            leftPadding: 8
                        }
                    }

                    // ── Add a bind ───────────────────────
                    Rectangle {
                        width: parent.width
                        height: 38
                        radius: 10
                        color: Theme.alpha(Theme.surface0, 0.5)

                        Rectangle {
                            id: newKeyChip
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 104
                            height: 26
                            radius: 8
                            color: page.dash.capturingNew ? Theme.alpha(Theme.icon, 0.3) : Theme.alpha(Theme.surface1, 0.9)

                            Caption {
                                anchors.centerIn: parent
                                vcenter: false
                                text: page.dash.capturingNew ? "Press keys\u2026" : (page.dash.newKey === "" ? "Set key" : page.dash.newKey)
                                color: page.dash.newKey === "" && !page.dash.capturingNew ? Theme.overlay1 : Theme.icon
                                size: 10
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    page.dash.bindError = "";
                                    page.dash.capturing = null;
                                    page.dash.capturingNew = !page.dash.capturingNew;
                                    if (page.dash.capturingNew)
                                        captureSink.forceActiveFocus();
                                }
                            }
                        }

                        TextInput {
                            id: newCommand
                            anchors.left: newKeyChip.right
                            anchors.leftMargin: 10
                            anchors.right: addChip.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.icon
                            font.family: Theme.font
                            font.pixelSize: 12
                            clip: true
                            enabled: !page.dash.anyCapture
                            onAccepted: addChip.commit()

                            Caption {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: newCommand.text === ""
                                text: "Command to run\u2026"
                                color: Theme.overlay0
                                size: 12
                            }
                        }

                        Rectangle {
                            id: addChip

                            function commit() {
                                if (page.dash.newKey === "") {
                                    page.dash.bindError = "set a key first";
                                    return;
                                }
                                if (newCommand.text.trim() === "") {
                                    page.dash.bindError = "type a command to run";
                                    return;
                                }
                                if (!Keybinds.addBind(page.dash.newKey, newCommand.text)) {
                                    page.dash.bindError = "could not add the bind";
                                    return;
                                }
                                page.dash.bindError = "";
                                page.dash.newKey = "";
                                newCommand.text = "";
                            }

                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 56
                            height: 26
                            radius: 8
                            readonly property bool ready: page.dash.newKey !== "" && newCommand.text.trim() !== ""
                            color: addChip.ready ? (addMouse.containsMouse ? Theme.alpha(Theme.green, 0.35) : Theme.alpha(Theme.green, 0.22)) : Theme.alpha(Theme.surface1, 0.6)

                            Caption {
                                anchors.centerIn: parent
                                vcenter: false
                                text: "Add"
                                color: addChip.ready ? Theme.green : Theme.overlay0
                                size: 10
                                font.bold: true
                            }

                            MouseArea {
                                id: addMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: addChip.commit()
                            }
                        }
                    }

                    Caption {
                        vcenter: false
                        width: parent.width
                        text: "New binds run through sh, so pipes and quotes work."
                        color: Theme.overlay0
                        size: 10
                    }

                    // ── Shell commands ───────────────────
                    Item {
                        width: parent.width
                        height: 20

                        Caption {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Panel commands"
                            color: Theme.icon
                            size: 12
                            font.bold: true
                        }

                        Caption {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "click to use \u00b7 right-click to copy"
                            color: Theme.overlay0
                            size: 10
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: Theme.alpha(Theme.surface1, 0.8)
                        }
                    }

                    Repeater {
                        model: page.panelCommands

                        Rectangle {
                            id: cmdRow
                            required property var modelData

                            width: page.settingsColWidth
                            height: 26
                            radius: 8
                            color: cmdMouse.containsMouse ? Theme.alpha(Theme.surface0, 0.7) : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.anim
                                }
                            }

                            Caption {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 150
                                text: cmdRow.modelData.label
                                color: Theme.subtext0
                                size: 11
                                elide: Text.ElideRight
                            }

                            Caption {
                                anchors.left: parent.left
                                anchors.leftMargin: 166
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: cmdRow.modelData.cmd
                                color: Theme.overlay1
                                size: 10
                                elide: Text.ElideLeft
                            }

                            MouseArea {
                                id: cmdMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                onClicked: event => {
                                    if (event.button === Qt.RightButton) {
                                        Cliphist.copyText(cmdRow.modelData.cmd);
                                        page.dash.bindError = "copied to clipboard";
                                        return;
                                    }
                                    // Drop it into the add form
                                    // so it only needs a key,
                                    // then bring the form back
                                    // into view — it sits above
                                    // this list.
                                    newCommand.text = cmdRow.modelData.cmd;
                                    page.dash.bindError = "";
                                    toTop.restart();
                                }
                            }
                        }
                    }

                    Item {
                        width: 1
                        height: 8
                    }

                    // ── Search ───────────────────────────
                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: 10
                        color: Theme.alpha(Theme.surface0, 0.6)

                        Glyph {
                            id: searchIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            text: "\udb80\udf49"
                            color: Theme.overlay1
                            size: 12
                        }

                        TextInput {
                            id: bindSearch
                            anchors.left: searchIcon.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.icon
                            font.family: Theme.font
                            font.pixelSize: 12
                            clip: true
                            enabled: !page.dash.anyCapture
                            onTextChanged: page.bindFilter = text

                            Caption {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: bindSearch.text === ""
                                text: "Search actions or keys\u2026"
                                color: Theme.overlay0
                                size: 12
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: bindSearch.forceActiveFocus()
                        }
                    }

                    Caption {
                        vcenter: false
                        width: parent.width
                        visible: page.dash.bindError !== ""
                        text: page.dash.bindError
                        color: Theme.red
                        size: 11
                        wrapMode: Text.Wrap
                    }

                    // ── Sections ─────────────────────────
                    Repeater {
                        model: keysCol.sections

                        Column {
                            required property var modelData

                            width: page.settingsColWidth
                            spacing: 3
                            topPadding: 8

                            Item {
                                width: parent.width
                                height: 20

                                Caption {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.parent.modelData.title
                                    color: Theme.icon
                                    size: 12
                                    font.bold: true
                                }

                                Caption {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.parent.modelData.items.length
                                    color: Theme.overlay0
                                    size: 10
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: Theme.alpha(Theme.surface1, 0.8)
                                }
                            }

                            Repeater {
                                model: parent.modelData.items

                                Rectangle {
                                    id: bindRow
                                    required property var modelData

                                    readonly property bool recording: page.dash.capturing !== null && page.dash.capturing.line === bindRow.modelData.line
                                    readonly property bool off: bindRow.modelData.disabled === true
                                    // Every command under "Custom commands"
                                    // can be deleted, not just lines this
                                    // panel wrote — niri's own actions and the
                                    // media keys fall in other categories.
                                    readonly property bool mine: Keybinds.deletable(bindRow.modelData)

                                    width: page.settingsColWidth
                                    height: 30
                                    radius: 9
                                    color: bindRow.recording ? Theme.alpha(Theme.icon, 0.16) : rowMouse.containsMouse ? Theme.alpha(Theme.surface0, 0.7) : "transparent"

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.anim
                                        }
                                    }

                                    // Declared first so the unbind button paints on top of it. Filling
                                    // the row and declaring it last put it over every child and
                                    // swallowed their clicks.
                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            page.dash.bindError = "";
                                            page.dash.capturingNew = false;
                                            page.dash.capturing = bindRow.recording ? null : bindRow.modelData;
                                            if (page.dash.capturing)
                                                captureSink.forceActiveFocus();
                                        }
                                    }

                                    Caption {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.right: keyChip.left
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: page.dash.prettyAction(bindRow.modelData.action)
                                        color: bindRow.off ? Theme.overlay0 : Theme.subtext0
                                        size: 11
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        id: deleteBtn
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: bindRow.mine ? 22 : 0
                                        height: 22
                                        radius: 11
                                        visible: bindRow.mine
                                        color: deleteMouse.containsMouse ? Theme.alpha(Theme.red, 0.3) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\udb82\ude7a"
                                            font.family: Theme.iconFont
                                            font.pixelSize: 11
                                            color: deleteMouse.containsMouse ? Theme.red : Theme.overlay1
                                        }

                                        MouseArea {
                                            id: deleteMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                page.dash.bindError = "";
                                                Keybinds.removeBind(bindRow.modelData);
                                            }
                                        }
                                    }

                                    // Unbind, or put an unbound
                                    // entry back on its old key.
                                    Rectangle {
                                        id: unbindBtn
                                        anchors.right: deleteBtn.left
                                        // A plain margin: the
                                        // delete button is
                                        // already zero-width
                                        // when hidden, so a
                                        // negative one here
                                        // just shoved this off
                                        // the row's edge.
                                        anchors.rightMargin: 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: unbindMouse.containsMouse ? Theme.alpha(bindRow.off ? Theme.green : Theme.red, 0.3) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: bindRow.off ? "\udb81\udc59" : "\udb80\udd56"
                                            font.family: Theme.iconFont
                                            font.pixelSize: 11
                                            color: unbindMouse.containsMouse ? (bindRow.off ? Theme.green : Theme.red) : Theme.overlay1
                                        }

                                        MouseArea {
                                            id: unbindMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                page.dash.bindError = "";
                                                if (!bindRow.off) {
                                                    Keybinds.unbind(bindRow.modelData);
                                                    return;
                                                }
                                                if (!Keybinds.restore(bindRow.modelData))
                                                    page.dash.bindError = `${bindRow.modelData.key} is taken; pick another key instead`;
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: keyChip
                                        anchors.right: unbindBtn.left
                                        anchors.rightMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.max(70, chipText.implicitWidth + 18)
                                        height: 22
                                        radius: 8
                                        color: bindRow.recording ? Theme.alpha(Theme.icon, 0.3) : Theme.alpha(Theme.surface1, bindRow.off ? 0.35 : 0.8)

                                        Caption {
                                            id: chipText
                                            anchors.centerIn: parent
                                            vcenter: false
                                            // The old key is kept
                                            // as a memento but
                                            // nothing triggers it.
                                            text: bindRow.recording ? "Press keys\u2026" : bindRow.off ? "unbound" : bindRow.modelData.key
                                            color: bindRow.recording ? Theme.icon : bindRow.off ? Theme.overlay0 : Theme.text
                                            size: 10
                                            font.bold: !bindRow.off
                                            font.italic: bindRow.off
                                        }
                                    }

                                }
                            }
                        }
                    }
                }

                SettingsCol {

                    colWidth: page.settingsColWidth
                    visible: page.settingsTab === 2
                    title: "System"
                    group: "cava"
                    showReset: false

                    Caption {
                        vcenter: false
                        text: "Visualiser engine"
                        color: Theme.subtext0
                        size: 11
                    }

                    Setting {
                        label: "Bands"
                        value: Settings.cavaBands
                        from: 12
                        to: 96
                        onMoved: v => Settings.set("cavaBands", v)
                    }
                    Setting {
                        label: "Framerate"
                        value: Settings.cavaFramerate
                        from: 15
                        to: 120
                        onMoved: v => Settings.set("cavaFramerate", v)
                    }
                    Pct {
                        label: "Smoothing"
                        value: Settings.cavaSmoothing
                        onPicked: v => Settings.set("cavaSmoothing", v)
                    }

                    Item {
                        width: 1
                        height: 10
                    }

                    Caption {
                        vcenter: false
                        text: "Clipboard and launcher"
                        color: Theme.subtext0
                        size: 11
                    }

                    ToggleSwitch {
                        label: "Image thumbnails"
                        checked: Settings.clipboardThumbnails
                        onToggled: Settings.set("clipboardThumbnails", !Settings.clipboardThumbnails)
                    }
                    Setting {
                        label: "Clipboard history"
                        value: Settings.clipboardMaxItems
                        from: 5
                        to: 100
                        onMoved: v => Settings.set("clipboardMaxItems", v)
                    }
                    Setting {
                        label: "Recent apps"
                        value: Settings.launcherRecentCount
                        from: 0
                        to: 12
                        onMoved: v => Settings.set("launcherRecentCount", v)
                    }

                    Item {
                        width: 1
                        height: 10
                    }

                    Caption {
                        vcenter: false
                        text: "Night light"
                        color: Theme.subtext0
                        size: 11
                    }

                    SliderRow {
                        label: "Temperature"
                        readout: `${Settings.nightTemp}K`
                        value: (Settings.nightTemp - 2000) / 4500
                        onMoved: v => Settings.set("nightTemp", Math.round((2000 + v * 4500) / 100) * 100)
                    }

                    Item {
                        width: 1
                        height: 10
                    }

                    Item {
                        width: parent.width
                        height: 30

                        ChipButton {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            label: "Reset everything"
                            accent: Theme.red
                            onTriggered: Settings.reset()
                        }
                    }
                }
            }
            }

            // Sibling of the Flickable, not a child: anything
            // declared inside one lives in its content item and
            // scrolls away with the content.
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 3
                radius: 1.5
                color: Theme.alpha(Theme.surface2, 0.5)
                visible: sheetView.contentHeight > sheetView.height

                Rectangle {
                    width: parent.width
                    radius: 1.5
                    color: Theme.alpha(Theme.icon, 0.55)
                    height: Math.max(30, sheetView.height * (sheetView.height / Math.max(1, sheetView.contentHeight)))
                    y: sheetView.contentHeight > sheetView.height ? (sheetView.contentY / (sheetView.contentHeight - sheetView.height)) * (parent.height - height) : 0
                }
            }

            // Fades in along the bottom edge while there is
            // more below, so the cue does not depend on
            // noticing a thin bar at the side.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 22
                opacity: sheetView.contentHeight - sheetView.contentY - sheetView.height > 4 ? 1 : 0

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: Theme.alpha(Theme.base, 0.85)
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.anim
                    }
                }
            }
        }
    }

    component SubTab: Rectangle {
        id: stb

        property string glyph: ""
        property string label: ""
        property int index: 0

        readonly property bool picked: page.settingsTab === stb.index

        width: stbRow.implicitWidth + 22
        height: 26
        radius: 13
        color: stb.picked ? Theme.alpha(Theme.icon, 0.18) : stbMouse.containsMouse ? Theme.surface0 : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.anim
            }
        }

        Row {
            id: stbRow
            anchors.centerIn: parent
            spacing: 6

            Glyph {
                text: stb.glyph
                color: stb.picked ? Theme.icon : Theme.subtext0
                size: 12
            }

            Caption {
                text: stb.label
                color: stb.picked ? Theme.icon : Theme.subtext0
                size: 11
                font.bold: stb.picked
            }
        }

        MouseArea {
            id: stbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: page.settingsTab = stb.index
        }
    }
}
