import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import "root:/"

Pill {
    id: root

    required property var bar


    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null

    readonly property var activeWifi: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null
    readonly property bool wiredUp: wiredDevice !== null && wiredDevice.connected

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: adapter !== null && adapter.enabled
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)

    readonly property string wifiGlyph: {
        if (wiredUp)
            return "󰈀";
        if (!Networking.wifiEnabled)
            return "󰤭";
        if (!activeWifi)
            return "󰤮";
        const s = activeWifi.signalStrength ?? 0;
        if (s >= 75)
            return "󰤨";
        if (s >= 50)
            return "󰤥";
        if (s >= 25)
            return "󰤢";
        return "󰤟";
    }

    // Networks worth listing: named, sorted strongest first.
    readonly property var visibleNetworks: {
        if (!wifiDevice)
            return [];
        return wifiDevice.networks.values.filter(n => n.name && n.name !== "").sort((a, b) => (b.signalStrength ?? 0) - (a.signalStrength ?? 0)).slice(0, 12);
    }

    active: bar.openPopup === "network"
    accent: Theme.blue
    innerSpacing: 7

    onClicked: bar.togglePopup("network")


    Glyph {
        text: root.wifiGlyph
        color: Theme.icon
    }

    Glyph {
        text: root.btConnected.length > 0 ? "󰂱" : root.btOn ? "󰂯" : "󰂲"
        color: Theme.icon
        size: 14
    }
}
