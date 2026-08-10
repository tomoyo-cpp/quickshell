pragma Singleton

import QtQuick
import Quickshell
import "root:/"
import Quickshell.Io

// Named snapshots of the appearance settings.
//
// Stores whatever keys are in Settings.keyGroups.appearance rather than a
// fixed list, so a setting added to that group is captured by every preset
// saved afterwards without touching this file.
Singleton {
    id: root

    // [{ name: "Night", values: { accent: "mauve", ... } }, ...]
    property var presets: []

    readonly property var keys: Settings.keyGroups.appearance

    function names() {
        return root.presets.map(p => p.name);
    }

    function find(name) {
        return root.presets.find(p => p.name === name) ?? null;
    }

    // Saving under an existing name overwrites it, which is what the UI's
    // "save" over a selected preset should do.
    function save(name) {
        const trimmed = (name ?? "").trim();
        if (!trimmed)
            return false;

        const values = {};
        for (const k of root.keys)
            values[k] = Settings[k];

        const next = root.presets.filter(p => p.name !== trimmed);
        next.push({
            name: trimmed,
            values: values
        });
        next.sort((a, b) => a.name.localeCompare(b.name));
        root.presets = next;
        root._persist();
        return true;
    }

    function apply(name) {
        const p = root.find(name);
        if (!p)
            return;

        for (const k in p.values) {
            // A preset saved before a key existed simply does not carry it.
            if (root.keys.indexOf(k) !== -1)
                Settings.set(k, p.values[k]);
        }
    }

    function remove(name) {
        root.presets = root.presets.filter(p => p.name !== name);
        root._persist();
    }

    // True when every stored value matches the live setting, so the UI can
    // mark which preset is currently in effect.
    function isActive(name) {
        const p = root.find(name);
        if (!p)
            return false;

        for (const k in p.values) {
            if (root.keys.indexOf(k) === -1)
                continue;
            if (Settings[k] !== p.values[k])
                return false;
        }
        return true;
    }

    function _persist() {
        file.setText(JSON.stringify(root.presets, null, 2));
    }

    FileView {
        id: file
        path: `${Quickshell.stateDir}/theme-presets.json`
        preload: true
        atomicWrites: true
        printErrors: false

        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.presets = Array.isArray(parsed) ? parsed : [];
            } catch (e) {
                root.presets = [];
            }
        }
    }
}
