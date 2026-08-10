import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "root:/"

// Now playing, hanging off the media widget in the bar.
PanelShell {
    id: root

    popupName: "media"
    bodyWidth: 440
    bodyHeight: 470

    readonly property var players: Mpris.players.values ?? []
    // Which pane the lower half shows. Not persisted: it is a glance, not a
    // preference, and the equalizer is the more common reason to open this.
    property bool showLyrics: false

    readonly property MprisPlayer player: {
        if (players.length === 0)
            return null;
        for (const p of players)
            if (p.isPlaying)
                return p;
        return players[0];
    }

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null

    // Quickshell does not poll MPRIS `Position` — it extrapolates between the
    // player's own updates and only re-reads on a non-linear change. That
    // extrapolation counts wall-clock time, so suspending the machine adds the
    // whole time the lid was shut: a 3:42 track came back reading 222:24 with
    // the bar pinned at the end, and stayed there.
    //
    // Clamped everywhere it is displayed. A position past the end of the track
    // is not a reading to be shown, whatever produced it.
    readonly property real position: {
        if (!root.player || !root.player.positionSupported)
            return 0;
        const p = root.player.position;
        if (root.player.lengthSupported && root.player.length > 0)
            return Math.max(0, Math.min(root.player.length, p));
        return Math.max(0, p);
    }

    // True when the player is reporting a position that cannot be real. Used to
    // decide whether to nudge it, so ordinary playback never gets touched.
    readonly property bool positionStale: root.player !== null && root.player.positionSupported && root.player.lengthSupported && root.player.length > 0 && root.player.position > root.player.length + 1

    // A zero seek is musically a no-op, but it is a non-linear change — the
    // player answers with where it really is, which is what resets the
    // extrapolation. Only sent when the reading is already impossible.
    //
    // Once per stale episode. A player is not obliged to answer a zero seek
    // with a Seeked signal, and retrying twice a second when it does not would
    // be a stream of pointless D-Bus traffic rather than a fix.
    property bool nudged: false

    onPositionStaleChanged: if (!root.positionStale)
        root.nudged = false

    function resync() {
        if (!root.positionStale || root.nudged || !root.player.canSeek)
            return;
        root.nudged = true;
        root.player.seek(0);
    }

    function formatTime(seconds) {
        if (!seconds || seconds <= 0)
            return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // A live audio tap, so it only runs while the panel is on screen.
    PwNodePeakMonitor {
        id: peak
        node: Pipewire.defaultAudioSink
        enabled: root.open
    }

    // `position` does not update reactively; poll it only while open.
    Timer {
        // Also runs while the reading is impossible, so a track paused across a
        // suspend still gets corrected instead of sitting at the wrong time
        // until someone presses play. Self-limiting: the resync clears it.
        running: root.open && root.player !== null && root.player.positionSupported && (root.player.isPlaying || (root.positionStale && !root.nudged))
        interval: 500
        repeat: true
        onTriggered: {
            root.player.positionChanged();
            root.resync();
        }
    }

    Caption {
        anchors.centerIn: parent
        visible: root.player === null
        text: "Nothing playing"
        color: Theme.overlay0
        size: 12
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        visible: root.player !== null

        // ── Art and track ────────────────────────────────────────────────
        Row {
            width: parent.width
            spacing: 12

            Rectangle {
                width: 74
                height: 74
                radius: 12
                color: Theme.alpha(Theme.surface0, 0.6)
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: source != ""
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.player || !root.player.trackArtUrl
                    text: "󰎈"
                    font.family: Theme.iconFont
                    font.pixelSize: 26
                    color: Theme.overlay0
                }
            }

            Column {
                width: parent.width - 86
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Caption {
                    vcenter: false
                    width: parent.width
                    text: root.player ? root.player.trackTitle || "Unknown track" : ""
                    color: Theme.icon
                    size: 14
                    font.bold: true
                    elide: Text.ElideRight
                }

                Caption {
                    vcenter: false
                    width: parent.width
                    text: root.player ? root.player.trackArtist || "" : ""
                    color: Theme.subtext0
                    size: 11
                    elide: Text.ElideRight
                }

                Caption {
                    vcenter: false
                    width: parent.width
                    visible: text !== ""
                    text: root.player ? root.player.trackAlbum || "" : ""
                    color: Theme.overlay1
                    size: 10
                    elide: Text.ElideRight
                }
            }
        }

        // Breaks out of the Column's 14px margins to span the frame edge to
        // edge. Column only manages y, so an explicit x is safe here.
        Equalizer {
            x: -14
            width: parent.width + 28
            height: 34
            barWidth: 3
            level: peak.peak
            accent: Theme.icon
        }

        // ── Seek ─────────────────────────────────────────────────────────
        LevelSlider {
            id: seekBar

            width: parent.width
            accent: Theme.icon
            // One seek when the drag ends, not one per mouse-move frame:
            // writing `position` repeatedly makes the decoder stutter audibly
            // while scrubbing.
            commitOnRelease: true
            value: root.player && root.player.lengthSupported && root.player.length > 0 ? root.position / root.player.length : 0
            onMoved: v => {
                if (root.player && root.player.canSeek && root.player.length > 0)
                    root.player.position = v * root.player.length;
            }
        }

        Item {
            width: parent.width
            height: 13

            Caption {
                anchors.left: parent.left
                // While scrubbing this reads the drag, not the player: the
                // seek has not happened yet, so the player still reports the
                // old position.
                text: root.formatTime(seekBar.dragging && root.player ? seekBar.dragValue * root.player.length : root.position)
                color: seekBar.dragging ? Theme.icon : Theme.overlay1
                size: 10
            }
            Caption {
                anchors.right: parent.right
                text: root.formatTime(root.player ? root.player.length : 0)
                color: Theme.overlay1
                size: 10
            }
        }

        // ── Transport, with volume alongside ─────────────────────────────
        Item {
            width: parent.width
            height: 38

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                MediaButton {
                    glyph: "󰒮"
                    onTriggered: if (root.player && root.player.canGoPrevious)
                        root.player.previous()
                }
                MediaButton {
                    glyph: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                    primary: true
                    onTriggered: if (root.player && root.player.canTogglePlaying)
                        root.player.togglePlaying()
                }
                MediaButton {
                    glyph: "󰒭"
                    onTriggered: if (root.player && root.player.canGoNext)
                        root.player.next()
                }
            }

            WaveSlider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 130
                accent: Theme.icon
                value: root.sinkAudio ? root.sinkAudio.volume : 0
                onMoved: v => {
                    if (root.sinkAudio) {
                        root.sinkAudio.volume = v;
                        root.sinkAudio.muted = v === 0;
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.surface0
        }

        // ── Equalizer / Lyrics ───────────────────────────────────────────
        // One region, two panes. The panel is already tall; stacking lyrics
        // under the equalizer would have pushed it past the screen.
        Item {
            width: parent.width
            height: 18

            Caption {
                id: paneTitle
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.showLyrics ? "Lyrics" : "Equalizer"
                color: Theme.icon
                size: 12
                font.bold: true
            }

            // Swaps the pane below. Sits next to the title so it reads as a
            // control on this section rather than on the panel.
            Rectangle {
                id: paneSwap
                anchors.left: paneTitle.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: swapLabel.implicitWidth + 16
                height: 16
                radius: 8
                color: swapMouse.containsMouse ? Theme.alpha(Theme.icon, 0.25) : Theme.alpha(Theme.surface0, 0.7)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.anim
                    }
                }

                Caption {
                    id: swapLabel
                    anchors.centerIn: parent
                    text: root.showLyrics ? "Equalizer" : "Lyrics"
                    color: Theme.subtext0
                    size: 9
                }

                MouseArea {
                    id: swapMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showLyrics = !root.showLyrics
                }
            }

            Caption {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.showLyrics
                text: Eq.custom ? "Custom" : Eq.preset
                color: Theme.overlay1
                size: 10
            }
        }

        // Both panes occupy the same 160px and cross-fade, drifting slightly
        // in opposite directions so the swap reads as one replacing the other
        // rather than two things blinking. Sized to the taller of the two —
        // the equalizer — so nothing below ever moves.
        Item {
            width: parent.width
            height: 160
            clip: true

            Column {
                id: eqPane

                width: parent.width
                spacing: 10

                opacity: root.showLyrics ? 0 : 1
                // Dropped from the layout once invisible, so its sliders stop
                // taking hover and its bindings stop being evaluated.
                visible: opacity > 0
                y: root.showLyrics ? -10 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.dur(200)
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: Theme.dur(260)
                        easing.type: Easing.OutCubic
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    Repeater {
                        model: 10

                        BandSlider {}
                    }
                }

                Grid {
                    width: parent.width
                    columns: 4
                    rowSpacing: 6
                    columnSpacing: 6

                    Repeater {
                        model: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]

                        PresetButton {
                            required property string modelData

                            name: modelData
                        }
                    }
                }
            }

            LyricsView {
                id: lyricsPane

                width: parent.width

                opacity: root.showLyrics ? 1 : 0
                visible: opacity > 0
                y: root.showLyrics ? 0 : 10

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.dur(200)
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: Theme.dur(260)
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    component BandSlider: Item {
        id: band

        required property int index

        readonly property real gain: Eq.gains[band.index]
        // 0 at the bottom of the track, 1 at the top.
        readonly property real fraction: (band.gain + Eq.range) / (Eq.range * 2)

        // The knob is centred on its position, so it overhangs each end of the
        // track by half its height. The track is inset by that much at both
        // ends to make room: a fully boosted band used to put the knob's centre
        // on the item's top edge, and the pane's clip sheared the top off it.
        // Sized to the hovered knob, which is the largest it gets.
        readonly property real knobMax: 13

        width: 24
        height: 96

        Rectangle {
            id: track
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: band.knobMax / 2
            anchors.bottom: label.top
            anchors.bottomMargin: 4 + band.knobMax / 2
            width: 3
            radius: 1.5
            color: Theme.alpha(Theme.icon, 0.18)

            // Fill runs from the centre, so cut and boost read differently.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                radius: parent.radius
                color: Theme.icon
                y: band.gain >= 0 ? track.height * (1 - band.fraction) : track.height / 2
                height: Math.max(1, Math.abs(band.fraction - 0.5) * track.height)
            }
        }

        Rectangle {
            id: knob
            anchors.horizontalCenter: parent.horizontalCenter
            y: track.y + track.height * (1 - band.fraction) - height / 2
            width: bandMouse.pressed || bandMouse.containsMouse ? band.knobMax : band.knobMax - 2
            height: width
            radius: width / 2
            color: Theme.icon

            Behavior on width {
                NumberAnimation {
                    duration: Theme.anim
                }
            }
        }

        Caption {
            id: label
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            vcenter: false
            text: Eq.frequencies[band.index]
            color: Theme.overlay1
            size: 9
        }

        MouseArea {
            id: bandMouse
            anchors.fill: parent
            anchors.margins: -3
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function emitAt(y) {
                const f = 1 - Math.max(0, Math.min(1, (y - track.y) / track.height));
                Eq.setBand(band.index, Math.round((f * 2 - 1) * Eq.range * 2) / 2);
            }

            onPressed: event => emitAt(event.y)
            onPositionChanged: event => {
                if (pressed)
                    emitAt(event.y);
            }
            // Double-click zeroes the band, the usual EQ convention.
            onDoubleClicked: Eq.setBand(band.index, 0)
        }
    }

    component PresetButton: Rectangle {
        id: pb

        required property string name

        readonly property bool selected: Eq.preset === pb.name && !Eq.custom

        width: (parent.width - 3 * 6) / 4
        height: 24
        radius: 8
        color: selected ? Theme.alpha(Theme.icon, 0.2) : pbMouse.containsMouse ? Theme.surface0 : Theme.alpha(Theme.surface0, 0.5)

        Behavior on color {
            ColorAnimation {
                duration: Theme.anim
            }
        }

        Caption {
            anchors.centerIn: parent
            text: pb.name
            color: pb.selected ? Theme.icon : Theme.subtext0
            size: 10
        }

        MouseArea {
            id: pbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Eq.applyPreset(pb.name)
        }
    }

    component MediaButton: Rectangle {
        id: mb

        property string glyph: ""
        property bool primary: false

        signal triggered

        width: mb.primary ? 36 : 30
        height: width
        radius: width / 2

        // A Row aligns children to the top, so the 30px buttons sat 3px above
        // centre next to the 36px play button.
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: mb.primary ? Theme.alpha(Theme.icon, 0.18) : mbMouse.containsMouse ? Theme.surface0 : Theme.alpha(Theme.surface0, 0.55)

        Behavior on color {
            ColorAnimation {
                duration: Theme.anim
            }
        }

        Text {
            anchors.centerIn: parent
            text: mb.glyph
            font.family: Theme.iconFont
            font.pixelSize: mb.primary ? 15 : 13
            color: Theme.icon
        }

        MouseArea {
            id: mbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mb.triggered()
        }
    }
}
