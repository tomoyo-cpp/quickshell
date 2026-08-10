pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// Clipboard history backed by cliphist. The store is filled by the
// `wl-paste --watch cliphist store` process niri spawns at startup.
Singleton {
    id: root

    // [{ id: "42", preview: "some text", line: "42\tsome text" }, ...]
    property var entries: []
    property bool loading: false

    // Set by whatever is displaying the list, so polling only runs when the
    // list is actually on screen.
    property bool watching: false

    // Pinned clips keep their own copy of the text. cliphist evicts past the
    // 15-item cap, so referencing its ids alone would lose them.
    property var pinned: []

    // Stashed before decoding, since the collector only sees the raw bytes.
    property string _pendingPreview: ""

    // Thumbnails for image entries, named <id>.png. Content is immutable per
    // id, so the filename needs no cache-busting.
    readonly property string thumbDir: `${Quickshell.cacheDir}/clipthumbs`

    function thumbFor(id) {
        return `${root.thumbDir}/${id}.png`;
    }

    Process {
        id: thumbProc
        command: [`${Quickshell.shellDir}/scripts/clip-thumbs.sh`, root.thumbDir]

        // Bumped when a pass finishes so entries re-evaluate their source:
        // a thumbnail that did not exist when the row was built now does.
        onExited: root.thumbRev += 1
    }

    property int thumbRev: 0

    function refresh() {
        if (listProc.running)
            return;
        root.loading = true;
        listProc.running = true;
    }

    function copy(id) {
        pipeProc.exec(["sh", "-c", `cliphist decode ${id} | wl-copy`]);
    }

    function copyText(text) {
        // stdinEnabled has to be set on the Process, not handed to exec():
        // exec()'s context only carries command/environment/workingDirectory,
        // so anything else in it is silently dropped and the write is lost.
        pipeProc.stdinEnabled = true;
        pipeProc.exec(["wl-copy"]);
        pipeProc.write(text);
        pipeProc.stdinEnabled = false;
    }

    // `cliphist delete` expects the raw *list* line on stdin (id, tab,
    // preview) — not the decoded clip. Piping the decoded content silently did
    // nothing, which is why single entries could not be removed.
    function remove(line) {
        deleteProc.stdinEnabled = true;
        deleteProc.exec(["cliphist", "delete"]);
        deleteProc.write(line + "\n");
        // Closing stdin is what signals EOF, so cliphist acts on the line.
        deleteProc.stdinEnabled = false;
        refreshDelay.restart();
    }

    function wipe() {
        pipeProc.exec(["cliphist", "wipe"]);
        refreshDelay.restart();
    }

    function isPinned(text) {
        return root.pinned.some(p => p.text === text);
    }

    function pin(entry) {
        root._pendingPreview = entry.preview;
        pinProc.exec(["cliphist", "decode", entry.id]);
    }

    function unpin(text) {
        root.pinned = root.pinned.filter(p => p.text !== text);
        root._savePins();
    }

    function _savePins() {
        pinFile.setText(JSON.stringify(root.pinned, null, 2));
    }

    Process {
        id: pipeProc
    }

    Process {
        id: deleteProc
    }

    Process {
        id: pinProc

        // Declared here, not passed to exec(): the context object only carries
        // command/environment/workingDirectory, so a stdout given to exec() is
        // silently dropped and the collector never fires.
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === "" || root.isPinned(text))
                    return;

                root.pinned = root.pinned.concat([
                    {
                        text: text,
                        preview: root._pendingPreview
                    }
                ]);
                root._savePins();
            }
        }
    }

    // Cheap poll so newly copied text appears without reopening the page.
    Timer {
        running: root.watching
        interval: 1500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshDelay
        interval: 120
        onTriggered: root.refresh()
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    out.push({
                        id: line.slice(0, tab),
                        preview: line.slice(tab + 1),
                        line: line
                    });
                }
                root.entries = out;
                root.loading = false;

                // Only worth a pass when there is an image in the list; the
                // script skips thumbnails it has already made, so a refresh
                // where nothing changed costs almost nothing.
                if (Settings.clipboardThumbnails && !thumbProc.running && out.some(e => e.preview.startsWith("[[ binary data")))
                    thumbProc.running = true;
            }
        }
    }

    FileView {
        id: pinFile
        path: `${Quickshell.stateDir}/clipboard-pins.json`
        preload: true
        atomicWrites: true
        printErrors: false

        onLoaded: {
            try {
                root.pinned = JSON.parse(text()) ?? [];
            } catch (e) {
                root.pinned = [];
            }
        }

        onLoadFailed: root.pinned = []
    }
}
