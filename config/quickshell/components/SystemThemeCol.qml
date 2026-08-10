import QtQuick
import "root:/"

// Which programs outside the bar follow its theme.
SettingsCol {
    id: col

    title: "Applications"
    group: "theming"

    ToggleSwitch {
        label: "GTK apps"
        checked: Settings.themeGtk
        onToggled: Settings.set("themeGtk", !Settings.themeGtk)
    }

    Caption {
        vcenter: false
        // Only one Catppuccin GTK variant is packaged until the four in
        // configuration.nix are built, so GTK follows light/dark and the icon
        // theme before it follows the flavour's hue.
        visible: Settings.themeGtk
        text: "Follows light/dark and icon theme"
        color: Theme.overlay0
        size: 10
        wrapMode: Text.WordWrap
        width: parent.width
    }

    ToggleSwitch {
        label: "Lock screen"
        checked: Settings.themeSwaylock
        onToggled: Settings.set("themeSwaylock", !Settings.themeSwaylock)
    }

    ToggleSwitch {
        label: "Terminal"
        checked: Settings.themeTerminal
        onToggled: Settings.set("themeTerminal", !Settings.themeTerminal)
    }

    // Its own control rather than following barOpacity: how far you can see
    // through the bar and how far you can see through text you are reading
    // are different judgements.
    Pct {
        label: "Terminal opacity"
        value: Settings.terminalOpacity
        dimmed: !Settings.themeTerminal
        onPicked: v => Settings.set("terminalOpacity", v)
    }

    ToggleSwitch {
        label: "Spotify"
        checked: Settings.themeSpotify
        onToggled: Settings.set("themeSpotify", !Settings.themeSpotify)
    }

    // Says so rather than failing quietly: this one depends on a patched copy
    // of Spotify that lives outside the shell, and the toggle cannot tell
    // whether it is there.
    Caption {
        vcenter: false
        visible: Settings.themeSpotify
        width: parent.width
        text: "Needs the spicetify copy — run spotify-sync once."
        color: Theme.overlay0
        size: 9
        wrapMode: Text.WordWrap
    }
}
