//@ pragma UseQApplication

import Quickshell

ShellRoot {
    // One bar per monitor. Variants injects `modelData` into each instance.
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // Notification toasts (primary screen).
    Toasts {}

    // Volume / brightness overlay.
    Osd {}

    // Stop control for the guided tour, shown only while it runs.
    PreviewStop {}

    // Battery warnings. A QML singleton is created lazily and nothing else
    // refers to this one, so this binding is what brings it to life.
    property var batteryAlert: BatteryAlert

    // Same reason: keeps kitty's colours following the selected flavour.
    property var kittyTheme: KittyTheme

    // And niri's window outlines.
    property var niriTheme: NiriTheme

    // GTK apps and the lock screen. Both no-op unless their toggle is on.
    property var gtkTheme: GtkTheme
    property var swaylockTheme: SwaylockTheme

    // And Spotify, restyled in place over the devtools protocol.
    property var spotifyTheme: SpotifyTheme
}
