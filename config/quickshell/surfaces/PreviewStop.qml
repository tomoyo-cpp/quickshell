import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "root:/"

// A stop button, bottom-left, for the duration of the guided tour.
//
// The tour moves focus, switches workspaces and opens the overview, so a
// control inside the bar's panels would be unreachable while it ran. This is
// its own overlay-layer surface: it stays put and stays clickable throughout,
// including over the overview.
PanelWindow {
    id: root

    readonly property bool showing: Preview.running

    // Stays mapped until the slide-out finishes. `reveal` rather than the
    // Behavior's state: a Behavior has no `running` property, and reading one
    // assigned undefined here.
    visible: root.showing || root.reveal > 0.001

    WlrLayershell.layer: WlrLayer.Overlay
    // Follows the tour across workspaces rather than belonging to one.
    WlrLayershell.namespace: "quickshell-preview-stop"

    color: "transparent"
    implicitWidth: 250
    implicitHeight: 54 + Theme.shadowPad * 2

    anchors {
        bottom: true
        left: true
    }

    margins {
        bottom: 18 - Theme.shadowPad
        left: 18 - Theme.shadowPad
    }

    // Nothing but the card itself should swallow clicks; the tour needs the
    // rest of the screen.
    exclusionMode: ExclusionMode.Ignore
    mask: Region {
        item: card
    }

    // Slides in from the left as it appears.
    property real reveal: root.showing ? 1 : 0

    Behavior on reveal {
        NumberAnimation {
            duration: Theme.dur(200)
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: card

        x: Theme.shadowPad + (1 - root.reveal) * -30
        y: Theme.shadowPad
        width: parent.width - Theme.shadowPad * 2
        height: parent.height - Theme.shadowPad * 2
        opacity: root.reveal

        Rectangle {
            id: cardBg
            anchors.fill: parent
            radius: Theme.popupRadius
            color: Theme.panelBg
            border.width: 1
            border.color: Theme.alpha(Theme.red, 0.45)
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: cardBg
            source: cardBg
            shadowEnabled: Settings.shadowEnabled
            shadowColor: "#000000"
            shadowOpacity: Settings.shadowOpacity
            shadowBlur: Settings.shadowBlur
            shadowVerticalOffset: 2
        }

        // Pulsing dot, so it reads as "something is running".
        Rectangle {
            id: dot
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: Theme.red

            SequentialAnimation on opacity {
                running: root.showing && Settings.animationsEnabled
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.25
                    duration: 700
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    to: 1
                    duration: 700
                    easing.type: Easing.InOutQuad
                }
            }
        }

        // Bounded on the right by the button, or a long label runs underneath
        // it. Caption already elides, so it shortens rather than overlapping.
        // Two lines: what is happening, and that it is being captured. The
        // recording is the part worth being unambiguous about.
        Column {
            id: label
            anchors.left: dot.right
            anchors.leftMargin: 10
            anchors.right: stopBtn.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Caption {
                vcenter: false
                width: parent.width
                text: "Preview running"
                color: Theme.subtext0
                size: 11
            }

            Caption {
                vcenter: false
                width: parent.width
                text: "Recording to ScreenRecordings"
                color: Theme.red
                size: 9
            }
        }

        Rectangle {
            id: stopBtn
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: stopLabel.implicitWidth + 22
            height: 26
            radius: 13
            color: stopMouse.containsMouse ? Theme.alpha(Theme.red, 0.35) : Theme.alpha(Theme.red, 0.18)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.anim
                }
            }

            Caption {
                id: stopLabel
                anchors.centerIn: parent
                text: "Stop"
                color: Theme.red
                size: 11
                font.bold: true
            }

            MouseArea {
                id: stopMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Preview.stop()
            }
        }
    }
}
