import QtQuick
import "root:/"

// The lock screen, drawn as ly draws its login box at boot: white on black,
// a bordered box with the hostname, session, login and password, the key
// hints top left and the date and time top right. Nothing moves.
//
// Locking stops nothing — every program keeps running behind this, and
// unlocking returns to the session exactly as it was.
//
// F1 / F2 shut down / reboot, as on ly; each needs a second press within
// three seconds, so a stray key does not cost unsaved work.
//
// Pure QtQuick (the root import only registers names), so it can be
// rendered offscreen for a preview. Lock.qml does the PAM conversation.
Rectangle {
    id: root

    property string font: "JetBrainsMono Nerd Font"
    property string host: "nixos"
    property string user: "tomoyo"
    property string session: "niri"
    property bool use24h: false
    property bool capsLock: false
    property int battery: -1        // percent, -1 when there is none
    property bool charging: false

    // Set by the owner while PAM works, and after it answers.
    property bool busy: false
    property string message: ""
    property bool messageIsError: false

    signal submitted(string password)
    signal power(string action)     // "poweroff" | "reboot"

    function clear() {
        field.text = "";
    }
    function focusField() {
        field.forceActiveFocus();
    }

    readonly property color fg: "#ffffff"
    readonly property color err: "#ff5555"

    color: "#000000"

    // ── The terminal grid ────────────────────────────────────────────────
    TextMetrics {
        id: cell
        font.family: root.font
        font.pixelSize: 16
        text: "M"
    }
    readonly property real cw: Math.ceil(cell.advanceWidth)
    readonly property real ch: Math.ceil(cell.height * 1.15)
    readonly property int inputLen: 34
    readonly property int labelLen: 10
    readonly property int marginH: 2
    readonly property int boxCols: marginH * 2 + labelLen + inputLen

    component Cell: Text {
        font.family: root.font
        font.pixelSize: 16
        color: root.fg
        height: root.ch
        verticalAlignment: Text.AlignVCenter
    }

    // ── Power keys, armed by the first press ─────────────────────────────
    property string _armed: ""
    Timer {
        id: disarm
        interval: 3000
        onTriggered: root._armed = ""
    }
    function _powerKey(action) {
        if (root._armed === action) {
            root._armed = "";
            root.power(action);
            return;
        }
        root._armed = action;
        disarm.restart();
    }
    readonly property string _info: _armed === "poweroff" ? "press F1 again to shut down" : _armed === "reboot" ? "press F2 again to reboot" : message !== "" ? message : host

    // ── Top corners ──────────────────────────────────────────────────────
    Row {
        x: root.cw
        y: root.ch * 0.5
        spacing: root.cw * 2
        Cell {
            text: "F1 shutdown"
        }
        Cell {
            text: "F2 reboot"
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: root.cw
        y: root.ch * 0.5
        spacing: root.cw * 2
        Cell {
            visible: root.capsLock
            text: "capslock"
        }
        Cell {
            visible: root.battery >= 0
            text: `bat ${root.battery}%${root.charging ? "+" : ""}`
            color: root.battery >= 0 && root.battery <= 15 && !root.charging ? root.err : root.fg
        }
        Cell {
            id: date
        }
    }

    function _tick() {
        const now = new Date();
        date.text = Qt.formatDate(now, "ddd d MMM") + "  " + Qt.formatTime(now, root.use24h ? "HH:mm" : "h:mm AP");
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._tick()
    }

    // ── The box ──────────────────────────────────────────────────────────
    Rectangle {
        id: box
        anchors.centerIn: parent
        width: root.boxCols * root.cw
        height: rowsCol.height + root.ch * 2
        color: root.color
        border.color: root.fg
        border.width: 1

        // ly's box_title, sitting in the top border.
        Cell {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.top
            leftPadding: root.cw
            rightPadding: root.cw
            text: "locked"
            Rectangle {
                anchors.fill: parent
                z: -1
                color: root.color
            }
        }

        Column {
            id: rowsCol
            x: root.marginH * root.cw
            y: root.ch
            width: (root.boxCols - root.marginH * 2) * root.cw

            // Info line: the hostname until there is something to say.
            Cell {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root._info
                color: root.messageIsError && root._armed === "" ? root.err : root.fg
                font.bold: root.messageIsError && root._armed === ""
            }
            Item {
                width: 1
                height: root.ch
            }

            // Session — fixed while locked, shown as ly's selector would.
            Row {
                Cell {
                    width: root.labelLen * root.cw
                    text: ""
                }
                Cell {
                    width: root.inputLen * root.cw
                    horizontalAlignment: Text.AlignHCenter
                    text: root.session
                    Cell {
                        text: "<"
                    }
                    Cell {
                        anchors.right: parent.right
                        text: ">"
                    }
                }
            }
            Row {
                Cell {
                    width: root.labelLen * root.cw
                    text: "login"
                }
                Cell {
                    text: root.user
                }
            }
            Row {
                Cell {
                    width: root.labelLen * root.cw
                    text: "password"
                }
                Item {
                    width: root.inputLen * root.cw
                    height: root.ch

                    TextInput {
                        id: field
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: root.font
                        font.pixelSize: 16
                        color: root.fg
                        echoMode: TextInput.Password
                        passwordCharacter: "*"
                        passwordMaskDelay: 0
                        readOnly: root.busy
                        focus: true
                        clip: true
                        selectByMouse: false
                        // A terminal block cursor, not a caret. Steady, like
                        // ly on the console.
                        cursorDelegate: Rectangle {
                            width: root.cw
                            height: root.ch * 0.9
                            color: root.fg
                            visible: field.activeFocus && !root.busy
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_F1) {
                                root._powerKey("poweroff");
                                event.accepted = true;
                            } else if (event.key === Qt.Key_F2) {
                                root._powerKey("reboot");
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                field.text = "";
                                root._armed = "";
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (!root.busy && field.text !== "")
                                    root.submitted(field.text);
                                event.accepted = true;
                            }
                        }
                    }
                }
            }
        }
    }

    // A click anywhere puts the keyboard back in the field.
    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: field.forceActiveFocus()
    }
}
