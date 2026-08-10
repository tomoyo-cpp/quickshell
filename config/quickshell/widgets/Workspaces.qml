import QtQuick
import Quickshell
import "root:/"

// Each workspace is a capsule showing the icons of the windows on it, so the
// capsule grows and shrinks with its contents. Empty workspaces collapse to a
// dot. The focused workspace gets a lighter surface.
//
// Widths are deliberately not eased. The Repeater is keyed on the workspace
// count, so creating or destroying one re-maps every capsule onto a different
// workspace at once — an eased width would animate each of them towards a
// value that has nothing to do with what it was showing a moment earlier. On
// top of that a destroyed capsule cannot be animated out at all, since the
// Repeater has already discarded it, so easing the appearing case alone leaves
// the two directions mismatched. Snapping is the consistent choice here.
// Colour and icon opacity still animate; those belong to a capsule that stays
// put.
Pill {
    id: root

    required property var bar

    // How many icons to show before collapsing into a "+N" counter.
    readonly property int maxIcons: Settings.workspaceMaxIcons

    readonly property var mine: {
        const all = Niri.workspaces.filter(w => w.output === root.bar.screen.name);
        if (Settings.workspaceShowEmpty)
            return all;
        // The focused workspace stays even when empty, otherwise the bar
        // shows nothing at all on a fresh session.
        return all.filter(w => w.is_active || (Niri.windowsByWorkspace[w.id] ?? []).length > 0);
    }

    interactive: false
    innerSpacing: 5
    padding: 6

    Repeater {
        model: root.mine.length

        Rectangle {
            id: ws
            required property int index

            readonly property var modelData: root.mine[ws.index] ?? ({})

            readonly property var windows: Niri.windowsByWorkspace[modelData.id] ?? []
            readonly property var shown: windows.slice(0, root.maxIcons)
            readonly property int overflow: windows.length - shown.length
            // Icons off collapses every workspace to the dot treatment.
            readonly property bool empty: windows.length === 0 || !Settings.workspaceShowIcons

            anchors.verticalCenter: parent.verticalCenter
            // A single-app workspace is pinned to width == height so it is a
            // true circle. Decoupling it from the icon padding means that
            // holds at any bar height.
            implicitWidth: ws.empty ? 20 : ws.shown.length === 1 && ws.overflow === 0 ? Theme.workspaceHeight : icons.implicitWidth + 16
            implicitHeight: Theme.workspaceHeight
            radius: Theme.workspaceRadius

            // Three levels, lightest wins: empty workspaces have no surface at
            // all, occupied ones sit above the container, the focused one sits
            // above those.
            color: ws.empty ? (wsMouse.containsMouse ? Theme.alpha(Theme.surface0, 0.5) : "transparent") : modelData.is_urgent ? Theme.alpha(Theme.red, 0.3) : modelData.is_active ? Theme.alpha(Theme.surface2, 0.9) : Theme.alpha(Theme.surface0, 0.75)

            border.width: modelData.is_urgent && !ws.empty ? 1 : 0
            border.color: Theme.alpha(Theme.red, 0.6)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.anim
                }
            }

            // Empty workspace — just a dot, no surface behind it.
            Rectangle {
                anchors.centerIn: parent
                visible: ws.empty
                width: 5
                height: 5
                radius: 2.5
                color: ws.modelData.is_active ? Theme.text : Theme.overlay0
            }

            Row {
                id: icons
                anchors.centerIn: parent
                spacing: 5
                visible: !ws.empty

                Repeater {
                    model: ws.shown.length

                    Item {
                        id: appIcon
                        required property int index

                        readonly property var modelData: ws.shown[appIcon.index] ?? ({})

                        // DesktopEntries reports zero applications in this
                        // quickshell build, so the icon is resolved straight
                        // from the app id. A couple of ids do not match their
                        // icon name and need an alias.
                        readonly property string iconSource: {
                            const id = appIcon.modelData.app_id || "";
                            if (id === "")
                                return "";

                            const aliases = {
                                "code": "vscode",
                                "spotify": "spotify-client",
                                "org.gnome.Nautilus": "nautilus"
                            };

                            let path = Quickshell.iconPath(aliases[id] ?? id, true);
                            if (path === "")
                                path = Quickshell.iconPath(id.toLowerCase(), true);
                            return path;
                        }

                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.workspaceIconSize
                        height: Theme.workspaceIconSize
                        opacity: ws.modelData.is_active ? 1 : 0.75

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.anim
                            }
                        }

                        Image {
                            anchors.fill: parent
                            visible: appIcon.iconSource !== ""
                            source: appIcon.iconSource
                            sourceSize.width: Theme.workspaceIconSize * 2
                            sourceSize.height: Theme.workspaceIconSize * 2
                            fillMode: Image.PreserveAspectFit
                        }

                        // Themeless apps get a lettered chip instead.
                        Rectangle {
                            anchors.fill: parent
                            visible: appIcon.iconSource === ""
                            radius: 5
                            color: Theme.alpha(Theme.overlay0, 0.55)

                            Text {
                                anchors.centerIn: parent
                                text: (appIcon.modelData.app_id || "?").charAt(0).toUpperCase()
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.bold: true
                                color: Theme.text
                            }
                        }
                    }
                }

                Caption {
                    visible: ws.overflow > 0
                    text: `+${ws.overflow}`
                    color: Theme.subtext0
                    size: 10
                }
            }

            MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Niri.focusWorkspace(ws.modelData.idx)
            }
        }
    }
}
