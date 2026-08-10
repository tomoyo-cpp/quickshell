import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "root:/"

PanelWindow {
    id: bar

    required property var modelData

    // Only one dropdown is open at a time; widgets bind against this.
    property string openPopup: ""
    // Which dashboard tab to land on when it opens, and which widget asked
    // for it — without the latter every opener lights up at once.
    property int dashboardPage: 0
    property string dashboardSource: ""

    // Single source of truth for tab order, in the same order as Dashboard's
    // `tabs`. Everything that opens a specific page looks its index up here
    // rather than hardcoding a number — inserting Appearance silently
    // repointed both `tab settings` and the gear widget at the wrong page.
    readonly property var dashboardPages: ["system", "wallpaper", "appearance", "settings"]

    function pageIndex(name) {
        return bar.dashboardPages.indexOf(String(name).toLowerCase());
    }

    function openDashboardNamed(name, source) {
        const i = bar.pageIndex(name);
        if (i >= 0)
            bar.openDashboard(i, source);
    }

    function openDashboard(page, source) {
        // Only a repeat of the *same* page toggles it shut. Matching on the
        // source alone meant asking for a different page while open closed the
        // panel instead of switching to it — every IPC call shares the "ipc"
        // source, so walking the tabs flickered open/shut.
        if (bar.openPopup === "dashboard" && bar.dashboardSource === source && bar.dashboardPage === page) {
            bar.closePopup();
            return;
        }
        bar.dashboardPage = page;
        bar.dashboardSource = source;
        bar.openPopup = "dashboard";
    }

    function togglePopup(name) {
        bar.openPopup = bar.openPopup === name ? "" : name;
    }

    function closePopup() {
        bar.openPopup = "";
    }

    screen: modelData
    color: "transparent"

    // The window is `shadowPad` larger than the bar on every side so the drop
    // shadow has somewhere to fall. `strip` is the bar proper — everything
    // anchors to that, not to the window.
    implicitHeight: Theme.barHeight + Theme.shadowPad * 2

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: Theme.barMargin - Theme.shadowPad
        left: Theme.barSideMargin - Theme.shadowPad
        right: Theme.barSideMarginRight - Theme.shadowPad
    }

    // Padding must not become reserved screen space.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.reservedSpace

    // Lets keybinds drive the dropdowns:
    //   qs ipc call bar toggle dashboard
    // Bound to the first screen only so the target name stays unique.
    IpcHandler {
        target: "bar"
        enabled: bar.screen === Quickshell.screens[0]

        function toggle(name: string): void {
            bar.togglePopup(name);
        }

        function close(): void {
            bar.closePopup();
        }

        // Open the dashboard straight to a tab: qs ipc call bar page 1
        //
        // Indices shift whenever a page is added or removed, which has already
        // silently repointed user keybinds twice. Prefer `tab` below.
        function page(index: int): void {
            bar.openDashboard(index, "ipc");
        }

        // Stable alternative: qs ipc call bar tab system
        //
        // Not named `show`: `qs ipc show` is a built-in subcommand, and the
        // argument parser matches it even after `call bar`, so the page name
        // was rejected before it ever reached here.
        function tab(name: string): void {
            const i = bar.pageIndex(name);
            if (i < 0)
                return;
            bar.openDashboard(i, "ipc");
        }
    }

    Item {
        id: strip
        anchors.fill: parent
        anchors.margins: Theme.shadowPad

        // Only routed through the MultiEffect when the shadow will actually
        // draw. At zero strength the effect was still round-tripping the whole
        // strip through an offscreen texture and a shader every frame to
        // produce a copy of itself — and a copy is not guaranteed to land on
        // exactly the same pixels as a direct draw, which is what put the bar a
        // shade off the panels beneath it despite both filling with crust at
        // the same alpha. Drawn plainly, it is on the panels' path.
        readonly property bool shadowDrawn: Settings.shadowEnabled && Settings.shadowOpacity > 0.001

        Rectangle {
            id: backdrop
            anchors.fill: parent
            radius: Theme.barRadius
            color: Theme.barBg
            visible: !strip.shadowDrawn
            layer.enabled: strip.shadowDrawn
        }

        MultiEffect {
            anchors.fill: backdrop
            source: backdrop
            visible: strip.shadowDrawn
            shadowEnabled: strip.shadowDrawn
            shadowColor: "#000000"
            shadowOpacity: Settings.shadowOpacity
            shadowBlur: Settings.shadowBlur
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
        }

        // ── Left end: launcher, overview, indicators, focused window ────
        LeftCluster {
            id: leftCluster

            anchors.left: parent.left
            anchors.leftMargin: Theme.containerInset + 4
            anchors.verticalCenter: parent.verticalCenter
            bar: bar
        }

        // Containers 1 and 3 hang off the workspace container rather than the
        // bar edges, so the three of them stay a single centred cluster.

        // ── 1: system load + media ───────────────────────────────────────
        Container {
            id: leftGroup

            anchors.right: workspaces.left
            anchors.rightMargin: Theme.gap
            anchors.verticalCenter: parent.verticalCenter
            innerSpacing: 4

            SysMonWidget {
                bar: bar
                visible: Settings.showSysMon
            }

            MediaWidget {
                id: mediaButton

                bar: bar
                visible: Settings.showMedia
            }
        }

        // ── 2: workspaces ────────────────────────────────────────────────
        Container {
            id: workspaces
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            Workspaces {
                bar: bar
            }
        }

        // ── 3: clock, screenshot, keyboard, settings, battery ────────────
        Container {
            id: rightContainer

            anchors.left: workspaces.right
            anchors.leftMargin: Theme.gap
            anchors.verticalCenter: parent.verticalCenter

            ClockWidget {
                id: clockButton

                bar: bar
            }

            ScreenshotWidget {
                visible: Settings.showScreenshot
            }

            RecordWidget {
                visible: Settings.showRecorder
            }

            KeyboardWidget {
                visible: Settings.showKeyboard
            }

            ClipboardWidget {
                id: clipButton

                bar: bar
                visible: Settings.showClipboard
            }

            BatteryWidget {
                id: batteryButton

                bar: bar
                visible: Settings.showBattery && device !== null && device.isLaptopBattery
            }
        }

        // ── Wi-fi + bluetooth: no container, straight on the backdrop ────
        NetworkWidget {
            id: netButton

            visible: Settings.showNetwork
            anchors.right: parent.right
            anchors.rightMargin: Theme.containerInset + 4
            anchors.verticalCenter: parent.verticalCenter
            bar: bar
        }
    }

    // Geometry of whichever surface is open, in screen coordinates.
    readonly property bool anyOpen: bar.openPopup !== ""
    readonly property int openLeft: {
        if (bar.openPopup === "dashboard")
            return dashboard.panelLeft;
        if (bar.openPopup === "notifications")
            return notifPanel.panelLeft;
        if (bar.openPopup === "clipboard")
            return clipPanel.panelLeft;
        if (bar.openPopup === "media")
            return mediaPanel.panelLeft;
        if (bar.openPopup === "calendar")
            return calendarPanel.panelLeft;
        if (bar.openPopup === "network")
            return networkPanel.panelLeft;
        if (bar.openPopup === "battery")
            return batteryPanel.panelLeft;
        return 0;
    }
    readonly property int openWidth: {
        if (bar.openPopup === "dashboard")
            return dashboard.panelWidth;
        if (bar.openPopup === "notifications")
            return notifPanel.panelWidth;
        if (bar.openPopup === "clipboard")
            return clipPanel.panelWidth;
        if (bar.openPopup === "media")
            return mediaPanel.panelWidth;
        if (bar.openPopup === "calendar")
            return calendarPanel.panelWidth;
        if (bar.openPopup === "network")
            return networkPanel.panelWidth;
        if (bar.openPopup === "battery")
            return batteryPanel.panelWidth;
        return 0;
    }
    readonly property int openHeight: {
        if (bar.openPopup === "dashboard")
            return dashboard.implicitHeight;
        if (bar.openPopup === "notifications")
            return notifPanel.implicitHeight;
        if (bar.openPopup === "clipboard")
            return clipPanel.implicitHeight;
        if (bar.openPopup === "media")
            return mediaPanel.implicitHeight;
        if (bar.openPopup === "calendar")
            return calendarPanel.implicitHeight;
        if (bar.openPopup === "network")
            return networkPanel.implicitHeight;
        if (bar.openPopup === "battery")
            return batteryPanel.implicitHeight;
        return 0;
    }

    // Three plain windows around the open surface rather than one masked
    // window: Region masks silently produced the wrong shape twice, and simple
    // rectangles are easy to reason about.

    // Everything below the panel.
    ClickCatcher {
        bar: bar
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        margins.top: Theme.barMargin + Theme.barHeight + bar.openHeight
    }

    // The band to the left of the panel.
    ClickCatcher {
        bar: bar
        anchors {
            top: true
            left: true
        }
        margins.top: Theme.barMargin + Theme.barHeight
        implicitWidth: Math.max(1, bar.openLeft)
        implicitHeight: Math.max(1, bar.openHeight)
    }

    // ...and to the right.
    ClickCatcher {
        bar: bar
        anchors {
            top: true
            right: true
        }
        margins.top: Theme.barMargin + Theme.barHeight
        implicitWidth: Math.max(1, (bar.screen ? bar.screen.width : 1920) - (bar.openLeft + bar.openWidth))
        implicitHeight: Math.max(1, bar.openHeight)
    }

    // Now playing, beneath the media widget.
    MediaPanel {
        id: mediaPanel

        bar: bar
        anchorX: Theme.barSideMargin + leftGroup.x + mediaButton.x + mediaButton.width / 2
    }

    // Calendar and tasks, beneath the clock.
    CalendarPanel {
        id: calendarPanel

        bar: bar
        anchorX: Theme.barSideMargin + rightContainer.x + clockButton.x + clockButton.width / 2
    }

    // Clipboard history, flowing out beneath its button.
    // Application launcher, centred on screen.
    Launcher {
        bar: bar
    }

    // Notification history, flowing out beneath the bell.
    NotificationPanel {
        id: notifPanel

        bar: bar
        anchorX: Theme.barSideMargin + leftCluster.x + leftCluster.bellItem.x + leftCluster.bellItem.width / 2
    }

    ClipboardPanel {
        id: clipPanel

        bar: bar
        anchorX: Theme.barSideMargin + rightContainer.x + clipButton.x + clipButton.width / 2
    }

    // Battery detail, flowing out beneath the battery ring.
    BatteryPanel {
        id: batteryPanel

        bar: bar
        anchorX: Theme.barSideMargin + rightContainer.x + batteryButton.x + batteryButton.width / 2
    }

    // Wi-Fi and bluetooth, flowing out beneath the network widget.
    NetworkPanel {
        id: networkPanel

        bar: bar
        anchorX: Theme.barSideMargin + netButton.x + netButton.width / 2
    }

    // The control centre, flowing out of the middle of the bar.
    Dashboard {
        id: dashboard

        bar: bar
        barStrip: strip
        // Drives its own visibility so it can animate itself closed.
        open: bar.openPopup === "dashboard"
    }

    component ClickCatcher: PanelWindow {
        required property var bar

        visible: bar.openPopup !== ""
        color: "transparent"
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: bar.closePopup()
        }
    }
}
