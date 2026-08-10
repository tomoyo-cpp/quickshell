import QtQuick
import Quickshell
import "root:/"

Pill {
    id: root

    required property var bar

    readonly property bool open: bar.openPopup === "calendar"
    readonly property date now: clock.date

    // A custom format string, when set, replaces the 12/24h and seconds
    // switches entirely — it is the escape hatch for anything they cannot say.
    readonly property string timeFormat: {
        if (Settings.clockFormat !== "")
            return Settings.clockFormat;
        const base = Settings.clockUse24h ? "HH:mm" : "h:mm";
        const secs = Settings.clockShowSeconds ? ":ss" : "";
        return base + secs + (Settings.clockUse24h ? "" : " AP");
    }

    active: open
    accent: Theme.lavender
    innerSpacing: 7

    onClicked: bar.togglePopup("calendar")

    SystemClock {
        id: clock
        // Ticking every second is only worth it when a second is on screen.
        precision: Settings.clockShowSeconds || Settings.clockFormat.includes("s") ? SystemClock.Seconds : SystemClock.Minutes
    }

    Caption {
        text: Qt.formatDateTime(root.now, root.timeFormat)
        color: Theme.text
        font.bold: true
    }

    Caption {
        text: "•"
        color: Theme.overlay0
        visible: Settings.clockShowDate
    }

    Caption {
        text: Qt.formatDate(root.now, "dddd, dd/MM")
        color: Theme.subtext0
        visible: Settings.clockShowDate
    }
}
