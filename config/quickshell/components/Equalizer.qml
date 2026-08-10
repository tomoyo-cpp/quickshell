import QtQuick
import "root:/"

// Spectrum visualiser, driven by cava's FFT bands.
//
// cava publishes more bands than any one visualiser draws, so this resamples
// Cava.values down to its own bar count. When cava has no frame yet — the
// first moments after it starts, or if it failed to attach to a source — it
// falls back to shaping the Pipewire peak, which is not a spectrum but keeps
// the widget alive rather than flat.
Item {
    id: root

    property real level: 0            // 0..1 live peak, fallback only
    property color accent: Theme.icon
    property real barWidth: 3
    property real minFraction: 0.08   // bars never collapse entirely

    // Gap between bars. -1 keeps the old proportional look.
    property real barGap: -1

    implicitHeight: 26

    // The bar count is derived from the available width rather than fixed, so
    // the spectrum always spans the full item at a constant density. A fixed
    // count would draw the same narrow strip whatever the width — and the
    // media title this sits behind changes width with the track and with the
    // configured font size.
    readonly property real pitch: root.barWidth + (root.barGap >= 0 ? root.barGap : Math.max(2, root.barWidth * 0.7))
    readonly property int bars: Math.max(3, Math.floor(root.width / root.pitch))

    // Spread the leftover across the gaps so the row ends exactly on the
    // item's edges instead of leaving a ragged remainder.
    readonly property real gapPx: root.bars > 1 ? (root.width - root.bars * root.barWidth) / (root.bars - 1) : 0

    readonly property bool live: Cava.values.length > 0
    readonly property var spectrum: root.live ? Cava.resample(root.bars) : []

    // Only ask cava to run while this is actually on screen — an idle cava is
    // a constant 60fps wakeup for nothing.
    property bool _held: false

    function _sync() {
        const want = root.visible && root.enabled;
        if (want === root._held)
            return;
        root._held = want;
        if (want)
            Cava.acquire();
        else
            Cava.release();
    }

    onVisibleChanged: root._sync()
    onEnabledChanged: root._sync()
    Component.onCompleted: root._sync()

    Component.onDestruction: if (root._held)
        Cava.release()

    // Fixed per-bar weights, used only by the fallback: a smooth arch, so the
    // middle bars swing widest and the outer ones stay calmer.
    readonly property var weights: {
        const w = [];
        for (let i = 0; i < root.bars; ++i) {
            const t = i / (root.bars - 1);
            w.push(0.45 + 0.55 * Math.sin(Math.PI * t));
        }
        return w;
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        width: root.width
        spacing: root.gapPx

        Repeater {
            model: root.bars

            Item {
                id: slot
                required property int index

                width: root.barWidth
                height: root.height

                property real value: root.minFraction

                // cava applies its own smoothing, so the band value is taken
                // straight; the Behavior below only covers the gap between
                // frames.
                readonly property real target: {
                    if (root.live) {
                        const s = root.spectrum;
                        return Math.max(root.minFraction, Math.min(1, s[slot.index] ?? 0));
                    }
                    const jitter = 0.75 + 0.25 * Math.abs(Math.sin(slot.index * 12.9898));
                    return Math.max(root.minFraction, Math.min(1, root.level * root.weights[slot.index] * jitter * 1.6));
                }

                onTargetChanged: slot.value = slot.target

                Behavior on value {
                    NumberAnimation {
                        // Quick to rise, slower to fall — the usual meter feel.
                        // Short enough not to smear cava's 60fps frames.
                        duration: root.live ? 55 : 90 + slot.index % 3 * 25
                        easing.type: Easing.OutQuad
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.barWidth
                    height: Math.max(root.barWidth, slot.height * slot.value)
                    radius: root.barWidth / 2
                    color: root.accent
                    opacity: 0.35 + 0.65 * slot.value
                }
            }
        }
    }
}
