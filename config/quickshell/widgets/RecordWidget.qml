import QtQuick
import "root:/"

// Start and stop a screen recording.
//
// Click to toggle. While recording the glyph turns red and pulses, and the
// elapsed time appears beside it — a recording you have forgotten about is
// worse than one that is hard to start.
Pill {
    id: root

    readonly property bool recording: Recorder.running

    padding: 9

    onClicked: Recorder.toggle()

    // Right-click stops without the risk of a mis-click starting a new one.
    onRightClicked: Recorder.stop()

    Row {
        spacing: 6

        Glyph {
            id: dot

            // Stop while recording, record while idle: the icon states what
            // the click will do, not what is happening.

            text: root.recording ? "\udb81\ude66" : "\udb81\udc4a"
            color: root.recording ? Theme.red : Theme.icon

            Behavior on color {
                ColorAnimation {
                    duration: Theme.anim
                }
            }

            SequentialAnimation on opacity {
                running: root.recording && Settings.animationsEnabled
                loops: Animation.Infinite
                alwaysRunToEnd: true

                NumberAnimation {
                    to: 0.35
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

        Caption {
            visible: root.recording
            text: Recorder.elapsedText
            color: Theme.red
            size: 11
        }
    }
}
