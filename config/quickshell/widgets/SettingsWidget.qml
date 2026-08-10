import QtQuick
import Quickshell.Services.Pipewire
import "root:/"

// Volume and brightness, behind one gear.
Pill {
    id: root

    required property var bar

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property int volume: sinkAudio ? Math.round(sinkAudio.volume * 100) : 0
    readonly property bool muted: sinkAudio ? sinkAudio.muted : true
    readonly property bool open: bar.openPopup === "dashboard" && bar.dashboardSource === "settings"

    active: open
    accent: Theme.text
    padding: 9

    // Page 2 is Settings. The index has moved twice as pages were removed, so
    // it is not a stable thing to hardcode blindly.
    onClicked: bar.openDashboardNamed("settings", "settings")

    // Scrolling the gear itself adjusts volume without opening anything.
    onScrolled: delta => {
        if (!sinkAudio)
            return;
        const next = sinkAudio.volume + (delta > 0 ? 0.05 : -0.05);
        sinkAudio.volume = Math.max(0, Math.min(1, next));
        if (next > 0)
            sinkAudio.muted = false;
    }

    // Keeps the default sink bound so its audio properties stay live.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Glyph {
        text: "󰒓"
        color: Theme.icon
    }

}
