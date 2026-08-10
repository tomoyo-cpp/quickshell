pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// Per-day to-do items, persisted as JSON so they survive restarts.
//
// Shape on disk: { "2026-08-02": [ { text: "...", done: false }, ... ] }
Singleton {
    id: root

    readonly property string path: `${Quickshell.stateDir}/todos.json`

    // Mirror of the file, kept in a plain JS object so bindings can depend on
    // it. Reassigned wholesale on every edit so QML sees the change.
    property var byDay: ({})

    function key(date) {
        return Qt.formatDate(date, "yyyy-MM-dd");
    }

    function itemsFor(date) {
        return root.byDay[root.key(date)] ?? [];
    }

    function countFor(date) {
        return root.itemsFor(date).length;
    }

    function openCountFor(date) {
        return root.itemsFor(date).filter(t => !t.done).length;
    }

    function add(date, text) {
        const trimmed = (text ?? "").trim();
        if (trimmed === "")
            return;

        const k = root.key(date);
        const next = Object.assign({}, root.byDay);
        next[k] = (next[k] ?? []).concat([
            {
                text: trimmed,
                done: false
            }
        ]);
        root.byDay = next;
        root._save();
    }

    function toggle(date, index) {
        const k = root.key(date);
        const list = (root.byDay[k] ?? []).slice();
        if (index < 0 || index >= list.length)
            return;

        list[index] = Object.assign({}, list[index], { done: !list[index].done });
        const next = Object.assign({}, root.byDay);
        next[k] = list;
        root.byDay = next;
        root._save();
    }

    function remove(date, index) {
        const k = root.key(date);
        const list = (root.byDay[k] ?? []).slice();
        if (index < 0 || index >= list.length)
            return;

        list.splice(index, 1);
        const next = Object.assign({}, root.byDay);
        if (list.length === 0)
            delete next[k];
        else
            next[k] = list;
        root.byDay = next;
        root._save();
    }

    function _save() {
        writer.setText(JSON.stringify(root.byDay, null, 2));
    }

    FileView {
        id: writer
        path: root.path
        preload: true
        atomicWrites: true
        // Nothing else writes this file, so no need to watch it.
        printErrors: false

        onLoaded: {
            try {
                root.byDay = JSON.parse(text()) ?? {};
            } catch (e) {
                root.byDay = {};
            }
        }

        // A missing file on first run is expected, not an error.
        onLoadFailed: root.byDay = {}
    }
}
