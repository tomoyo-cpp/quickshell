import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Bluetooth
import "root:/"

// Wi-Fi and Bluetooth, flowing out of the bar beneath the network widget at
// the right end.
//
// The link summary at the top reuses the System page's dual network ring:
// download on the outer track, upload on the inner one.
PanelShell {
    id: root

    popupName: "network"
    bodyWidth: 380

    // ── Devices ──────────────────────────────────────────────────────────
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null

    readonly property var activeWifi: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null
    readonly property bool wiredUp: wiredDevice !== null && wiredDevice.connected

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: adapter !== null && adapter.enabled

    // Named networks, strongest first, one row per SSID. The scan list often
    // carries the same SSID once per band or BSSID.
    readonly property var visibleNetworks: {
        if (!root.wifiDevice)
            return [];
        const seen = {};
        const out = [];
        const all = root.wifiDevice.networks.values.filter(n => n.name && n.name !== "").sort((a, b) => (b.signalStrength ?? 0) - (a.signalStrength ?? 0));
        for (const n of all) {
            if (seen[n.name])
                continue;
            seen[n.name] = true;
            out.push(n);
        }
        return out;
    }

    readonly property var btDevices: Bluetooth.devices.values.filter(d => d.paired || d.connected || (root.adapter && root.adapter.discovering))

    // ── Layout ───────────────────────────────────────────────────────────
    property int tab: 0   // 0 = wi-fi, 1 = bluetooth

    readonly property int rowHeight: 34
    readonly property int listCount: root.tab === 0 ? root.visibleNetworks.length : root.btDevices.length

    // Grows with the list, then scrolls. Capped so the panel never runs past
    // the middle of the screen.
    readonly property int maxListHeight: {
        const half = Math.round((root.screen ? root.screen.height : 1080) / 2) - (Theme.barMargin + Theme.barHeight);
        return Math.max(root.rowHeight * 3, half - 232);
    }
    readonly property int listHeight: Math.max(root.rowHeight, Math.min(root.maxListHeight, root.listCount * (root.rowHeight + 2)))

    bodyHeight: 14 + 104 + 12 + 30 + 8 + root.listHeight + (pskRow.active ? 42 : 0) + 14

    // Text entry needs real keyboard focus; on-demand focus would want a
    // click on the surface first and swallow the first keystroke.
    WlrLayershell.keyboardFocus: pskRow.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── Live details ─────────────────────────────────────────────────────
    property string iface: "-"
    property string ipAddr: "-"
    property string gateway: "-"
    property string linkSpeed: "-"
    property string ssid: "-"
    property string band: "-"

    onOpenChanged: {
        if (open) {
            info.running = true;
            pskRow.target = null;
        } else {
            pskRow.target = null;
        }
    }

    // Scanning is only worth the radio time while the list is on screen.
    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.open && root.tab === 0
        when: root.wifiDevice !== null
    }

    // Bluetooth had no equivalent at all, so nothing ever set
    // adapter.discovering and — with nothing paired — the list could only ever
    // be empty.
    //
    // Re-asserted on a timer rather than bound once. A Binding only writes when
    // its own expression changes, so it could not notice BlueZ ending a
    // discovery on its own, nor an adapter that came back from a power cycle
    // with discovery cleared. Re-checking keeps the scan alive for as long as
    // the tab is open and picks itself back up after a toggle.
    readonly property bool wantScan: root.open && root.tab === 1 && root.btOn

    Timer {
        id: btScan

        running: root.wantScan
        interval: 4000
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (root.adapter && !root.adapter.discovering)
                root.adapter.discovering = true;
        }

        // Stop scanning the moment the tab is left, rather than leaving the
        // radio running behind a closed panel. Guarded on `enabled`: writing to
        // an adapter that has just been switched off is not meaningful.
        onRunningChanged: {
            if (!btScan.running && root.adapter && root.adapter.enabled && root.adapter.discovering)
                root.adapter.discovering = false;
        }
    }

    Timer {
        running: root.open
        interval: 3000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!info.running)
            info.running = true
    }

    Process {
        id: info
        command: [`${Quickshell.shellDir}/scripts/net-info.sh`]

        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/);
                if (p.length < 6)
                    return;
                root.iface = p[0];
                root.ipAddr = p[1];
                root.gateway = p[2];
                root.linkSpeed = p[3] === "-" ? "-" : `${p[3]} Mb/s`;
                // Spaces were escaped in the script so the split stays sane.
                root.ssid = p[4] === "-" ? "-" : p[4].replace(/\x1f/g, " ");
                root.band = p[5] === "-" ? "-" : (parseInt(p[5]) > 4000 ? "5 GHz" : "2.4 GHz");
            }
        }
    }

    Process {
        id: btAction
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 0

        // ── Link summary: the System page's network ring + details ───────
        Item {
            width: parent.width
            height: 104

            CircleGauge {
                id: netRing

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                vcenter: false
                diameter: 88
                thickness: 5
                accent: Theme.blue
                secondAccent: Theme.mauve
                value: SysMon.rxRate / SysMon.netScale
                secondValue: SysMon.txRate / SysMon.netScale

                Sparkline {
                    anchors.centerIn: parent
                    width: netRing.innerDiameter
                    height: width
                    circleRadius: width / 2
                    values: SysMon.rxPercentHistory
                    accent: Theme.blue
                }

                Sparkline {
                    anchors.centerIn: parent
                    width: netRing.innerDiameter
                    height: width
                    circleRadius: width / 2
                    visible: SysMon.txPercentHistory.length > 1
                    filled: false
                    values: SysMon.txPercentHistory
                    accent: Theme.mauve
                }

                Column {
                    anchors.centerIn: parent
                    spacing: -1

                    Caption {
                        anchors.horizontalCenter: parent.horizontalCenter
                        vcenter: false
                        text: `󰇚 ${SysMon.formatRate(SysMon.rxRate)}`
                        color: Theme.blue
                        size: 9
                        font.bold: true
                    }

                    Caption {
                        anchors.horizontalCenter: parent.horizontalCenter
                        vcenter: false
                        text: `󰕒 ${SysMon.formatRate(SysMon.txRate)}`
                        color: Theme.mauve
                        size: 9
                        font.bold: true
                    }
                }
            }

            // Details, keyed off whichever link actually carries the route.
            Column {
                anchors.left: netRing.right
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Row {
                    spacing: 6

                    Glyph {
                        text: root.wiredUp ? "󰈀" : !Networking.wifiEnabled ? "󰤭" : root.activeWifi ? "󰤨" : "󰤮"
                        color: Theme.icon
                        size: 13
                    }

                    Caption {
                        text: root.wiredUp ? "Wired" : root.ssid !== "-" ? root.ssid : "Not connected"
                        color: Theme.icon
                        size: 13
                        font.bold: true
                        width: Math.min(implicitWidth, 200)
                        elide: Text.ElideRight
                    }
                }

                Detail {
                    label: "IP"
                    value: root.ipAddr
                }
                Detail {
                    label: "Gateway"
                    value: root.gateway
                }
                Detail {
                    label: "Link"
                    value: root.linkSpeed
                }
                Detail {
                    label: root.wiredUp ? "Interface" : "Band"
                    value: root.wiredUp ? root.iface : root.band
                }
            }
        }

        Item {
            width: 1
            height: 12
        }

        // ── Tabs ─────────────────────────────────────────────────────────
        Row {
            width: parent.width
            height: 30
            spacing: 6

            Tab {
                width: (parent.width - 6) / 2
                glyph: "󰤨"
                label: "Wi-Fi"
                index: 0
            }

            Tab {
                width: (parent.width - 6) / 2
                glyph: "󰂯"
                label: "Bluetooth"
                index: 1
            }
        }

        Item {
            width: 1
            height: 8
        }

        // ── Lists ────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: root.listHeight

            // Wi-Fi
            ListView {
                id: wifiList

                anchors.fill: parent
                visible: root.tab === 0
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.visibleNetworks

                // Only shown when there is more than fits, so it doubles as
                // the cue that the list scrolls at all.
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 1
                    width: 3
                    radius: 1.5
                    color: Theme.alpha(Theme.icon, 0.4)

                    visible: wifiList.contentHeight > wifiList.height
                    height: Math.max(24, wifiList.height * (wifiList.height / Math.max(1, wifiList.contentHeight)))
                    y: wifiList.contentHeight > wifiList.height ? Math.max(0, Math.min(wifiList.height - height, (wifiList.contentY / (wifiList.contentHeight - wifiList.height)) * (wifiList.height - height))) : 0
                }

                delegate: Rectangle {
                    id: net
                    required property var modelData

                    readonly property int strength: modelData.signalStrength ?? 0
                    readonly property bool secured: {
                        const s = net.modelData.security;
                        return s !== undefined && s !== null && s !== 0 && s !== "";
                    }

                    width: ListView.view.width - 8
                    height: root.rowHeight
                    radius: 11
                    color: modelData.connected ? Theme.alpha(Theme.blue, 0.16) : netMouse.containsMouse ? Theme.surface0 : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.anim
                        }
                    }

                    MouseArea {
                        id: netMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: event => {
                            if (event.button === Qt.RightButton) {
                                if (net.modelData.known)
                                    net.modelData.forget();
                                return;
                            }
                            if (net.modelData.connected) {
                                net.modelData.disconnect();
                                return;
                            }
                            // An unknown secured network needs a passphrase;
                            // a known one already has it stored.
                            if (net.secured && !net.modelData.known)
                                pskRow.prompt(net.modelData);
                            else
                                net.modelData.connect();
                        }
                    }

                    Glyph {
                        id: netIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 11
                        text: net.strength >= 75 ? "󰤨" : net.strength >= 50 ? "󰤥" : net.strength >= 25 ? "󰤢" : "󰤟"
                        color: net.modelData.connected ? Theme.blue : Theme.subtext0
                        size: 13
                    }

                    Caption {
                        anchors.left: netIcon.right
                        anchors.leftMargin: 10
                        anchors.right: netRight.left
                        anchors.rightMargin: 8
                        text: net.modelData.name
                        color: net.modelData.connected ? Theme.icon : Theme.subtext0
                        size: 12
                        elide: Text.ElideRight
                    }

                    Row {
                        id: netRight
                        anchors.right: parent.right
                        anchors.rightMargin: 11
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Glyph {
                            text: "󰌾"
                            color: Theme.overlay0
                            size: 10
                            visible: net.secured
                        }

                        Caption {
                            text: net.modelData.known ? "󰄬" : ""
                            color: Theme.overlay1
                            size: 10
                            visible: !net.modelData.connected && net.modelData.known
                        }

                        Caption {
                            text: net.modelData.stateChanging ? "…" : net.modelData.connected ? "󰄬" : `${net.strength}%`
                            color: net.modelData.connected ? Theme.blue : Theme.overlay1
                            size: 10
                            font.bold: net.modelData.connected
                        }
                    }
                }
            }

            // Bluetooth
            ListView {
                id: btList

                anchors.fill: parent
                visible: root.tab === 1
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.btDevices

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 1
                    width: 3
                    radius: 1.5
                    color: Theme.alpha(Theme.icon, 0.4)

                    visible: btList.contentHeight > btList.height
                    height: Math.max(24, btList.height * (btList.height / Math.max(1, btList.contentHeight)))
                    y: btList.contentHeight > btList.height ? Math.max(0, Math.min(btList.height - height, (btList.contentY / (btList.contentHeight - btList.height)) * (btList.height - height))) : 0
                }

                delegate: Rectangle {
                    id: btDev
                    required property var modelData

                    width: ListView.view.width - 8
                    height: root.rowHeight
                    radius: 11
                    color: modelData.connected ? Theme.alpha(Theme.blue, 0.16) : btMouse.containsMouse ? Theme.surface0 : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.anim
                        }
                    }

                    MouseArea {
                        id: btMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: event => {
                            if (event.button === Qt.RightButton) {
                                if (btDev.modelData.paired)
                                    btDev.modelData.forget();
                                return;
                            }
                            if (btDev.modelData.connected)
                                btDev.modelData.disconnect();
                            else if (!btDev.modelData.paired)
                                btDev.modelData.pair();
                            else
                                btDev.modelData.connect();
                        }
                    }

                    Glyph {
                        id: btIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 11
                        text: {
                            const i = btDev.modelData.icon ?? "";
                            if (i.includes("headset") || i.includes("headphone"))
                                return "󰋋";
                            if (i.includes("audio"))
                                return "󰓃";
                            if (i.includes("mouse"))
                                return "󰍽";
                            if (i.includes("keyboard"))
                                return "󰌌";
                            if (i.includes("phone"))
                                return "󰄜";
                            return "󰂯";
                        }
                        color: btDev.modelData.connected ? Theme.blue : Theme.subtext0
                        size: 13
                    }

                    Caption {
                        anchors.left: btIcon.right
                        anchors.leftMargin: 10
                        anchors.right: btRight.left
                        anchors.rightMargin: 8
                        text: btDev.modelData.deviceName || btDev.modelData.name || btDev.modelData.address
                        color: btDev.modelData.connected ? Theme.icon : Theme.subtext0
                        size: 12
                        elide: Text.ElideRight
                    }

                    Row {
                        id: btRight
                        anchors.right: parent.right
                        anchors.rightMargin: 11
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Caption {
                            text: btDev.modelData.batteryAvailable ? `${Math.round(btDev.modelData.battery * 100)}%` : ""
                            color: Theme.overlay1
                            size: 10
                            visible: text !== ""
                        }

                        Caption {
                            text: btDev.modelData.pairing ? "…" : btDev.modelData.connected ? "󰄬" : btDev.modelData.paired ? "" : "󰐕"
                            color: btDev.modelData.connected ? Theme.blue : Theme.overlay1
                            size: 10
                            font.bold: btDev.modelData.connected
                        }
                    }
                }
            }

            // Empty state, so a disabled radio does not read as a hang.
            Caption {
                anchors.centerIn: parent
                // centerIn already supplies both anchors; the default vertical
                // one would fight it.
                vcenter: false
                visible: root.listCount === 0
                text: root.tab === 0 ? (Networking.wifiEnabled ? "Scanning…" : "Wi-Fi is off") : (root.btOn ? "No devices" : "Bluetooth is off")
                color: Theme.overlay0
                size: 11
            }
        }

        // ── Passphrase prompt ────────────────────────────────────────────
        Item {
            id: pskRow

            property var target: null
            readonly property bool active: pskRow.target !== null

            function prompt(network) {
                pskRow.target = network;
                pskField.text = "";
                focusDelay.restart();
            }

            function submit() {
                if (!pskRow.target || pskField.text === "")
                    return;
                pskRow.target.connectWithPsk(pskField.text);
                pskRow.target = null;
                pskField.text = "";
            }

            width: parent.width
            height: pskRow.active ? 42 : 0
            visible: pskRow.active
            clip: true

            // The surface only takes keyboard focus once the prompt exists, so
            // grabbing it in the same frame lands before the layer is ready.
            Timer {
                id: focusDelay
                interval: 30
                onTriggered: pskField.forceActiveFocus()
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 32
                radius: 11
                color: Theme.surface0

                Glyph {
                    id: pskIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    text: "󰌾"
                    color: Theme.overlay1
                    size: 11
                }

                TextInput {
                    id: pskField

                    anchors.left: pskIcon.right
                    anchors.leftMargin: 9
                    anchors.right: pskCancel.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    echoMode: TextInput.Password
                    color: Theme.icon
                    font.family: Theme.font
                    font.pixelSize: 12
                    clip: true

                    onAccepted: pskRow.submit()
                    Keys.onEscapePressed: pskRow.target = null

                    Caption {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pskField.text === ""
                        text: pskRow.target ? `Password for ${pskRow.target.name}` : ""
                        color: Theme.overlay0
                        size: 12
                    }
                }

                Glyph {
                    id: pskCancel
                    anchors.right: parent.right
                    anchors.rightMargin: 11
                    text: "󰅖"
                    color: cancelMouse.containsMouse ? Theme.red : Theme.overlay1
                    size: 11

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pskRow.target = null
                    }
                }
            }
        }
    }

    // ── Local components ─────────────────────────────────────────────────
    component Detail: Row {
        property string label: ""
        property string value: ""

        spacing: 6

        Caption {
            width: 58
            text: parent.label
            color: Theme.overlay0
            size: 11
        }

        Caption {
            text: parent.value
            color: Theme.subtext0
            size: 11
        }
    }

    component Tab: Rectangle {
        id: tabRoot

        property string glyph: ""
        property string label: ""
        property int index: 0

        readonly property bool selected: root.tab === tabRoot.index

        height: 30
        radius: 11
        color: tabRoot.selected ? Theme.alpha(Theme.blue, 0.18) : tabMouse.containsMouse ? Theme.surface0 : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.anim
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 7

            Glyph {
                text: tabRoot.glyph
                color: tabRoot.selected ? Theme.blue : Theme.subtext0
                size: 12
            }

            Caption {
                text: tabRoot.label
                color: tabRoot.selected ? Theme.icon : Theme.subtext0
                size: 12
                font.bold: tabRoot.selected
            }
        }

        // The radio's own switch, on the tab it belongs to.
        Toggle {
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            checked: tabRoot.index === 0 ? Networking.wifiEnabled : root.btOn
            onToggled: {
                if (tabRoot.index === 0) {
                    Networking.wifiEnabled = !Networking.wifiEnabled;
                } else if (root.adapter) {
                    root.adapter.enabled = !root.adapter.enabled;
                }
            }
        }

        MouseArea {
            id: tabMouse
            anchors.fill: parent
            anchors.rightMargin: 40
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.tab = tabRoot.index
        }
    }

    component Toggle: Rectangle {
        id: sw

        property bool checked: false
        signal toggled

        width: 30
        height: 16
        radius: 8
        color: sw.checked ? Theme.blue : Theme.surface1

        Behavior on color {
            ColorAnimation {
                duration: Theme.anim
            }
        }

        Rectangle {
            x: sw.checked ? sw.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            height: 10
            radius: 5
            color: sw.checked ? Theme.crust : Theme.overlay2

            Behavior on x {
                NumberAnimation {
                    duration: Theme.anim
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }

}
