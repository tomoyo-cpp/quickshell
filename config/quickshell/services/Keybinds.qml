pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// niri's keybinds, read from and written back to ~/.config/niri/config.kdl.
//
// niri watches its own config and reloads on change, so a rewrite takes effect
// without restarting anything. Since this edits the file that owns the whole
// session, writes are line-surgical: only the key token of a single line is
// ever replaced, and a backup is kept from before the first change.
Singleton {
    id: root

    readonly property string configPath: `${Quickshell.env("HOME")}/.config/niri/config.kdl`

    // [{ line: 187, key: "Mod+S", flags: "repeat=false", action: "spawn ...", raw: "..." }]
    property var binds: []
    property bool loaded: false
    property string error: ""

    // Line of the binds block's closing brace, where new binds are inserted.
    property int blockEnd: -1

    // Set while a rebind is in flight so the reload does not clobber the view.
    property bool writing: false

    // Every bind line looks like:
    //     <indent><KEY> [flags...] { <action>; }
    // The key is the first token; anything between it and the brace is flags
    // such as allow-when-locked=true or repeat=false, which must be preserved.
    // Trailing marker identifies binds this panel created, so only those offer
    // deletion — niri's own binds are not ours to remove. Verified with
    // `niri validate` that a trailing // comment parses fine.
    readonly property string customMark: "//qs-custom"

    readonly property var bindRe: /^(\s*)([A-Za-z0-9_+]+)((?:\s+[a-z-]+=[^\s{]+)*)\s*\{\s*(.*?)\s*\}\s*(\/\/\S*)?\s*$/

    // A bind that has been unbound is commented out with an explicit marker
    // rather than deleted, so the action survives and the old key can be
    // offered back. The marker matters: niri ships commented-out example
    // binds, and a bare `//` test would drag all of those into the list.
    readonly property string disabledMark: "//qs-unbound"
    readonly property var disabledRe: /^(\s*)\/\/qs-unbound\s+([A-Za-z0-9_+]+)((?:\s+[a-z-]+=[^\s{]+)*)\s*\{\s*(.*?)\s*\}\s*(\/\/\S*)?\s*$/

    function _parse(text) {
        const lines = text.split("\n");
        const out = [];

        let depth = 0;
        let inBinds = false;

        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i];
            const trimmed = line.trim();

            if (!inBinds) {
                if (/^binds\s*\{/.test(trimmed)) {
                    inBinds = true;
                    depth = 1;
                }
                continue;
            }

            // Track nesting so a nested block cannot end the section early.
            depth += (line.match(/\{/g) ?? []).length;
            depth -= (line.match(/\}/g) ?? []).length;
            if (depth <= 0) {
                root.blockEnd = i;
                break;
            }

            if (trimmed === "")
                continue;

            if (trimmed.startsWith("//")) {
                const d = root.disabledRe.exec(line);
                if (!d)
                    continue;   // an ordinary comment, or niri's own examples
                out.push({
                    line: i,
                    indent: d[1],
                    key: d[2],
                    flags: d[3] ?? "",
                    action: d[4],
                    disabled: true,
                    custom: (d[5] ?? "") === root.customMark,
                    raw: line
                });
                continue;
            }

            const m = root.bindRe.exec(line);
            if (!m)
                continue;

            out.push({
                line: i,
                indent: m[1],
                key: m[2],
                flags: m[3] ?? "",
                action: m[4],
                disabled: false,
                custom: (m[5] ?? "") === root.customMark,
                raw: line
            });
        }
        return out;
    }

    // niri's config carries prose comments rather than section headers, so
    // categories are derived from what each bind actually does. Order here is
    // the order they are shown in.
    readonly property var categories: ["Custom commands", "Media & hardware", "Screenshot", "Windows", "Workspaces", "Monitors", "Size & layout", "Overview", "Session", "Other"]

    function categoryOf(bind) {
        const k = bind.key;
        const a = bind.action;

        if (k.startsWith("XF86"))
            return "Media & hardware";
        if (a.includes("screenshot"))
            return "Screenshot";
        if (a.startsWith("spawn"))
            return "Custom commands";
        if (a.includes("overview"))
            return "Overview";
        if (/(^|\W)(quit|power-off-monitors|toggle-keyboard-shortcuts-inhibit|do-screen-transition)/.test(a))
            return "Session";
        if (a.includes("monitor"))
            return "Monitors";
        if (a.includes("workspace"))
            return "Workspaces";
        if (/(width|height|maximize|fullscreen|center|expand|preset|floating|tabbed)/.test(a))
            return "Size & layout";
        if (/(window|column|consume|expel|swap)/.test(a))
            return "Windows";
        return "Other";
    }

    // [{ title: "Applications", items: [...] }], empty categories dropped.
    readonly property var grouped: {
        const buckets = {};
        for (const b of root.binds) {
            const c = root.categoryOf(b);
            (buckets[c] = buckets[c] ?? []).push(b);
        }
        const out = [];
        for (const c of root.categories)
            if (buckets[c] && buckets[c].length > 0)
                out.push({
                    title: c,
                    items: buckets[c]
                });
        return out;
    }

    // Normalised for comparison: modifier order and case must not make two
    // identical binds look different.
    function normalise(combo) {
        const parts = combo.split("+").filter(p => p !== "");
        const mods = [];
        let key = "";
        for (const p of parts) {
            const low = p.toLowerCase();
            if (["mod", "super", "ctrl", "control", "alt", "shift"].includes(low))
                mods.push(low === "control" ? "ctrl" : low);
            else
                key = p.toLowerCase();
        }
        mods.sort();
        return mods.concat([key]).join("+");
    }

    // The bind already using this combo, if any. `exceptLine` lets a bind keep
    // its own key without reporting a clash with itself.
    function conflict(combo, exceptLine) {
        const target = root.normalise(combo);
        for (const b of root.binds) {
            if (b.line === exceptLine)
                continue;
            // An unbound entry holds its old key only as a memento; nothing
            // triggers it, so it cannot clash.
            if (b.disabled)
                continue;
            if (root.normalise(b.key) === target)
                return b;
        }
        return null;
    }

    function rebind(bind, combo) {
        if (combo === "" || root.conflict(combo, bind.line))
            return false;

        // Giving an unbound entry a key reactivates it: the write below emits
        // the plain form, without the marker.
        root._pendingMode = "";
        root.writing = true;
        root._pendingKey = combo;
        root._pendingLine = bind.line;
        // Re-read immediately before writing rather than trusting the copy in
        // memory: the file may have been edited by hand since it was loaded,
        // and a stale rewrite would silently revert those edits.
        rewriteReader.reload();
        return true;
    }

    property string _pendingKey: ""
    property int _pendingLine: -1
    // "disable" or "enable" for the two toggle paths; "" for a plain rebind.
    property string _pendingMode: ""

    // Whether a bind may be deleted outright, as opposed to merely unbound.
    //
    // Anything in "Custom commands" qualifies, not just lines this panel
    // wrote: they are all spawn commands the user chose, and the category
    // check already excludes niri's own window and workspace actions, whose
    // removal would be unrecoverable from the UI. Media keys land in
    // "Media & hardware" and so are excluded too. Every edit writes a backup
    // alongside the config first.
    function deletable(bind) {
        if (!bind)
            return false;
        return bind.custom === true || root.categoryOf(bind) === "Custom commands";
    }

    // Removes the line entirely.
    function removeBind(bind) {
        if (!root.deletable(bind))
            return false;
        root.writing = true;
        root._pendingLine = bind.line;
        root._pendingMode = "delete";
        rewriteReader.reload();
        return true;
    }

    // Keeps the line but stops anything triggering it.
    function unbind(bind) {
        if (bind.disabled)
            return false;
        root.writing = true;
        root._pendingLine = bind.line;
        root._pendingMode = "disable";
        rewriteReader.reload();
        return true;
    }

    // Puts an unbound entry back on its original key, if that key is free.
    function restore(bind) {
        if (!bind.disabled)
            return false;
        if (root.conflict(bind.key, bind.line))
            return false;
        root.writing = true;
        root._pendingLine = bind.line;
        root._pendingMode = "enable";
        rewriteReader.reload();
        return true;
    }
    // Non-empty means the pending write is an insert rather than a rebind.
    property string _pendingCommand: ""

    // Appends a new bind running `command` through sh. spawn-sh rather than
    // spawn because the command is typed freehand: it may contain pipes,
    // quotes or multiple statements, and spawn takes pre-split argv.
    function addBind(combo, command) {
        if (combo === "" || command.trim() === "" || root.conflict(combo, -1))
            return false;

        root.writing = true;
        root._pendingKey = combo;
        root._pendingCommand = command.trim();
        root._pendingLine = -1;
        rewriteReader.reload();
        return true;
    }

    function _applyPending(text) {
        const lines = text.split("\n");

        // Insert path.
        if (root._pendingCommand !== "") {
            if (root.blockEnd < 0 || root.blockEnd >= lines.length) {
                root.error = "could not find the binds block; nothing written";
                root.writing = false;
                root._pendingCommand = "";
                return;
            }
            // Escaped so a quote in the command cannot break out of the KDL
            // string and corrupt the rest of the file.
            const cmd = root._pendingCommand.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
            lines.splice(root.blockEnd, 0, `    ${root._pendingKey} { spawn-sh "${cmd}"; } ${root.customMark}`);

            backup.setText(text);
            writer.setText(lines.join("\n"));

            root._pendingKey = "";
            root._pendingCommand = "";
            settle.restart();
            return;
        }

        const i = root._pendingLine;
        if (i < 0 || i >= lines.length) {
            root.error = "bind line vanished; nothing written";
            root.writing = false;
            return;
        }

        // The line may currently be active or unbound; try both shapes.
        const m = root.bindRe.exec(lines[i]) ?? root.disabledRe.exec(lines[i]);
        if (!m) {
            root.error = "bind line no longer parses; nothing written";
            root.writing = false;
            root._pendingMode = "";
            return;
        }

        // Only the key token and the comment marker ever change; indent,
        // flags and action are carried over verbatim so nothing else in the
        // file can drift.
        const flags = m[3] ?? "";
        // Preserved verbatim, or a rebind would strip a custom bind's marker
        // and quietly make it undeletable.
        const mark = (m[5] ?? "") === "" ? "" : ` ${m[5]}`;

        if (root._pendingMode === "delete")
            lines.splice(i, 1);
        else if (root._pendingMode === "disable")
            lines[i] = `${m[1]}${root.disabledMark} ${m[2]}${flags} { ${m[4]} }${mark}`;
        else if (root._pendingMode === "enable")
            lines[i] = `${m[1]}${m[2]}${flags} { ${m[4]} }${mark}`;
        else
            lines[i] = `${m[1]}${root._pendingKey}${flags} { ${m[4]} }${mark}`;

        root._pendingMode = "";

        backup.setText(text);          // pre-change copy, written once per edit
        writer.setText(lines.join("\n"));

        root._pendingKey = "";
        root._pendingLine = -1;

        // FileView emits no usable save signal in this build — verified: the
        // write lands but neither onSaved nor onSaveFailed fires. So the
        // settle is timed rather than signalled, or `writing` would stay true
        // forever and the watcher would never refresh the list again.
        settle.restart();
    }

    Timer {
        id: settle
        interval: 200
        onTriggered: {
            root.writing = false;
            reader.reload();
        }
    }

    function reload() {
        reader.reload();
    }

    FileView {
        id: reader
        path: root.configPath
        preload: true
        watchChanges: true
        printErrors: false

        onFileChanged: if (!root.writing)
            reader.reload()

        onLoaded: {
            root.binds = root._parse(text());
            root.loaded = true;
            root.error = "";
        }

        onLoadFailed: {
            root.error = "could not read niri config";
            root.loaded = false;
        }
    }

    // Separate reader for the read-modify-write cycle, so a rewrite never
    // races the watcher above.
    FileView {
        id: rewriteReader
        path: root.configPath
        printErrors: false

        onLoaded: root._applyPending(text())
        onLoadFailed: {
            root.error = "could not re-read config; nothing written";
            root.writing = false;
        }
    }

    FileView {
        id: writer
        path: root.configPath
        atomicWrites: true
        printErrors: false
    }

    FileView {
        id: backup
        path: `${root.configPath}.qs-backup`
        atomicWrites: true
        printErrors: false
    }
}
