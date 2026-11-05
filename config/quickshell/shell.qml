//@ pragma UseQApplication

import Quickshell

ShellRoot {
    // One bar per monitor. Variants injects `modelData` into each instance.
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // The wallpaper: sharp behind windows (gone in the overview), and a
    // blurred copy in niri's backdrop.
    Variants {
        model: Quickshell.screens

        Wallpaper {}
    }
    Variants {
        model: Quickshell.screens

        Wallpaper {
            backdrop: true
        }
    }

    // Notification toasts (primary screen).
    Toasts {}

    // Lock screen, drawn like ly. Idle until `qs ipc call lock lock`.
    Lock {}

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

    // GTK apps. No-op unless its toggle is on.
    property var gtkTheme: GtkTheme

    // And Spotify, restyled in place over the devtools protocol.
    property var spotifyTheme: SpotifyTheme
}
