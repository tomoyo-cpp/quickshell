pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// Runtime-configurable bar settings, persisted as JSON.
//
// Theme reads its metrics and colours from here, so changing a value re-lays
// out or recolours the bar immediately; the file is only the storage.
Singleton {
    id: root

    // ── Sizing ───────────────────────────────────────────────────────────
    property int barHeight: 38
    property int barMargin: 8
    property int barSideMargin: 16
    // Right edge. Ignored while linkSideMargins is on, which is the default —
    // one slider is what most people want.
    property int barSideMarginRight: 16
    property bool linkSideMargins: true
    property int barRadius: 13
    // Corners of everything that hangs off the bar: the dropdown panels, the
    // launcher, the dashboard, toasts. Separate from barRadius because the two
    // are different judgements — a square bar strip with rounded panels under
    // it is a look, and tying them together made squaring the bar square every
    // panel as a side effect.
    property int panelRadius: 16
    property int gap: 6
    property int iconSize: 18
    property int fontSize: 13

    // Space tiled windows leave for the bar, over and above its height.
    // Deliberately separate from barMargin: raising the top margin floats the
    // bar further down its gap rather than shoving every window down with it.
    property int reservedMargin: 8

    // ── Inner geometry ───────────────────────────────────────────────────
    property int containerInset: 4
    property int containerRadius: 14
    property int pillPadding: 9
    property int workspaceIconSize: 16

    // ── System-wide theming ──────────────────────────────────────────────
    // Whether the flavour is pushed beyond the bar. Kept out of the
    // "appearance" group so resetting colours does not silently turn these
    // off, and so theme presets carry the look without the plumbing.
    property bool themeGtk: false
    property bool themeSwaylock: false

    // The terminal has followed the bar's colours since kitty theming landed,
    // so this defaults on. Its transparency is its own control rather than
    // barOpacity: a bar you can see through and a terminal you can read
    // through are different judgements.
    property bool themeTerminal: true
    property real terminalOpacity: 0.9

    // Spotify, through spicetify. Off by default: it needs the patched
    // copy that ~/.local/bin/spotify-sync builds, and does nothing without it.
    property bool themeSpotify: false

    // Pointer. Empty means "leave whatever niri and the toolkits already do"
    // — picking a theme in the Appearance tab is what opts in, so a fresh
    // install does not silently take the cursor over.
    property string cursorTheme: ""
    property int cursorSize: 24

    // Compositor window chrome, written into niri's config. Off by default so
    // the bar does not take over the border settings until asked.
    property bool themeWindows: false
    property int windowBorderWidth: 2
    property int windowRadius: 8
    property int windowGaps: 16

    // ── Appearance ───────────────────────────────────────────────────────
    // Palette key from Theme.palette — "text" is the original all-white look.
    property string accent: "text"
    // mocha | macchiato | frappe | latte
    property string flavour: "mocha"

    property real barOpacity: 0.9
    property real containerOpacity: 0.5
    property real panelOpacity: 0.97

    property bool shadowEnabled: true
    property real shadowOpacity: 0.45
    property real shadowBlur: 0.7

    // ── Clock ────────────────────────────────────────────────────────────
    property bool clockUse24h: true
    property bool clockShowSeconds: false
    property bool clockShowDate: true
    // Non-empty overrides all of the above, using Qt's date/time format.
    property string clockFormat: ""

    // ── Media ────────────────────────────────────────────────────────────
    property int mediaMaxWidth: 170
    property int mediaScrollSpeed: 26
    property bool mediaShowArtist: true
    property bool showVisualiser: true
    property real visualiserOpacity: 0.28
    property int visualiserBarWidth: 2

    // ── Battery ──────────────────────────────────────────────────────────
    // Bands: <= low is red, <= mid orange, <= high yellow, above it green.
    property int batteryLow: 15
    property int batteryMid: 30
    property int batteryHigh: 60
    property bool batteryFlash: true
    property bool batteryAlerts: true
    property bool batteryShowPercent: true

    // ── Workspaces ───────────────────────────────────────────────────────
    property bool workspaceShowIcons: true
    property bool workspaceShowEmpty: true
    property int workspaceMaxIcons: 4

    // ── Notifications ────────────────────────────────────────────────────
    // left | right
    property string toastPosition: "right"
    property int toastDuration: 5000
    property int toastMaxVisible: 4
    property bool dnd: false

    // ── Behaviour ────────────────────────────────────────────────────────
    property bool animationsEnabled: true
    // Multiplier on every transition; higher is slower.
    property real animSpeed: 1.0

    // ── Clipboard and launcher ───────────────────────────────────────────
    property bool clipboardThumbnails: true
    // Written into niri's config and reloaded, since the cap belongs to the
    // `wl-paste --watch cliphist store` process it spawns.
    property int clipboardMaxItems: 15
    property int launcherRecentCount: 6

    // ── Cava ─────────────────────────────────────────────────────────────
    property int cavaBands: 48
    property int cavaFramerate: 60
    property real cavaSmoothing: 0.55

    // ── Night light ──────────────────────────────────────────────────────
    property int nightTemp: 4000

    // ── Widgets ──────────────────────────────────────────────────────────
    property bool showSysMon: true
    property bool showMedia: true
    property bool showLauncher: true
    property bool showOverview: true
    property bool showScreenshot: true
    property bool showRecorder: false
    property bool showKeyboard: true
    property bool showClipboard: true
    property bool showBattery: true
    property bool showNetwork: true

    // ── Popups ───────────────────────────────────────────────────────────
    property bool osdEnabled: true
    property bool toastsEnabled: true

    // Every persisted key, grouped so a new setting is added in one place and
    // save, load and reset all pick it up.
    readonly property var keyGroups: ({
            sizing: ["barHeight", "barMargin", "barSideMargin", "barSideMarginRight", "linkSideMargins", "barRadius", "panelRadius", "gap", "iconSize", "fontSize", "reservedMargin"],
            inner: ["containerInset", "containerRadius", "pillPadding", "workspaceIconSize"],
            appearance: ["accent", "flavour", "barOpacity", "containerOpacity", "panelOpacity", "shadowEnabled", "shadowOpacity", "shadowBlur"],
            theming: ["themeGtk", "themeSwaylock", "themeTerminal", "terminalOpacity", "themeSpotify"],
            windows: ["themeWindows", "windowBorderWidth", "windowRadius", "windowGaps"],
            cursor: ["cursorTheme", "cursorSize"],
            clock: ["clockUse24h", "clockShowSeconds", "clockShowDate", "clockFormat"],
            media: ["mediaMaxWidth", "mediaScrollSpeed", "mediaShowArtist", "showVisualiser", "visualiserOpacity", "visualiserBarWidth"],
            battery: ["batteryLow", "batteryMid", "batteryHigh", "batteryFlash", "batteryShowPercent", "batteryAlerts"],
            workspaces: ["workspaceShowIcons", "workspaceShowEmpty", "workspaceMaxIcons"],
            notifications: ["toastPosition", "toastDuration", "toastMaxVisible", "dnd"],
            behaviour: ["animationsEnabled", "animSpeed"],
            clipboard: ["clipboardThumbnails", "clipboardMaxItems", "launcherRecentCount"],
            cava: ["cavaBands", "cavaFramerate", "cavaSmoothing"],
            night: ["nightTemp"],
            widgets: ["showSysMon", "showMedia", "showLauncher", "showOverview", "showScreenshot", "showRecorder", "showKeyboard", "showClipboard", "showBattery", "showNetwork"],
            popups: ["osdEnabled", "toastsEnabled"]
        })

    readonly property var keys: {
        const out = [];
        for (const g in root.keyGroups)
            for (const k of root.keyGroups[g])
                out.push(k);
        return out;
    }

    // Captured before the file is read, so "reset" does not need them spelled
    // out a second time.
    property var defaults: ({})

    function set(key, value) {
        if (root[key] === value)
            return;
        root[key] = value;
        saveDebounce.restart();
    }

    // Resets one group, so a bad colour experiment does not cost the layout.
    function resetGroup(group) {
        const list = root.keyGroups[group];
        if (!list)
            return;
        for (const k of list)
            root[k] = root.defaults[k];
        saveDebounce.restart();
    }

    function reset() {
        for (const k of root.keys)
            root[k] = root.defaults[k];
        saveDebounce.restart();
    }

    function _save() {
        const out = {};
        for (const k of root.keys)
            out[k] = root[k];
        file.setText(JSON.stringify(out, null, 2));
    }

    Component.onCompleted: {
        const d = {};
        for (const k of root.keys)
            d[k] = root[k];
        root.defaults = d;
    }

    // Dragging a slider fires continuously; only the settled value is written.
    Timer {
        id: saveDebounce
        interval: 400
        onTriggered: root._save()
    }

    FileView {
        id: file
        path: `${Quickshell.stateDir}/settings.json`
        preload: true
        atomicWrites: true
        printErrors: false

        onLoaded: {
            let data;
            try {
                data = JSON.parse(text());
            } catch (e) {
                return;
            }
            if (!data)
                return;

            for (const k of root.keys)
                if (data[k] !== undefined)
                    root[k] = data[k];
        }
    }
}
