pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// Installed applications, scanned by scripts/list-apps.sh.
//
// Quickshell's own DesktopEntries service reports zero applications in this
// build, so the .desktop files are parsed by that script instead.
Singleton {
    id: root

    // [{ id, name, icon, exec }, ...] sorted by name.
    property var all: []

    property string query: ""

    // Ids of recently launched apps, most recent first, persisted so the list
    // is useful straight after a restart.
    property var recentIds: []
    readonly property int recentLimit: Settings.launcherRecentCount

    // Resolved against the current app list, so an uninstalled app simply
    // drops out rather than showing a dead row.
    readonly property var recent: {
        const out = [];
        for (const id of root.recentIds) {
            const app = root.all.find(a => a.id === id);
            if (app)
                out.push(app);
        }
        return out;
    }

    // Ranked matches. Prefix hits sort above substring hits so typing "fi"
    // puts Firefox before Nautilus (which merely contains "fi" in a keyword).
    readonly property var results: {
        const q = root.query.trim().toLowerCase();
        if (q === "")
            return root.all;

        const scored = [];
        for (const app of root.all) {
            const name = app.name.toLowerCase();
            const id = app.id.toLowerCase();

            let score = -1;
            if (name.startsWith(q))
                score = 0;
            else if (name.includes(q))
                score = 1;
            else if (id.startsWith(q))
                score = 2;
            else if (id.includes(q))
                score = 3;

            if (score >= 0)
                scored.push({ app: app, score: score });
        }

        scored.sort((a, b) => a.score !== b.score ? a.score - b.score : a.app.name.localeCompare(b.app.name));
        return scored.map(s => s.app);
    }

    function refresh() {
        if (!scan.running)
            scan.running = true;
    }

    function launch(app) {
        if (!app)
            return;

        root.recentIds = [app.id].concat(root.recentIds.filter(id => id !== app.id)).slice(0, root.recentLimit);
        recentFile.setText(JSON.stringify(root.recentIds, null, 2));

        // Exec is already stripped of field codes by the script.
        //
        // Launched into its own transient scope rather than with a bare
        // execDetached. execDetached detaches the process but leaves it in
        // quickshell.service's cgroup, and systemd's default KillMode is
        // control-group — so restarting or reloading the shell SIGTERMs every
        // app ever started from the launcher. That was killing VS Code.
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--quiet",
            "--collect", "--unit", `app-${app.id.replace(/[^a-zA-Z0-9_.\\-]/g, "_")}-${Date.now()}`,
            "sh", "-c", app.exec]);
    }

    function iconFor(app) {
        if (!app || !app.icon)
            return "";
        return Quickshell.iconPath(app.icon, true);
    }

    FileView {
        id: recentFile
        path: `${Quickshell.stateDir}/recent-apps.json`
        preload: true
        atomicWrites: true
        printErrors: false

        onLoaded: {
            try {
                root.recentIds = JSON.parse(text()) ?? [];
            } catch (e) {
                root.recentIds = [];
            }
        }

        onLoadFailed: root.recentIds = []
    }

    Process {
        id: scan
        running: true
        command: [`${Quickshell.shellDir}/scripts/list-apps.sh`]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.all = JSON.parse(text) ?? [];
                } catch (e) {
                    root.all = [];
                }
            }
        }
    }
}
