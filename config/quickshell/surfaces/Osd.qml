import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pipewire
import "root:/"

// Volume / brightness overlay. One window serves both — a change just swaps
// `mode` and restarts the timer, so it is never torn down and rebuilt. Slides
// up from the bottom, stays 1.5s, then fades out. The bar inside is draggable,
// so it doubles as a control rather than a read-only indicator.
PanelWindow {
    id: root

    // "volume" | "brightness" | "keyboard"
    property string mode: "volume"
    property bool showing: false

    // 0 hidden, 1 fully out. Drives opacity and the slide offset together.
    property real reveal: showing ? 1 : 0

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property bool muted: sinkAudio ? sinkAudio.muted : false
    readonly property int volume: sinkAudio ? Math.round(sinkAudio.volume * 100) : 0

    readonly property int value: mode === "volume" ? volume : Backlight.percent

    // Keyboard layout has no level to show — it flashes the name instead.
    readonly property bool levelMode: mode !== "keyboard"

    readonly property string glyph: {
        if (mode === "keyboard")
            return "󰌌";
        if (mode === "brightness")
            return "󰃠";
        return muted ? "󰝟" : "󰕾";
    }

    // Property changes fire once on startup as the services settle; ignore
    // those so the overlay only reacts to real user input.
    property bool armed: false

    function trigger(which) {
        if (!root.armed)
            return;
        root.mode = which;
        root.showing = true;
        hideTimer.restart();
    }

    anchors {
        bottom: true
    }

    margins {
        bottom: 40
    }

    exclusiveZone: 0
    color: "transparent"
    implicitWidth: 330
    implicitHeight: Theme.barHeight + Theme.shadowPad * 2

    // Keep the window mapped until the fade-out finishes.
    visible: Settings.osdEnabled && reveal > 0.01

    // Only the card should catch clicks, not the full window strip.
    mask: Region {
        item: card
    }

    Behavior on reveal {
        NumberAnimation {
            duration: Theme.dur(220)
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.showing = false
    }

    Timer {
        running: true
        interval: 1500
        onTriggered: root.armed = true
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        target: root.sinkAudio
        ignoreUnknownSignals: true

        function onVolumesChanged() {
            root.trigger("volume");
        }

        function onMutedChanged() {
            root.trigger("volume");
        }
    }

    // Fires on every layout switch, which is exactly when the feedback is
    // wanted — the bar icon stays uncluttered the rest of the time.
    Connections {
        target: Niri

        function onLayoutIndexChanged() {
            root.trigger("keyboard");
        }
    }

    Connections {
        target: Backlight

        function onPercentChanged() {
            root.trigger("brightness");
        }
    }

    Item {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - Theme.shadowPad * 2
        height: Theme.barHeight

        opacity: root.reveal
        // Slides up as it fades in.
        y: (parent.height - height) / 2 + (1 - root.reveal) * 16

        // Same construction as the bar strip, so the translucency matches
        // exactly rather than only using the same colour value.
        Rectangle {
            id: cardBg
            anchors.fill: parent
            radius: Theme.barRadius
            color: Theme.barBg
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: cardBg
            source: cardBg
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.45
            shadowBlur: 0.7
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
        }

        Item {
            id: osdIcon
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22

            Glyph {
                anchors.centerIn: parent
                vcenter: false
                text: root.glyph
                size: 19
                color: root.mode === "volume" && root.muted ? Theme.overlay0 : Theme.icon
            }
        }

        Caption {
            anchors.left: osdIcon.right
            anchors.leftMargin: 15
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.levelMode
            text: Niri.layoutNames[Niri.layoutIndex] ?? ""
            color: Theme.icon
            size: 13
            font.bold: true
        }

        LevelSlider {
            visible: root.levelMode
            anchors.left: osdIcon.right
            anchors.leftMargin: 15
            anchors.right: osdValue.left
            anchors.rightMargin: 15
            anchors.verticalCenter: parent.verticalCenter

            accent: root.mode === "volume" && root.muted ? Theme.overlay0 : Theme.icon
            value: root.value / 100

            onMoved: v => {
                // Keep the overlay up while it is being dragged.
                hideTimer.restart();

                if (root.mode === "volume") {
                    if (root.sinkAudio) {
                        root.sinkAudio.volume = v;
                        root.sinkAudio.muted = v === 0;
                    }
                } else {
                    Backlight.set(v * 100);
                }
            }
        }

        Caption {
            id: osdValue
            visible: root.levelMode
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: `${root.value}%`
            color: Theme.icon
            size: 13
            font.bold: true
            // Reserve room for "100%" so the slider does not jitter as the
            // number changes width.
            width: 38
            horizontalAlignment: Text.AlignRight
        }
    }
}
