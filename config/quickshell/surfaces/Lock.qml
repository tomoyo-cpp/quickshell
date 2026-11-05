import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.UPower
import "root:/"

// The lock screen: ext-session-lock, so the compositor itself guarantees
// nothing but this is drawn or receives input until PAM says yes. Nothing is
// paused: downloads, music, builds and every window carry on underneath,
// exactly as they were.
//
//   qs ipc call lock lock        lock now
//   qs ipc call lock isLocked    "true" once the compositor confirms it
//
// scripts/lock.sh wraps both, restarting this shell if it is not running;
// swayidle (idle, lid, suspend) and Mod+Alt+L go through it. If the shell
// dies while locked, the session stays locked — the protocol guarantees it —
// and a marker in $XDG_RUNTIME_DIR makes the restarted shell (systemd
// restarts it) put the lock screen straight back up.
//
// Authenticates against the `login` PAM service: the same password check as
// the console, and present on every NixOS system, so there is no separate
// PAM file to get out of step.
Scope {
    id: root

    property bool busy: false
    property string message: ""
    property bool messageIsError: false
    property bool capsLock: false
    property string _pending: ""

    signal clearFields

    // Survives a crash of this shell, not a reboot or logout.
    readonly property string _marker: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-locked`
    Process {
        id: marker
    }
    Process {
        running: true
        command: ["test", "-e", root._marker]
        onExited: code => {
            if (code === 0)
                root.lock();
        }
    }

    function lock() {
        if (sessionLock.locked)
            return;
        root.message = "";
        root.messageIsError = false;
        sessionLock.locked = true;
        marker.exec(["sh", "-c", `touch "${root._marker}"`]);
    }

    function tryUnlock(password) {
        if (pam.active || password === "")
            return;
        root._pending = password;
        root.busy = true;
        root.message = "authenticating...";
        root.messageIsError = false;
        if (!pam.start()) {
            root.busy = false;
            root._pending = "";
            root.message = "could not start PAM";
            root.messageIsError = true;
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }
        function isLocked(): bool {
            return sessionLock.secure;
        }
    }

    PamContext {
        id: pam
        config: "login"

        onPamMessage: {
            if (pam.responseRequired) {
                pam.respond(root._pending);
                root._pending = "";
            } else if (pam.message !== "") {
                root.message = pam.message;
                root.messageIsError = pam.messageIsError;
            }
        }

        onCompleted: result => {
            root.busy = false;
            root._pending = "";
            root.clearFields();
            if (result === PamResult.Success) {
                root.message = "";
                sessionLock.locked = false;
                marker.exec(["rm", "-f", root._marker]);
            } else {
                root.message = "authentication failed";
                root.messageIsError = true;
            }
        }

        onError: err => {
            root.busy = false;
            root._pending = "";
            root.clearFields();
            root.message = "pam: " + PamError.toString(err);
            root.messageIsError = true;
        }
    }

    // Caps lock has no Wayland-side query; the keyboard LEDs say. Only
    // polled while locked.
    Timer {
        interval: 500
        repeat: true
        running: sessionLock.locked
        triggeredOnStart: true
        onTriggered: if (!caps.running)
            caps.running = true
    }
    Process {
        id: caps
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLock = /[1-9]/.test(text)
        }
    }

    // F1 / F2 on the lock screen. logind lets the active local session do
    // this without a password, as it would from the power button.
    Process {
        id: power
    }

    FileView {
        id: hostname
        path: "/etc/hostname"
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            color: "#000000"

            LockView {
                id: view
                anchors.fill: parent

                font: Theme.font
                host: hostname.text().trim() || "localhost"
                user: Quickshell.env("USER") ?? ""
                session: "niri"
                use24h: Settings.clockUse24h
                capsLock: root.capsLock
                battery: UPower.displayDevice && UPower.displayDevice.isLaptopBattery ? Math.round(UPower.displayDevice.percentage * 100) : -1
                charging: UPower.displayDevice && UPower.displayDevice.state === UPowerDeviceState.Charging
                busy: root.busy
                message: root.message
                messageIsError: root.messageIsError

                onSubmitted: password => root.tryUnlock(password)
                onPower: action => power.exec(["systemctl", action])
                Component.onCompleted: view.focusField()

                Connections {
                    target: root
                    function onClearFields() {
                        view.clear();
                    }
                }
            }
        }
    }
}
