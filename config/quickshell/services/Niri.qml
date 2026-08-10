pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// Live niri state, driven by `niri msg --json event-stream`.
Singleton {
    id: root

    // ── Exposed state ────────────────────────────────────────────────────
    property var workspaces: []          // sorted by output, then idx
    property int focusedWorkspaceId: -1
    property string focusedTitle: ""
    property string focusedAppId: ""
    property var layoutNames: []
    property int layoutIndex: 0
    property bool overviewOpen: false
    property int castCount: 0

    readonly property string layoutShort: {
        const n = layoutNames[layoutIndex];
        if (!n)
            return "??";
        // "English (US)" -> "US", "Estonian" -> "EST"
        const paren = n.match(/\(([^)]+)\)/);
        if (paren)
            return paren[1].toUpperCase().slice(0, 3);
        return n.slice(0, 3).toUpperCase();
    }

    // Internal: window id -> window object
    property var _windows: ({})

    // workspace id -> windows on it, in scrolling-layout order.
    readonly property var windowsByWorkspace: {
        const map = {};
        for (const id in root._windows) {
            const w = root._windows[id];
            if (w.workspace_id === null || w.workspace_id === undefined)
                continue;
            if (!map[w.workspace_id])
                map[w.workspace_id] = [];
            map[w.workspace_id].push(w);
        }
        for (const key in map)
            map[key].sort((a, b) => {
                const pa = a.layout && a.layout.pos_in_scrolling_layout;
                const pb = b.layout && b.layout.pos_in_scrolling_layout;
                if (pa && pb && pa[0] !== pb[0])
                    return pa[0] - pb[0];
                if (pa && pb && pa[1] !== pb[1])
                    return pa[1] - pb[1];
                return a.id - b.id;
            });
        return map;
    }

    // ── Actions ──────────────────────────────────────────────────────────
    function focusWorkspace(idx) {
        actionProc.exec(["niri", "msg", "action", "focus-workspace", String(idx)]);
    }

    function toggleOverview() {
        actionProc.exec(["niri", "msg", "action", "toggle-overview"]);
    }

    function nextLayout() {
        actionProc.exec(["niri", "msg", "action", "switch-layout", "next"]);
    }

    Process {
        id: actionProc
    }

    // ── Event stream ─────────────────────────────────────────────────────
    Process {
        id: stream
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => root._handle(line)
        }
        onRunningChanged: if (!running)
            respawn.start()
    }

    Timer {
        id: respawn
        interval: 1000
        onTriggered: stream.running = true
    }

    function _sortWorkspaces(list) {
        return list.slice().sort((a, b) => {
            if (a.output !== b.output)
                return a.output < b.output ? -1 : 1;
            return a.idx - b.idx;
        });
    }

    function _refreshFocusedWindow() {
        // The focused window is whichever one carries is_focused.
        for (const id in root._windows) {
            const w = root._windows[id];
            if (w.is_focused) {
                root.focusedTitle = w.title || "";
                root.focusedAppId = w.app_id || "";
                return;
            }
        }
        root.focusedTitle = "";
        root.focusedAppId = "";
    }

    function _handle(line) {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }

        if (ev.WorkspacesChanged) {
            const list = ev.WorkspacesChanged.workspaces;
            root.workspaces = root._sortWorkspaces(list);
            for (const ws of list)
                if (ws.is_focused)
                    root.focusedWorkspaceId = ws.id;
        } else if (ev.WorkspaceActivated) {
            const { id, focused } = ev.WorkspaceActivated;
            const target = root.workspaces.find(w => w.id === id);
            if (!target)
                return;
            const next = root.workspaces.map(w => {
                // Only one workspace per output is active at a time.
                if (w.output === target.output)
                    return Object.assign({}, w, {
                        is_active: w.id === id,
                        is_focused: focused ? w.id === id : w.is_focused
                    });
                if (focused)
                    return Object.assign({}, w, { is_focused: false });
                return w;
            });
            root.workspaces = next;
            if (focused)
                root.focusedWorkspaceId = id;
        } else if (ev.WorkspaceUrgencyChanged) {
            const { id, urgent } = ev.WorkspaceUrgencyChanged;
            root.workspaces = root.workspaces.map(w => w.id === id ? Object.assign({}, w, { is_urgent: urgent }) : w);
        } else if (ev.WindowsChanged) {
            const map = {};
            for (const w of ev.WindowsChanged.windows)
                map[w.id] = w;
            root._windows = map;
            root._refreshFocusedWindow();
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window;
            const map = Object.assign({}, root._windows);
            if (w.is_focused)
                for (const id in map)
                    if (Number(id) !== w.id)
                        map[id] = Object.assign({}, map[id], { is_focused: false });
            map[w.id] = w;
            root._windows = map;
            root._refreshFocusedWindow();
        } else if (ev.WindowClosed) {
            const map = Object.assign({}, root._windows);
            delete map[ev.WindowClosed.id];
            root._windows = map;
            root._refreshFocusedWindow();
        } else if (ev.WindowFocusChanged) {
            const id = ev.WindowFocusChanged.id;
            const map = {};
            for (const k in root._windows)
                map[k] = Object.assign({}, root._windows[k], { is_focused: Number(k) === id });
            root._windows = map;
            root._refreshFocusedWindow();
        } else if (ev.KeyboardLayoutsChanged) {
            const kl = ev.KeyboardLayoutsChanged.keyboard_layouts;
            root.layoutNames = kl.names;
            root.layoutIndex = kl.current_idx;
        } else if (ev.KeyboardLayoutSwitched) {
            root.layoutIndex = ev.KeyboardLayoutSwitched.idx;
        } else if (ev.OverviewOpenedOrClosed) {
            root.overviewOpen = ev.OverviewOpenedOrClosed.is_open;
        } else if (ev.CastsChanged) {
            root.castCount = (ev.CastsChanged.casts || []).length;
        }
    }
}
