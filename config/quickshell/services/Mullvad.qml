pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// Mullvad, through its CLI: the tunnel state live, its settings on demand,
// and the actions the network panel's VPN tab and the bar need. Replaces the
// Electron app, which no longer starts with the session.
//
// The state comes from `mullvad status -j listen`, which prints one JSON line
// per change, so nothing polls. It also prints other daemon events on the
// same stream (version checks, the whole relay list), which carry no
// `state` and are skipped — reading them as an empty state made the VPN
// look gone. If the daemon restarts the listener exits,
// and is started again a few seconds later.
Singleton {
    id: root

    // ── Tunnel ───────────────────────────────────────────────────────────
    // "connected" | "connecting" | "disconnecting" | "disconnected" | "error"
    // | "" while the daemon has not answered.
    property string state: ""
    readonly property bool available: state !== ""
    readonly property bool connected: state === "connected"
    readonly property bool busy: state === "connecting" || state === "disconnecting"
    // Disconnected, but lockdown blocks every packet: offline, not exposed.
    property bool blocked: false
    property string country: ""
    property string city: ""
    property string ip: ""
    property string relay: ""

    // ── Settings ─────────────────────────────────────────────────────────
    // Without an account, connecting only makes the daemon block all traffic.
    property bool loggedIn: false
    property bool lockdown: false
    property bool autoConnect: false
    property string location: ""      // "se", "se got", "se-got-wg-001"
    // Mullvad's in-tunnel DNS blocklists.
    property var dnsBlock: ({
            ads: false,
            trackers: false,
            malware: false
        })

    // [{ code, name, cities: [{ code, name }] }], sorted by name.
    property var countries: []

    readonly property string glyph: !available ? "󰦞" : connected ? "󰦝" : busy ? "󱆢" : blocked ? "󰻌" : "󰦞"
    readonly property color color: !available ? Theme.overlay1 : connected ? Theme.icon : busy ? Theme.yellow : blocked ? Theme.peach : Theme.red
    readonly property string summary: {
        if (!available)
            return "Mullvad daemon not running";
        if (!loggedIn && !connected)
            return "Not logged in";
        if (connected)
            return `${root.city}, ${root.country}`;
        if (busy)
            return root.state === "connecting" ? "Connecting…" : "Disconnecting…";
        if (blocked)
            return "Disconnected — lockdown blocks all traffic";
        return "Not protected";
    }

    // ── Actions ──────────────────────────────────────────────────────────
    function connect() {
        if (root.loggedIn)
            root._run(["mullvad", "connect"]);
    }
    function disconnect() {
        root._run(["mullvad", "disconnect"]);
    }
    function toggle() {
        root.connected || root.busy ? root.disconnect() : root.connect();
    }
    function reconnect() {
        root._run(["mullvad", "reconnect"]);
    }
    function login(account) {
        const n = String(account).replace(/\s/g, "");
        if (/^\d{16}$/.test(n))
            root._run(["mullvad", "account", "login", n]);
    }
    function logout() {
        root._run(["mullvad", "account", "logout"]);
    }
    function setLocation(country, city) {
        root._run(city ? ["mullvad", "relay", "set", "location", country, city] : ["mullvad", "relay", "set", "location", country]);
    }
    function setLockdown(on) {
        root._run(["mullvad", "lockdown-mode", "set", on ? "on" : "off"]);
    }
    function setAutoConnect(on) {
        root._run(["mullvad", "auto-connect", "set", on ? "on" : "off"]);
    }
    function setDnsBlock(key, on) {
        const b = Object.assign({}, root.dnsBlock);
        b[key] = on;
        const args = ["mullvad", "dns", "set", "default"];
        for (const k of ["ads", "trackers", "malware"])
            if (b[k])
                args.push(`--block-${k}`);
        root._run(args);
    }

    function refresh() {
        if (!settingsProc.running)
            settingsProc.running = true;
    }
    function loadRelays() {
        if (!relayProc.running && root.countries.length === 0)
            relayProc.running = true;
    }

    // One action at a time, then re-read the settings it may have changed.
    property var _queue: []
    function _run(cmd) {
        root._queue = root._queue.concat([cmd]);
        if (!actionProc.running)
            root._next();
    }
    function _next() {
        if (root._queue.length === 0) {
            root.refresh();
            return;
        }
        actionProc.command = root._queue[0];
        root._queue = root._queue.slice(1);
        actionProc.running = true;
    }

    Process {
        id: actionProc
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "")
                console.warn("mullvad:", text.trim())
        }
        onExited: root._next()
    }

    // ── Live state ───────────────────────────────────────────────────────
    function _parseState(line) {
        let s;
        try {
            s = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (!s || typeof s.state !== "string")
            return;
        const loc = (s.details && s.details.location) || {};
        root.state = s.state || "";
        root.blocked = !!(s.details && s.details.locked_down);
        root.country = loc.country || "";
        root.city = loc.city || "";
        root.ip = loc.ipv4 || loc.ipv6 || "";
        root.relay = loc.hostname || "";
    }

    Process {
        id: listen
        running: true
        command: ["mullvad", "status", "-j", "listen"]
        stdout: SplitParser {
            onRead: line => root._parseState(line)
        }
        onExited: {
            root.state = "";
            relisten.restart();
        }
    }
    Timer {
        id: relisten
        interval: 5000
        onTriggered: listen.running = true
    }

    // ── Settings ─────────────────────────────────────────────────────────
    Process {
        id: settingsProc
        running: true
        command: ["sh", "-c", "mullvad account get; mullvad lockdown-mode get; mullvad auto-connect get; mullvad relay get; mullvad dns get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text;
                root.loggedIn = !/Not logged in/i.test(t);
                root.lockdown = /when the VPN is disconnected:\s*on/i.test(t);
                root.autoConnect = /Autoconnect:\s*on/i.test(t);
                // "country se", "city got, se", "hostname se-got-wg-001"
                // — kept as "se", "se got" or the hostname.
                const loc = t.match(/^\s*Location:\s*(.+)$/m);
                let l = loc ? loc[1].trim() : "";
                let m;
                if ((m = l.match(/^city\s+(\w+),\s*(\w+)$/)))
                    l = `${m[2]} ${m[1]}`;
                else
                    l = l.replace(/^(country|hostname)\s+/, "");
                root.location = l === "any" ? "" : l;
                root.dnsBlock = {
                    ads: /Block ads:\s*true/i.test(t),
                    trackers: /Block trackers:\s*true/i.test(t),
                    malware: /Block malware:\s*true/i.test(t)
                };
            }
        }
    }

    // `mullvad relay list` is human-readable: countries unindented, cities
    // one tab in, servers two. Only countries and cities are kept.
    Process {
        id: relayProc
        command: ["mullvad", "relay", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    let m;
                    if ((m = line.match(/^(\S.*) \(([a-z]{2})\)$/)))
                        out.push({
                            code: m[2],
                            name: m[1],
                            cities: []
                        });
                    else if ((m = line.match(/^\t([^\t].*) \(([a-z]{3})\) @/)) && out.length)
                        out[out.length - 1].cities.push({
                            code: m[2],
                            name: m[1]
                        });
                }
                out.sort((a, b) => a.name.localeCompare(b.name));
                root.countries = out;
            }
        }
    }
}
