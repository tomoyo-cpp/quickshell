import QtQuick
import "root:/"

// Mullvad, without its app: the tunnel's state, the settings that decide
// whether anything can leak (lockdown, auto-connect, DNS blocklists) and
// where to exit. Lives in the network panel's VPN tab; the tab's own switch
// connects and disconnects. Everything goes through services/Mullvad.qml.
Item {
    id: root

    // The country the relay constraint names, if it names one.
    readonly property string pickedCountry: Mullvad.location.split(/[\s-]/)[0] || ""
    readonly property string pickedCity: Mullvad.location.split(/[\s-]/)[1] || ""
    property string filter: ""

    Column {
        anchors.fill: parent
        spacing: 0

        // ── Status ───────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 42

            Glyph {
                id: bigGlyph
                anchors.left: parent.left
                anchors.leftMargin: 6
                text: Mullvad.glyph
                color: Mullvad.color
                size: 24
            }

            Column {
                anchors.left: bigGlyph.right
                anchors.leftMargin: 12
                anchors.right: Mullvad.connected ? newServer.left : parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Caption {
                    vcenter: false
                    width: parent.width
                    elide: Text.ElideRight
                    text: (!Mullvad.available ? "Unavailable" : Mullvad.connected ? "Protected" : Mullvad.busy ? "Working…" : Mullvad.blocked ? "Blocked" : "Exposed") + (Mullvad.available ? ` · ${Mullvad.summary}` : "")
                    color: Mullvad.color
                    size: 12
                    font.bold: true
                }
                Caption {
                    vcenter: false
                    width: parent.width
                    elide: Text.ElideRight
                    visible: text !== ""
                    text: [Mullvad.ip, Mullvad.relay].filter(s => s !== "").join("  ·  ")
                    color: Theme.overlay1
                    size: 10
                }
            }

            ChipButton {
                id: newServer
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: Mullvad.connected
                label: "New server"
                onTriggered: Mullvad.reconnect()
            }
        }

        // ── Account, until there is one ──────────────────────────────────
        Rectangle {
            visible: Mullvad.available && !Mullvad.loggedIn
            width: parent.width
            height: visible ? 28 : 0
            radius: 11
            color: Theme.surface0

            Glyph {
                id: keyIcon
                anchors.left: parent.left
                anchors.leftMargin: 11
                text: "󰌆"
                color: Theme.overlay1
                size: 11
            }
            TextInput {
                id: account
                anchors.left: keyIcon.right
                anchors.leftMargin: 9
                anchors.right: parent.right
                anchors.rightMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.icon
                echoMode: TextInput.Password
                clip: true
                onAccepted: {
                    Mullvad.login(text);
                    text = "";
                }

                Caption {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: account.text === ""
                    text: "Account number, then Enter"
                    color: Theme.overlay0
                    size: 12
                }
            }
        }
        Item {
            visible: Mullvad.available && !Mullvad.loggedIn
            width: 1
            height: visible ? 10 : 0
        }

        // ── Leak protection ──────────────────────────────────────────────
        Row {
            width: parent.width
            spacing: 16

            ToggleSwitch {
                width: (parent.width - 16) / 2
                label: "Lockdown mode"
                checked: Mullvad.lockdown
                onToggled: Mullvad.setLockdown(!Mullvad.lockdown)
            }
            ToggleSwitch {
                width: (parent.width - 16) / 2
                label: "Connect at startup"
                checked: Mullvad.autoConnect
                onToggled: Mullvad.setAutoConnect(!Mullvad.autoConnect)
            }
        }

        Item {
            width: 1
            height: 6
        }

        Row {
            width: parent.width
            height: 24
            spacing: 6

            Caption {
                width: 92
                text: "Block (DNS)"
                color: Theme.overlay0
                size: 11
            }
            Repeater {
                model: [
                    {
                        key: "ads",
                        label: "Ads"
                    },
                    {
                        key: "trackers",
                        label: "Trackers"
                    },
                    {
                        key: "malware",
                        label: "Malware"
                    }
                ]
                delegate: ChipButton {
                    required property var modelData
                    readonly property bool on: Mullvad.dnsBlock[modelData.key]
                    label: (on ? "󰄬 " : "") + modelData.label
                    highlighted: on
                    accent: on ? Theme.icon : Theme.subtext0
                    onTriggered: Mullvad.setDnsBlock(modelData.key, !on)
                }
            }
        }

        Item {
            width: 1
            height: 12
        }

        // ── Exit location ────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 28
            radius: 11
            color: Theme.surface0

            Glyph {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: 11
                text: "󰍉"
                color: Theme.overlay1
                size: 11
            }

            TextInput {
                id: search
                anchors.left: searchIcon.right
                anchors.leftMargin: 9
                anchors.right: current.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.icon
                clip: true
                onTextChanged: root.filter = text.toLowerCase()

                Caption {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: "Exit location"
                    color: Theme.overlay0
                    size: 12
                }
            }

            Caption {
                id: current
                anchors.right: parent.right
                anchors.rightMargin: 11
                text: Mullvad.location !== "" ? Mullvad.location : "any"
                color: Theme.overlay1
                size: 10
            }
        }

        Item {
            width: 1
            height: 6
        }

        ListView {
            id: list
            width: parent.width
            height: root.height - y
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: Mullvad.countries.filter(c => root.filter === "" || c.name.toLowerCase().includes(root.filter) || c.code === root.filter)

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 1
                width: 3
                radius: 1.5
                color: Theme.alpha(Theme.icon, 0.4)
                visible: list.contentHeight > list.height
                height: Math.max(24, list.height * (list.height / Math.max(1, list.contentHeight)))
                y: list.contentHeight > list.height ? Math.max(0, Math.min(list.height - height, (list.contentY / (list.contentHeight - list.height)) * (list.height - height))) : 0
            }

            Caption {
                anchors.centerIn: parent
                vcenter: false
                visible: list.count === 0
                text: !Mullvad.available ? "Mullvad daemon not running" : Mullvad.countries.length === 0 ? "Loading servers…" : "No match"
                color: Theme.overlay0
                size: 11
            }

            delegate: Column {
                id: row
                required property var modelData
                readonly property bool picked: root.pickedCountry === modelData.code
                width: ListView.view.width - 8
                spacing: 4

                Rectangle {
                    width: parent.width
                    height: 30
                    radius: 11
                    color: row.picked ? Theme.alpha(Theme.blue, 0.16) : countryMouse.containsMouse ? Theme.surface0 : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.anim
                        }
                    }

                    Caption {
                        anchors.left: parent.left
                        anchors.leftMargin: 11
                        text: row.modelData.name
                        color: row.picked ? Theme.icon : Theme.subtext0
                        font.bold: row.picked
                        size: 12
                    }
                    Caption {
                        anchors.right: parent.right
                        anchors.rightMargin: 11
                        text: row.picked ? "󰄬" : `${row.modelData.cities.length} ${row.modelData.cities.length === 1 ? "city" : "cities"}`
                        color: row.picked ? Theme.blue : Theme.overlay0
                        size: 10
                    }
                    MouseArea {
                        id: countryMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Mullvad.setLocation(row.modelData.code, "")
                    }
                }

                // Cities, once the country is the one picked.
                Flow {
                    visible: row.picked && row.modelData.cities.length > 1
                    width: parent.width - 22
                    x: 11
                    spacing: 4
                    bottomPadding: 4

                    Repeater {
                        model: row.picked ? row.modelData.cities : []
                        delegate: ChipButton {
                            required property var modelData
                            label: modelData.name
                            highlighted: root.pickedCity === modelData.code
                            onTriggered: Mullvad.setLocation(row.modelData.code, modelData.code)
                        }
                    }
                }
            }
        }
    }
}
