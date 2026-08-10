pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// Keeps Spotify's colours in step with the bar.
//
// Unlike the other theming services this one writes nothing itself. Spotify's
// palette lives inside a spicetify-patched bundle, and rewriting that takes
// half a minute — far too slow to sit behind a slider. So the work is done by
// ~/.local/bin/spotify-theme, which does two things: pushes the palette into
// the running client as CSS variables over the CEF devtools protocol, and
// updates the theme's own CSS so the next launch starts correct.
//
// The live push is the same idea as KittyTheme's `kitty @ set-colors`: talk to
// the running program rather than restarting it. Spotify's audio is in the
// native process, not the web view, so restyling never interrupts playback.
Singleton {
    id: root

    readonly property bool enabled: Settings.themeSpotify

    // Only the values Spotify actually renders from. Deliberately not bound to
    // Theme.accent itself: that is a colour, and a flavour change can leave it
    // identical while every surface around it moves.
    readonly property string signature: `${Settings.flavour}/${Settings.accent}`

    onSignatureChanged: if (root.enabled)
        pushDelay.restart()

    onEnabledChanged: if (root.enabled)
        pushDelay.restart()

    // Clicking through accent swatches would otherwise fire a process per
    // click, and each one opens a websocket to the client.
    Timer {
        id: pushDelay
        interval: 300
        onTriggered: push.running = true
    }

    // The flavour and accent are passed rather than left to be read back from
    // settings.json. Settings debounces its writes by 400ms, so a helper
    // launched by the change and reading the file would race the save and
    // apply the *previous* accent — which is exactly what happened while this
    // debounce was shorter than that one.
    //
    // Failure is silent and expected: Spotify is usually not running, and the
    // devtools port only exists when it was launched with the flag. The colour
    // scheme on disk is still updated in that case, so the next launch is
    // correct either way.
    Process {
        id: push
        command: [`${Quickshell.env("HOME")}/.local/bin/spotify-theme`, "--live", "--flavour", Settings.flavour, "--use-accent", Settings.accent]
    }

    // Push once at startup so a flavour changed while the shell was down —
    // or while Spotify was closed — is picked up.
    Component.onCompleted: if (root.enabled)
        pushDelay.restart()
}
