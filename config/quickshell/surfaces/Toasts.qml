import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "root:/"

// Notification toasts, stacked under the right end of the bar.
PanelWindow {
    id: root

    property int cardWidth: 380

    // Critical notifications are shown even with toasts off or DND on: the
    // whole point of the battery alert is that it cannot be missed.
    readonly property bool anyCritical: Notifs.popups.some(n => n.urgency === NotificationUrgency.Critical)

    visible: Notifs.popups.length > 0 && (root.anyCritical || (Settings.toastsEnabled && !Settings.dnd))
    color: "transparent"
    // Positioned against the raw screen edge. Without this the bar's
    // exclusive zone is added to the top margin, pushing the toasts a full
    // bar height further down than asked for.
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    implicitWidth: cardWidth
    // Capped at half the screen; beyond that the stack scrolls.
    // Whichever comes first: the configured toast count, or half the screen.
    readonly property int maxStackHeight: Math.min(Math.round((root.screen ? root.screen.height : 1080) / 2), Settings.toastMaxVisible * 110)
    implicitHeight: Math.max(1, Math.min(maxStackHeight, stack.implicitHeight))

    anchors {
        top: true
        // Follows the configured side; only one of these is ever set.
        right: Settings.toastPosition === "right"
        left: Settings.toastPosition === "left"
    }

    margins {
        // 16px clear of the bar's bottom edge.
        top: Theme.barMargin + Theme.barHeight + 16
        right: Theme.barSideMarginRight
        left: Theme.barSideMargin
    }

    // Only the cards themselves should catch clicks.
    mask: Region {
        item: stackView
    }

    Flickable {
        id: stackView
        anchors.fill: parent
        contentHeight: stack.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: stack.implicitHeight > height

        Column {
            id: stack
            anchors.top: parent.top
            anchors.right: parent.right
            width: root.cardWidth
            spacing: 8

        // ScriptModel rather than the raw array: a Repeater fed a plain JS
        // array rebuilds every delegate whenever the array is reassigned, so
        // dismissing one toast destroyed the others mid-animation and
        // replayed their entrance. ScriptModel diffs by identity instead.
        ScriptModel {
            id: popupModel
            values: Notifs.popups
        }

        Repeater {
            model: popupModel

            Rectangle {
                id: toast
                required property Notification modelData

                // Normal urgency follows the bar's accent, matching the cards in
                // NotificationPanel. Critical stays red and low stays muted:
                // those carry meaning, so they are deliberately not themed.
                readonly property color urgencyColor: modelData.urgency === NotificationUrgency.Critical ? Theme.red : modelData.urgency === NotificationUrgency.Low ? Theme.overlay1 : Theme.accent

                // A screenshot gets a wide preview instead of the small icon
                // chip — the picture is the whole content of the message.
                readonly property string previewSource: Notifs.previewOf(modelData)
                readonly property bool hasPreview: toast.previewSource !== ""

                // Exit is animated before the model drops the entry — a
                // Repeater destroys its delegate the instant the model
                // changes, so animating after removal is not possible.
                property bool leaving: false
                property real collapse: 1

                // Runs whatever the toast was going to do, but only after the
                // card has finished leaving.
                property var pendingAction: null

                function close(extra) {
                    if (toast.leaving)
                        return;
                    toast.pendingAction = extra ?? null;
                    toast.leaving = true;
                    exitAnim.start();
                }

                SequentialAnimation {
                    id: exitAnim

                    ParallelAnimation {
                        NumberAnimation {
                            target: toast
                            property: "opacity"
                            to: 0
                            duration: Theme.dur(120)
                            easing.type: Easing.InQuad
                        }
                        NumberAnimation {
                            target: toast
                            property: "x"
                            to: 70
                            duration: Theme.dur(130)
                            easing.type: Easing.InCubic
                        }
                    }

                    // Collapse afterwards so the toasts below slide up rather
                    // than jumping the moment this one is gone.
                    NumberAnimation {
                        target: toast
                        property: "collapse"
                        to: 0
                        duration: Theme.dur(90)
                        easing.type: Easing.InQuad
                    }

                    ScriptAction {
                        script: {
                            if (toast.pendingAction)
                                toast.pendingAction();
                            Notifs.dismissPopup(toast.modelData);
                        }
                    }
                }

                width: stack.width
                // Driven through `collapse` rather than animating `height`
                // directly, which would break the binding to the content.
                height: Math.max(0, (content.implicitHeight + 24) * toast.collapse)
                // Column still reserves spacing for a zero-height child.
                visible: toast.collapse > 0.01
                clip: toast.leaving
                radius: Theme.popupRadius
                // The panel tier, not a toast-specific colour: a toast floats on
                // the desktop like the bar and the panels do, so it takes the
                // same base (crust) and follows panelOpacity with them. The
                // cards inside NotificationPanel sit on top of that, which is
                // why they use surface0 instead.
                color: Theme.panelBg
                border.width: 1
                border.color: Theme.alpha(urgencyColor, 0.5)

                // Slide + fade in.
                opacity: 0
                x: 40
                Component.onCompleted: {
                    opacity = 1;
                    x = 0;
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.dur(220)
                    }
                }
                Behavior on x {
                    NumberAnimation {
                        duration: Theme.dur(260)
                        easing.type: Easing.OutCubic
                    }
                }

                // Critical notifications stay until dismissed.
                //
                // The null check is what keeps a card mortal: if the
                // Notification is destroyed under it, reading `urgency` off
                // the dead object left this binding false and the toast sat
                // there forever. Anything that is no longer a live
                // notification expires on the normal timer instead.
                Timer {
                    running: !toast.modelData || toast.modelData.urgency !== NotificationUrgency.Critical
                    interval: toast.modelData && toast.modelData.expireTimeout > 0 ? toast.modelData.expireTimeout : Settings.toastDuration
                    onTriggered: toast.close()
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: parent.height - 20
                    radius: 2
                    color: toast.urgencyColor
                }

                Image {
                    id: thumb
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    width: visible ? 34 : 0
                    height: 34
                    sourceSize.width: 34
                    sourceSize.height: 34
                    fillMode: Image.PreserveAspectFit
                    visible: source != "" && !toast.hasPreview
                    source: {
                        if (toast.modelData.image)
                            return toast.modelData.image;
                        if (toast.modelData.appIcon)
                            return Quickshell.iconPath(toast.modelData.appIcon, true);
                        return "";
                    }
                }

                Column {
                    id: content
                    anchors.left: thumb.visible ? thumb.right : parent.left
                    anchors.leftMargin: thumb.visible ? 11 : 15
                    anchors.right: closeBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Caption {
                        vcenter: false
                        text: toast.modelData.appName || "system"
                        color: toast.urgencyColor
                        size: 10
                        font.bold: true
                    }

                    Caption {
                        width: parent.width
                        vcenter: false
                        text: toast.modelData.summary
                        color: Theme.text
                        size: 13
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Caption {
                        width: parent.width
                        visible: text !== ""
                        vcenter: false
                        text: toast.modelData.body
                        color: Theme.subtext0
                        size: 11
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }

                    Item {
                        width: parent.width

                        // Same rule as the panel: the box takes the image's
                        // ratio, floored at 16:9, so screenshots are not cut.
                        height: toastPreview.ready ? Math.round(width / Math.max(16 / 9, toastPreview.aspect)) + 5 : 0
                        visible: toastPreview.ready

                        Thumbnail {
                            id: toastPreview

                            anchors.fill: parent
                            anchors.topMargin: 5
                            corner: 8
                            decodeWidth: 640
                            source: toast.previewSource
                        }

                        MouseArea {
                            anchors.fill: toastPreview
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["xdg-open", decodeURIComponent(toast.previewSource.replace("file://", ""))])
                        }
                    }

                    Row {
                        spacing: 6
                        visible: toast.modelData.actions.length > 0
                        topPadding: 4

                        Repeater {
                            model: toast.modelData.actions

                            Rectangle {
                                id: action
                                required property NotificationAction modelData

                                width: actionLabel.implicitWidth + 20
                                height: 24
                                radius: 8
                                color: actionMouse.containsMouse ? Theme.alpha(toast.urgencyColor, 0.3) : Theme.surface0

                                Caption {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: action.modelData.text
                                    color: Theme.text
                                    size: 11
                                }

                                MouseArea {
                                    id: actionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        action.modelData.invoke();
                                        toast.close();
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    width: 22
                    height: 22
                    radius: 8
                    color: closeMouse.containsMouse ? Theme.alpha(Theme.red, 0.3) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: Theme.iconFont
                        font.pixelSize: 11
                        color: closeMouse.containsMouse ? Theme.red : Theme.overlay0
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            toast.close(() => {
                                Notifs.removeMatching(toast.modelData);
                                toast.modelData.dismiss();
                            });
                        }
                    }
                }
            }
        }
        }
    }
}
