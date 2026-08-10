import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "root:/"

Pill {
    id: root

    required property var bar

    // Prefer whatever is actually playing, otherwise the first known player.
    readonly property MprisPlayer player: {
        const list = Mpris.players.values;
        if (!list || list.length === 0)
            return null;
        for (const p of list)
            if (p.isPlaying)
                return p;
        return list[0];
    }

    // Empty when there is genuinely nothing to name — a player can exist with
    // no metadata yet, which reads the same as no player at all.
    readonly property string trackLabel: {
        if (!player)
            return "";
        const title = player.trackTitle || "";
        const artist = player.trackArtist || "";
        if (title && artist && Settings.mediaShowArtist)
            return `${title} • ${artist}`;
        return title || artist || player.identity || "";
    }

    readonly property bool hasTrack: root.trackLabel !== ""

    // The pill keeps its place when nothing is playing rather than vanishing,
    // so the bar does not reflow every time a player comes and goes. Same
    // wording as the panel's empty state.
    readonly property string label: root.hasTrack ? root.trackLabel : "Nothing playing"

    // Clamped: Quickshell extrapolates `position` on wall-clock time between
    // the player's own updates, so a suspend adds the whole time the lid was
    // shut and the raw value can land well past the end of the track. The ring
    // fills rather than wrapping round. MediaPanel does the same for its
    // timestamp, and nudges the player back into sync from there.
    readonly property real progress: {
        if (!player || !player.lengthSupported || !player.positionSupported)
            return 0;
        if (player.length <= 0)
            return 0;
        return Math.max(0, Math.min(1, player.position / player.length));
    }

    interactive: false

    // Live audio tap, only while something is actually playing.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    PwNodePeakMonitor {
        id: peak
        node: Pipewire.defaultAudioSink
        enabled: root.visible && root.player !== null && root.player.isPlaying
    }

    // Spans exactly the title's width rather than the whole pill, so it reads
    // as a backdrop for the text and leaves the play ring clear.
    backgroundContent: Equalizer {
        x: root.contentRow.x + title.x
        width: title.width
        height: parent.height
        level: peak.peak
        accent: Theme.icon
        barWidth: Settings.visualiserBarWidth
        minFraction: 0.05
        // Gated on there being a track, not just on the pill being on screen.
        // The pill is now always shown, and a visible Equalizer holds cava
        // open at 60fps — idling one behind "Nothing playing" would burn a
        // wakeup a frame for a spectrum of silence.
        visible: Settings.showVisualiser && root.hasTrack
        // Kept faint: it is a backdrop for the title, not a readout.
        opacity: Settings.visualiserOpacity
    }
    innerSpacing: 8
    padding: 8

    // `position` deliberately does not update reactively — poll it while playing.
    Timer {
        running: root.player !== null && root.player.isPlaying && root.player.positionSupported
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    // Standalone play/pause button.
    Item {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: ring.implicitWidth
        implicitHeight: ring.implicitHeight

        CircleGauge {
            id: ring

            // Bar rings are small, so the gap needs a wider angle to read.
            gapDegrees: 20
            anchors.centerIn: parent
            value: root.progress
            glyph: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
            // Dimmer with nothing loaded, so the idle pill reads as a resting
            // control rather than as something waiting to be pressed.
            opacity: ringMouse.containsMouse ? 1 : (root.hasTrack ? 0.85 : 0.4)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim
                }
            }
        }

        MouseArea {
            id: ringMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onClicked: event => {
                // With no player there is nothing to toggle, but the button is
                // on screen now — so it opens the panel rather than doing
                // nothing at all.
                if (!root.player) {
                    root.bar.togglePopup("media");
                    return;
                }
                if (event.button === Qt.RightButton && root.player.canGoNext)
                    root.player.next();
                else if (event.button === Qt.MiddleButton && root.player.canGoPrevious)
                    root.player.previous();
                else if (root.player.canTogglePlaying)
                    root.player.togglePlaying();
            }

            onWheel: event => {
                if (!root.player)
                    return;
                if (event.angleDelta.y > 0 && root.player.canGoPrevious)
                    root.player.previous();
                else if (event.angleDelta.y < 0 && root.player.canGoNext)
                    root.player.next();
            }
        }
    }

    // Clickable, but deliberately not styled as a button — it just opens the
    // dashboard's media page.
    MarqueeText {
        id: title

        text: root.label
        color: titleMouse.containsMouse ? Theme.icon : (root.hasTrack ? Theme.subtext1 : Theme.overlay1)

        MouseArea {
            id: titleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: root.bar.togglePopup("media")
        }
    }
}
