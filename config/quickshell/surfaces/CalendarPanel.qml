import QtQuick
import Quickshell
import "root:/"

// Month view and the day's tasks, hanging off the clock in the bar.
PanelShell {
    id: root

    popupName: "calendar"
    bodyWidth: 300

    // Clock, rule, header, weekday row, day grid, rule, task header, entry,
    // task list. The two leading terms are the clock block and its rule,
    // plus the Column spacing each one adds.
    bodyHeight: 58 + 1 + 12 + 28 + 18 + weekRows * 27 + 1 + 22 + 26 + Math.min(84, taskList.contentHeight) + 46

    property int monthOffset: 0
    property date selectedDay: new Date()

    readonly property date now: clock.date

    readonly property date shownMonth: {
        const d = new Date(root.now);
        d.setDate(1);
        d.setMonth(d.getMonth() + root.monthOffset);
        return d;
    }
    // Monday-first offset of the 1st.
    readonly property int lead: (root.shownMonth.getDay() + 6) % 7
    readonly property int daysInMonth: {
        const d = new Date(root.shownMonth);
        d.setMonth(d.getMonth() + 1);
        d.setDate(0);
        return d.getDate();
    }
    readonly property int weekRows: Math.ceil((root.lead + root.daysInMonth) / 7)

    onOpenChanged: if (open) {
        root.monthOffset = 0;
        root.selectedDay = new Date();
    }

    SystemClock {
        id: clock
        // Seconds only while the panel is on screen — otherwise this wakes the
        // shell once a second to drive a clock nobody is looking at.
        //
        // Keyed to `visible` rather than `open`: the panel stays on screen for
        // the length of its close animation, and dropping to Minutes the
        // instant `open` went false truncated the clock to :00 in full view of
        // the user, so the seconds appeared to snap to zero on the way out.
        // PanelShell holds `visible` true until the animation finishes.
        precision: root.visible ? SystemClock.Seconds : SystemClock.Minutes
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        // ── Clock ────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 58

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                spacing: 3

                Caption {
                    vcenter: false
                    text: Qt.formatTime(root.now, "HH:mm")
                    color: Theme.icon
                    size: 34
                    font.bold: true
                }

                // Seconds ride along the baseline at a smaller size, so the
                // hours and minutes stay the thing you read.
                Caption {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    vcenter: false
                    text: Qt.formatTime(root.now, "ss")
                    color: Theme.overlay1
                    size: 14
                    font.bold: true
                }
            }

            Caption {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                vcenter: false
                text: Qt.formatDate(root.now, "dddd, d MMMM yyyy")
                color: Theme.subtext0
                size: 12
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.alpha(Theme.surface1, 0.7)
        }

        // ── Month header ─────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 24

            Caption {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(root.shownMonth, "MMMM yyyy")
                color: Theme.icon
                size: 13
                font.bold: true
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                NavButton {
                    glyph: "󰅁"
                    onTriggered: root.monthOffset -= 1
                }
                NavButton {
                    glyph: "󰇙"
                    onTriggered: root.monthOffset = 0
                }
                NavButton {
                    glyph: "󰅂"
                    onTriggered: root.monthOffset += 1
                }
            }
        }

        Row {
            width: parent.width

            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                Item {
                    required property string modelData
                    width: parent.width / 7
                    height: 18

                    Caption {
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: Theme.overlay1
                        size: 10
                        font.bold: true
                    }
                }
            }
        }

        Grid {
            id: grid
            width: parent.width
            columns: 7

            Repeater {
                model: root.weekRows * 7

                Item {
                    id: cell
                    required property int index

                    readonly property int dayNumber: cell.index - root.lead + 1
                    readonly property bool inMonth: dayNumber >= 1 && dayNumber <= root.daysInMonth
                    readonly property bool isToday: inMonth && root.monthOffset === 0 && dayNumber === root.now.getDate()

                    readonly property date cellDate: {
                        const d = new Date(root.shownMonth);
                        d.setDate(cell.dayNumber);
                        return d;
                    }
                    readonly property bool isSelected: inMonth && Todos.key(cell.cellDate) === Todos.key(root.selectedDay)
                    readonly property int taskCount: inMonth ? Todos.countFor(cell.cellDate) : 0

                    width: grid.width / 7
                    height: 27

                    Rectangle {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        radius: 12
                        color: cell.isToday ? Theme.icon : cell.isSelected ? Theme.alpha(Theme.icon, 0.25) : dayMouse.containsMouse ? Theme.surface0 : "transparent"
                    }

                    Caption {
                        anchors.centerIn: parent
                        text: cell.inMonth ? cell.dayNumber : ""
                        color: cell.isToday ? Theme.crust : Theme.subtext0
                        font.bold: cell.isToday
                        size: 11
                    }

                    // Marks days that carry tasks.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        visible: cell.taskCount > 0
                        width: 4
                        height: 4
                        radius: 2
                        color: cell.isToday ? Theme.crust : Theme.icon
                    }

                    MouseArea {
                        id: dayMouse
                        anchors.fill: parent
                        enabled: cell.inMonth
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedDay = cell.cellDate
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.surface0
        }

        // ── Tasks for the selected day ───────────────────────────────────
        Item {
            width: parent.width
            height: 22

            Caption {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(root.selectedDay, "ddd d MMM")
                color: Theme.icon
                size: 12
                font.bold: true
            }

            Caption {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: Todos.countFor(root.selectedDay) > 0
                text: `${Todos.openCountFor(root.selectedDay)} open`
                color: Theme.overlay1
                size: 10
            }
        }

        Rectangle {
            width: parent.width
            height: 26
            radius: 9
            color: taskInput.activeFocus ? Theme.surface0 : Theme.alpha(Theme.surface0, 0.5)

            TextInput {
                id: taskInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.text
                selectByMouse: true
                clip: true

                onAccepted: {
                    Todos.add(root.selectedDay, text);
                    text = "";
                }
            }

            Caption {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: taskInput.text === "" && !taskInput.activeFocus
                text: "Add a task…"
                color: Theme.overlay0
                size: 11
            }
        }

        ListView {
            id: taskList
            width: parent.width
            height: Math.min(84, contentHeight)
            clip: true
            spacing: 2
            model: Todos.itemsFor(root.selectedDay)
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: task
                required property var modelData
                required property int index

                readonly property bool hovered: taskMouse.containsMouse || delMouse.containsMouse

                width: ListView.view.width
                height: 24
                radius: 8
                color: hovered ? Theme.surface0 : "transparent"

                // Full-width, declared first so the delete button sits above.
                MouseArea {
                    id: taskMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Todos.toggle(root.selectedDay, task.index)
                }

                Text {
                    id: box
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: task.modelData.done ? "󰄲" : "󰄱"
                    font.family: Theme.iconFont
                    font.pixelSize: 12
                    color: task.modelData.done ? Theme.icon : Theme.overlay1
                }

                Caption {
                    anchors.left: box.right
                    anchors.leftMargin: 8
                    anchors.right: del.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: task.modelData.text
                    color: task.modelData.done ? Theme.overlay0 : Theme.subtext0
                    font.strikeout: task.modelData.done
                    size: 11
                }

                Rectangle {
                    id: del
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    radius: 9
                    // Opacity, not visible: a hidden item takes no clicks.
                    opacity: task.hovered ? 1 : 0
                    color: delMouse.containsMouse ? Theme.alpha(Theme.red, 0.3) : "transparent"

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.anim
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: Theme.iconFont
                        font.pixelSize: 10
                        color: Theme.red
                    }

                    MouseArea {
                        id: delMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Todos.remove(root.selectedDay, task.index)
                    }
                }
            }
        }
    }

    component NavButton: Rectangle {
        id: nav

        property string glyph: ""
        signal triggered

        width: 22
        height: 22
        radius: 11
        color: navMouse.containsMouse ? Theme.surface0 : "transparent"

        Text {
            anchors.centerIn: parent
            text: nav.glyph
            font.family: Theme.iconFont
            font.pixelSize: 12
            color: Theme.subtext0
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.triggered()
        }
    }
}
