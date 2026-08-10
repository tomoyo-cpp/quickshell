pragma Singleton

import QtQuick
import Quickshell
import "root:/"
import Quickshell.Io

// Keeps niri's window outlines in step with the bar's accent and flavour.
//
// niri has no `include` directive, so unlike kitty this cannot be a generated
// side file — the colours are rewritten in place in config.kdl, the same way
// Keybinds.qml edits binds. niri reloads the config when the file changes, so
// the borders update without a restart.
//
// Only `active-color`, `inactive-color` and `urgent-color` inside the
// focus-ring and border blocks are touched; everything else, including the
// shadow's own `color`, is left exactly as written.
Singleton {
    id: root

    readonly property string configPath: `${Quickshell.env("HOME")}/.config/niri/config.kdl`

    readonly property string activeColor: Theme.accentFor(Settings.accent)
    readonly property string inactiveColor: Theme.palette.surface2
    readonly property string urgentColor: Theme.palette.red

    readonly property bool sizing: Settings.themeWindows

    // Marks the window-rule this service owns, so it can be rewritten without
    // disturbing the hand-written rules around it.
    readonly property string radiusMark: "//qs-window-radius"
    readonly property string cursorMark: "//qs-cursor"

    // Rewrite the colour keys inside focus-ring / border, leaving the rest of
    // the file byte-for-byte identical. Border width and gaps follow only when
    // the window-chrome toggle is on.
    function _apply(text) {
        const lines = text.split("\n");
        const wanted = {
            "active-color": root.activeColor,
            "inactive-color": root.inactiveColor,
            "urgent-color": root.urgentColor
        };

        let block = null;
        let depth = 0;
        let layoutDepth = 0;
        let inLayout = false;

        for (let i = 0; i < lines.length; i++) {
            let line = lines[i];

            // `gaps` sits directly in the layout block, not in a sub-block.
            if (!inLayout && /^\s*layout\s*\{/.test(line)) {
                inLayout = true;
                layoutDepth = (line.split("{").length - 1) - (line.split("}").length - 1);
            } else if (inLayout && block === null) {
                layoutDepth += (line.split("{").length - 1) - (line.split("}").length - 1);
                if (layoutDepth <= 0)
                    inLayout = false;
                else if (root.sizing) {
                    const g = line.replace(/^(\s*)gaps\s+\d+/, `$1gaps ${Settings.windowGaps}`);
                    if (g !== line) {
                        lines[i] = g;
                        line = g;
                    }
                }
            }

            if (block === null) {
                const open = /^\s*(focus-ring|border)\s*\{/.exec(line);
                if (open) {
                    block = open[1];
                    depth = (line.split("{").length - 1) - (line.split("}").length - 1);
                }
                continue;
            }

            depth += (line.split("{").length - 1) - (line.split("}").length - 1);
            if (depth <= 0) {
                block = null;
                continue;
            }

            for (const key in wanted) {
                const re = new RegExp(`^(\\s*)${key}\\s+"[^"]*"`);
                const next = line.replace(re, `$1${key} "${wanted[key]}"`);
                if (next !== line) {
                    lines[i] = next;
                    line = next;
                }
            }

            if (root.sizing) {
                const w = line.replace(/^(\s*)width\s+\d+(\.\d+)?/, `$1width ${Settings.windowBorderWidth}`);
                if (w !== line) {
                    lines[i] = w;
                    line = w;
                }
            }
        }

        return root._applyCursor(root._applyRadius(lines.join("\n")));
    }

    // The pointer lives in a top-level `cursor` block. Written here rather
    // than from the cursor picker itself so config.kdl keeps a single writer —
    // two services rewriting the same file race, and this one already re-reads
    // from disk before every write to avoid clobbering hand edits.
    //
    // niri reloads on change, so the pointer updates without a restart. It
    // also exports XCURSOR_THEME to what it spawns, which is what carries the
    // choice into GTK and Qt clients.
    function _applyCursor(text) {
        if (!Settings.cursorTheme)
            return text;

        const theme = Settings.cursorTheme;
        const size = Settings.cursorSize;

        if (/^\s*cursor\s*\{/m.test(text)) {
            // Only the two keys are touched; hide-when-typing and the rest of
            // the block stay as written.
            let out = text.replace(/^(\s*)xcursor-theme\s+"[^"]*"/m, `$1xcursor-theme "${theme}"`);
            out = out.replace(/^(\s*)xcursor-size\s+\d+/m, `$1xcursor-size ${size}`);
            // A cursor block that never had the keys needs them adding.
            if (!/xcursor-theme/.test(out))
                out = out.replace(/^(\s*)cursor\s*\{/m, `$1cursor {\n$1    xcursor-theme "${theme}"\n$1    xcursor-size ${size}`);
            return out;
        }

        return text.replace(/\s*$/, "") + `\n\n${root.cursorMark}\ncursor {\n    xcursor-theme "${theme}"\n    xcursor-size ${size}\n}\n`;
    }

    // Corner radius has no top-level key — it lives in a window rule.
    //
    // The stock config already ships an active rounded-corners rule (its
    // comment claims it is commented out, but it is not), so this updates
    // whatever rule is already there rather than appending its own. Appending
    // would leave two rules both matching every window, with the later one
    // silently winning.
    function _applyRadius(text) {
        if (!root.sizing)
            return text;

        if (/geometry-corner-radius\s+\d+/.test(text))
            return text.replace(/(geometry-corner-radius\s+)\d+/g, `$1${Settings.windowRadius}`);

        // Nothing to adopt — add one, marked so it is recognisable as ours.
        const rule = `${root.radiusMark}
window-rule {
    geometry-corner-radius ${Settings.windowRadius}
    clip-to-geometry true
}`;
        return text.replace(/\s*$/, "") + "\n\n" + rule + "\n";
    }

    // Always re-read from disk before rewriting.
    //
    // This file is edited by hand, by niri's own tooling and by Keybinds, so a
    // copy held in memory since startup goes stale. Writing that copy back
    // silently reverted every edit made since — an accent change was enough to
    // undo a hand-edited focus-follows-mouse line.
    function sync() {
        reader.reload();
    }

    function _rewrite(text) {
        if (!text)
            return;

        const updated = root._apply(text);

        // Nothing to do — and importantly, no write, so niri is not asked to
        // reload on every settings change and this cannot feed itself.
        if (updated === text)
            return;

        backup.setText(text);
        writer.setText(updated);
    }

    // Coalesces a flavour change (which moves three colours at once) into a
    // single rewrite.
    onActiveColorChanged: settle.restart()
    onInactiveColorChanged: settle.restart()
    onUrgentColorChanged: settle.restart()
    onSizingChanged: settle.restart()

    Connections {
        target: Settings
        function onWindowBorderWidthChanged() { settle.restart(); }
        function onWindowRadiusChanged() { settle.restart(); }
        function onWindowGapsChanged() { settle.restart(); }
        function onCursorThemeChanged() { settle.restart(); }
        function onCursorSizeChanged() { settle.restart(); }
    }

    Timer {
        id: settle
        interval: 300
        onTriggered: root.sync()
    }

    // Read side only. Reloading re-reads from disk, and the rewrite happens in
    // onLoaded so it always acts on current content.
    FileView {
        id: reader
        path: root.configPath
        preload: true
        printErrors: false

        onLoaded: root._rewrite(reader.text())
    }

    // Write side. Separate from the reader so a write cannot be mistaken for
    // fresh content; the reload it triggers finds nothing left to change and
    // the cycle stops there.
    FileView {
        id: writer
        path: root.configPath
        atomicWrites: true
        printErrors: false
    }

    FileView {
        id: backup
        path: `${root.configPath}.qs-theme-backup`
        atomicWrites: true
        printErrors: false
    }
}
