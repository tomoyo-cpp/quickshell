import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import "root:/"

// The control centre: a panel that flows out of the middle of the bar. The
// outline is drawn as a single Shape so the join can use concave fillets —
// plain rounded rectangles can only curve inwards, which reads as a card
// stuck under the bar rather than an extension of it.
//
// This is a layer surface rather than a PopupWindow: a grabbing popup requires
// its parent layer surface to have already received input, so opening from a
// keybind made the whole panel fail to map. A layer surface takes keyboard
// focus directly, which is what the task field and search boxes need.
PanelWindow {
    id: root

    required property var bar
    // The bar's visual strip — the window around it is larger by
    // `shadowPad`, so anchoring to the window would leave a gap.
    required property Item barStrip

    // Body geometry. The window is wider than the body by `notch` on each
    // side so the outward fillets have somewhere to live.
    readonly property int bodyWidth: 700
    readonly property int maxBodyHeight: 505
    readonly property int notch: 18
    // The panel meets the bar exactly at its bottom edge — no overlap. It is
    // stacked above the bar's surface, so it still hides the drop shadow that
    // would otherwise draw a line across the join.
    readonly property int joinOverlap: 0

    // Published for the click-catcher. The window spans the full width; the
    // panel itself is centred within it.
    readonly property int panelWidth: bodyWidth + notch * 2
    readonly property int panelLeft: Math.round((width - panelWidth) / 2)

    // Two phases on the way out, mirrored on the way back: the outline flows
    // first, then the contents fade in on top of it. Sharing one value made
    // text appear over a panel that was still transparent.
    property bool open: false

    // Held true through the close so the surface stays mapped while it plays.
    // The outline follows this rather than bodyHeight directly. Lists fill in
    // their delegates lazily, so bodyHeight can grow mid-animation; easing to
    // the new value absorbs that instead of stepping to it.
    property real smoothHeight: root.bodyHeight

    Behavior on smoothHeight {
        NumberAnimation {
            duration: Theme.dur(140)
            easing.type: Easing.OutCubic
        }
    }

    property bool closing: false

    property real reveal: 0
    property real contentFade: 0

    readonly property int page: root.bar ? root.bar.dashboardPage : 0

    // Set by whichever Page is showing, when it declares a height.
    property real activeContentHeight: 0

    // Chrome around the page content: outer margins, tab strip, rule, spacing.
    readonly property int pageChrome: 18 * 2 + 30 + 1 + 14 * 2

    readonly property int bodyHeight: activeContentHeight > 0 ? Math.min(maxBodyHeight, Math.round(activeContentHeight) + pageChrome) : maxBodyHeight
    property int monthOffset: 0
    property date selectedDay: new Date()

    readonly property date now: clock.date

    // ── Audio ────────────────────────────────────────────────────────────
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property int volume: sinkAudio ? Math.round(sinkAudio.volume * 100) : 0
    readonly property bool muted: sinkAudio ? sinkAudio.muted : true

    // ── Battery ──────────────────────────────────────────────────────────
    readonly property var battery: UPower.displayDevice
    readonly property int batteryPercent: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: battery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged)

    readonly property string batteryRemaining: {
        if (!battery)
            return "";
        const secs = charging ? battery.timeToFull : battery.timeToEmpty;
        if (!secs || secs <= 0)
            return charging && batteryPercent >= 99 ? "Fully charged" : "On AC power";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        const t = h > 0 ? `${h}h ${m}m` : `${m}m`;
        return charging ? `${t} until full` : `${t} remaining`;
    }

    // Same figure as batteryRemaining, trimmed to fit inside a gauge ring.
    readonly property string batteryRemainingShort: {
        if (!battery)
            return "";
        const secs = charging ? battery.timeToFull : battery.timeToEmpty;
        if (!secs || secs <= 0)
            return charging && batteryPercent >= 99 ? "full" : "on AC";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    // ── Network ──────────────────────────────────────────────────────────
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var activeWifi: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: adapter !== null && adapter.enabled
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)

    readonly property var visibleNetworks: {
        if (!wifiDevice)
            return [];
        return wifiDevice.networks.values.filter(n => n.name && n.name !== "").sort((a, b) => (b.signalStrength ?? 0) - (a.signalStrength ?? 0)).slice(0, 14);
    }

    // ── Media ────────────────────────────────────────────────────────────
    readonly property var players: Mpris.players.values ?? []
    readonly property MprisPlayer player: {
        if (players.length === 0)
            return null;
        for (const p of players)
            if (p.isPlaying)
                return p;
        return players[0];
    }

    // ── Calendar geometry ────────────────────────────────────────────────
    readonly property date shownMonth: {
        const d = new Date(root.now);
        d.setDate(1);
        d.setMonth(d.getMonth() + root.monthOffset);
        return d;
    }
    readonly property int lead: (root.shownMonth.getDay() + 6) % 7
    readonly property int daysInMonth: {
        const d = new Date(root.shownMonth);
        d.setMonth(d.getMonth() + 1);
        d.setDate(0);
        return d.getDate();
    }
    readonly property int weekRows: Math.ceil((root.lead + root.daysInMonth) / 7)

    // Colour for the System page's battery ring. Same four bands as the
    // battery panel, so the two agree.
    readonly property bool batteryCharging: root.charging
    readonly property color batteryColor: {
        if (root.batteryCharging)
            return Theme.green;
        if (root.batteryPercent <= Settings.batteryLow)
            return Theme.red;
        if (root.batteryPercent <= Settings.batteryMid)
            return Theme.peach;
        if (root.batteryPercent <= Settings.batteryHigh)
            return Theme.yellow;
        return Theme.green;
    }

    // The Widgets tab carries three columns, the rest two. Column width is
    // derived from that rather than fixed, or three 250px columns overflow the
    // 700px panel and clip at both edges.
    // The bind currently being recorded, or null.
    property var capturing: null
    property string bindError: ""

    // Add-a-bind form. `capturingNew` is a separate flag from `capturing` so
    // the form's key chip and the list rows cannot both be recording.
    property bool capturingNew: false
    property string newKey: ""

    // Modifiers chosen in the UI rather than held down.
    //
    // niri consumes its own binds before any client sees them, and it only
    // honours a shortcuts inhibitor if the surface asked for one, which
    // Quickshell cannot do. So physically holding Mod+Q to rebind it would
    // close a window instead. Picking the modifiers here means the key you
    // actually press is bare, and niri binds almost nothing bare.
    property bool modSuper: false
    property bool modCtrl: false
    property bool modAlt: false
    property bool modShift: false

    function clearMods() {
        root.modSuper = false;
        root.modCtrl = false;
        root.modAlt = false;
        root.modShift = false;
    }

    readonly property bool anyCapture: root.capturing !== null || root.capturingNew

    KeyCapture {
        id: keyCapture
    }

    // KDL actions read like config; strip the syntax for display.
    function prettyAction(a) {
        return a.replace(/;$/, "").replace(/^spawn-sh\s+/, "").replace(/^spawn\s+/, "").replace(/"/g, " ").replace(/\s+/g, " ").trim();
    }

    function applyCapture(event) {
        if (!root.anyCapture)
            return;

        if (event.key === Qt.Key_Escape) {
            root.capturing = null;
            root.capturingNew = false;
            root.bindError = "";
            return;
        }

        // Union of the chips and anything genuinely held, so both styles work.
        const combo = keyCapture.comboWith(event, root.modSuper, root.modCtrl, root.modAlt, root.modShift);
        if (combo === "")
            return;   // modifier alone, or a key with no name — keep waiting

        // Recording a key for the new-bind form.
        if (root.capturingNew) {
            const taken = Keybinds.conflict(combo, -1);
            if (taken) {
                root.bindError = `${combo} is already bound to ${root.prettyAction(taken.action)}`;
                return;
            }
            root.newKey = combo;
            root.capturingNew = false;
            root.bindError = "";
            root.clearMods();
            return;
        }

        if (combo === root.capturing.key) {
            root.capturing = null;
            return;
        }

        const clash = Keybinds.conflict(combo, root.capturing.line);
        if (clash) {
            root.bindError = `${combo} is already bound to ${root.prettyAction(clash.action)}`;
            return;   // stays in capture mode so another key can be tried
        }

        if (!Keybinds.rebind(root.capturing, combo))
            root.bindError = "could not write the bind";
        else
            root.bindError = "";
        root.capturing = null;
        root.clearMods();
    }

    // Invisible, but must be a focusable Item to receive key events at all.
    Item {
        id: captureSink

        focus: root.anyCapture
        Keys.onPressed: event => {
            root.applyCapture(event);
            event.accepted = true;
        }
    }

    readonly property var tabs: [
        {
            glyph: "󰢮",
            label: "System"
        },
        {
            glyph: "󰸉",
            label: "Wallpaper"
        },
        {
            glyph: "󰏘",
            label: "Appearance"
        },
        {
            glyph: "󰢻",
            label: "Settings"
        }
    ]

    // Spans the width so the panel can be centred by anchoring; only the
    // panel itself accepts input, everything else is masked out.
    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        // Flush with the bar's bottom edge.
        top: Theme.barMargin + Theme.barHeight - root.joinOverlap
    }

    implicitHeight: bodyHeight + Theme.shadowPad + joinOverlap
    // Positioned relative to the raw screen edge: the bar reserves an
    // exclusive zone, and without this the panel's top margin is measured from
    // below that zone, leaving a gap exactly the height of the bar.
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: true

    // On-demand focus needs a click before it delivers keys, which is fine for
    // the to-do field but useless for capturing a keybind. Exclusive focus
    // while capturing also stops niri acting on the combo being recorded —
    // otherwise pressing Mod+S to rebind it would just toggle this panel.
    WlrLayershell.keyboardFocus: root.anyCapture ? WlrKeyboardFocus.Exclusive : (root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)
    color: "transparent"
    // Stays mapped until the collapse finishes, or it would just vanish.
    visible: open || closing

    mask: Region {
        item: panel
    }

    onOpenChanged: {
        if (open) {
            root.monthOffset = 0;
            root.closing = false;
            closeAnim.stop();
            openAnim.restart();
        } else if (root.reveal > 0) {
            openAnim.stop();
            root.closing = true;
            closeAnim.restart();
        }

        // Sampling starts with the panel, not with the System page: a first
        // delta takes a moment, and by the time that page is reached the rows
        // are already there.
        Procs.watching = open;
    }

    // Driven explicitly rather than with Behaviors: a Behavior whose
    // SequentialAnimation starts with a PauseAnimation writes the new value
    // through immediately instead of holding it, which unmapped the surface
    // before the close could be seen.
    SequentialAnimation {
        id: openAnim

        // Strictly ordered: the container forms first, then the contents fade
        // in. Overlapping them let text appear over a half-formed, still
        // translucent panel.
        NumberAnimation {
            target: root
            property: "reveal"
            to: 1
            duration: Theme.dur(260)
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "contentFade"
            to: 1
            duration: Theme.dur(190)
            easing.type: Easing.OutQuad
        }
    }

    SequentialAnimation {
        id: closeAnim

        // Contents clear first, then the panel retracts into the bar.
        NumberAnimation {
            target: root
            property: "contentFade"
            to: 0
            duration: Theme.dur(70)
            easing.type: Easing.InQuad
        }

        NumberAnimation {
            target: root
            property: "reveal"
            to: 0
            duration: Theme.dur(120)
            easing.type: Easing.InCubic
        }

        ScriptAction {
            script: root.closing = false
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // Only monitored while the media page is open — it is a live audio tap.
    PwNodePeakMonitor {
        id: peak
        node: Pipewire.defaultAudioSink
        enabled: root.visible && root.page === 1
    }

    Item {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.bodyWidth + root.notch * 2
        height: root.bodyHeight + Theme.shadowPad + root.joinOverlap

        // Escape closes, as with any dialog.
        focus: true
        Keys.onEscapePressed: root.bar.closePopup()

    // ── Outline ──────────────────────────────────────────────────────────
    // Drawn directly rather than through a MultiEffect: MultiEffect renders a
    // shadow for a Shape source but never its fill, layered or not. The bar
    // strip is a plain Rectangle, so it keeps its drop shadow.
    PanelOutline {
        anchors.fill: panel
        notch: root.notch
        bodyWidth: root.bodyWidth
        smoothHeight: root.smoothHeight
        reveal: root.reveal
        joinOverlap: root.joinOverlap
    }

    // ── Contents ─────────────────────────────────────────────────────────
    Item {
        x: root.notch
        width: root.bodyWidth
        height: root.bodyHeight

        opacity: root.contentFade
        // Composited once as a texture while animating, rather than alpha-
        // blending every child separately each frame. Dropped again at rest so
        // nothing pays for an offscreen buffer when it is not moving.
        layer.enabled: openAnim.running || closeAnim.running
        // A small upward offset makes the contents settle into the panel
        // rather than snapping into place.
        y: root.joinOverlap + (1 - root.contentFade) * -8

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // ── Tabs ─────────────────────────────────────────────────────
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Repeater {
                    model: root.tabs.length

                    Rectangle {
                        id: tab
                        required property int index

                        readonly property var modelData: root.tabs[tab.index]

                        readonly property bool selected: root.page === tab.index

                        width: tabLabel.x + tabLabel.implicitWidth + 13
                        height: 30
                        radius: 15
                        color: selected ? Theme.alpha(Theme.icon, 0.16) : tabMouse.containsMouse ? Theme.surface0 : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.anim
                            }
                        }

                        Text {
                            id: tabIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: tab.modelData.glyph
                            font.family: Theme.iconFont
                            font.pixelSize: 14
                            color: tab.selected ? Theme.icon : Theme.overlay1
                        }

                        Caption {
                            id: tabLabel
                            x: tabIcon.x + tabIcon.width + 7
                            anchors.verticalCenter: parent.verticalCenter
                            text: tab.modelData.label
                            color: tab.selected ? Theme.icon : Theme.overlay1
                            size: 12
                            font.bold: tab.selected
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                            root.bar.dashboardPage = tab.index;
                            root.bar.dashboardSource = "";
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

            // ── Pages ────────────────────────────────────────────────────
            Item {
                id: pages
                width: parent.width
                height: parent.height - y

                // ── System ───────────────────────────────────────────────
                SystemPage {
                    dash: root
                    pageIndex: 0
                }

                // ── Wallpaper ────────────────────────────────────────────
                WallpaperPage {
                    dash: root
                    pageIndex: 1
                }

                // ── Appearance ───────────────────────────────────────────
                AppearancePage {
                    dash: root
                    pageIndex: 2
                }

                // ── Settings ─────────────────────────────────────────────
                SettingsPage {
                    dash: root
                    pageIndex: 3
                }
            }
        }
    }

    }

    function formatTime(seconds) {
        if (!seconds || seconds <= 0)
            return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }

    // Poll position only while the media page is open and something plays.
    Timer {
        running: root.visible && root.page === 1 && root.player !== null && root.player.isPlaying && root.player.positionSupported
        interval: 500
        repeat: true
        onTriggered: root.player.positionChanged()
    }

}
