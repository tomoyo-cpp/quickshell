import QtQuick
import "root:/"

// Compositor window chrome, written into niri's config.
SettingsCol {
    id: col

    title: "Windows"
    group: "windows"

    ToggleSwitch {
        label: "Manage borders"
        checked: Settings.themeWindows
        onToggled: Settings.set("themeWindows", !Settings.themeWindows)
    }

    Caption {
        vcenter: false
        visible: !Settings.themeWindows
        text: "Off: niri's own border settings are left alone."
        color: Theme.overlay0
        size: 10
        wrapMode: Text.WordWrap
        width: parent.width
    }

    Setting {
        visible: Settings.themeWindows
        label: "Border size"
        value: Settings.windowBorderWidth
        from: 0
        to: 8
        onMoved: v => Settings.set("windowBorderWidth", v)
    }

    Setting {
        visible: Settings.themeWindows
        label: "Corner radius"
        value: Settings.windowRadius
        from: 0
        to: 24
        onMoved: v => Settings.set("windowRadius", v)
    }

    Setting {
        visible: Settings.themeWindows
        label: "Window gaps"
        value: Settings.windowGaps
        from: 0
        to: 32
        onMoved: v => Settings.set("windowGaps", v)
    }
}
