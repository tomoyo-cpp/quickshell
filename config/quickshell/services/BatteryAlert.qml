pragma Singleton

import QtQuick
import Quickshell
import "root:/"
import Quickshell.Io
import Quickshell.Services.UPower

// Staged battery warnings.
//
// Emitted as ordinary desktop notifications rather than a bespoke overlay, so
// they inherit the toast behaviour already built: critical urgency renders red
// and stays until dismissed instead of expiring on a timer.
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: root.device !== null && root.device.isLaptopBattery
    readonly property int percent: root.device ? Math.round(root.device.percentage * 100) : 100

    readonly property bool charging: root.device && (root.device.state === UPowerDeviceState.Charging || root.device.state === UPowerDeviceState.FullyCharged)

    // Highest stage already announced this discharge: 0 none, 1 low, 2 critical.
    property int stage: 0

    // Percent the level must climb back above before a stage re-arms. Without
    // it, a battery hovering on the threshold would fire on every fluctuation.
    readonly property int hysteresis: 3

    readonly property int lowAt: Settings.batteryMid
    readonly property int criticalAt: Settings.batteryLow

    function _remaining() {
        if (!root.device)
            return "";
        const secs = root.device.timeToEmpty;
        if (!secs || secs <= 0)
            return "";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        return h > 0 ? ` · about ${h}h ${m}m left` : ` · about ${m}m left`;
    }

    // No -i: the battery icon names are not in the icon theme here, and the
    // toast is already colour-coded by urgency.
    function _notify(urgency, summary, body) {
        notifier.exec(["notify-send", "-u", urgency, "-a", "Battery", summary, body]);
    }

    function check() {
        if (!Settings.batteryAlerts || !root.present)
            return;

        // Plugging in clears everything: the level is on its way back up.
        if (root.charging) {
            root.stage = 0;
            return;
        }

        if (root.percent <= root.criticalAt && root.stage < 2) {
            root.stage = 2;
            root._notify("critical", `Battery critically low — ${root.percent}%`, `Plug in now${root._remaining()}.`);
            return;
        }

        if (root.percent <= root.lowAt && root.stage < 1) {
            root.stage = 1;
            root._notify("normal", `Battery low — ${root.percent}%`, `Consider plugging in${root._remaining()}.`);
            return;
        }

        // Re-arm once the level has recovered clear of a threshold.
        if (root.percent > root.criticalAt + root.hysteresis && root.stage === 2)
            root.stage = 1;
        if (root.percent > root.lowAt + root.hysteresis && root.stage === 1)
            root.stage = 0;
    }

    onPercentChanged: root.check()
    onChargingChanged: root.check()

    // UPower can report a stale percentage for a moment at startup, so the
    // first check waits rather than firing on a bad reading.
    Timer {
        running: true
        interval: 8000
        onTriggered: root.check()
    }

    Process {
        id: notifier
    }
}
