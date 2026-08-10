import QtQuick
import "root:/"

Column {
    id: st

    property string label: ""
    property int value: 0
    property int from: 0
    property int to: 100

    signal moved(int value)

    width: parent.width
    spacing: 3

    Item {
        width: parent.width
        height: 15

        Caption {
            anchors.left: parent.left
            text: st.label
            color: Theme.subtext0
            size: 11
        }
        Caption {
            anchors.right: parent.right
            text: st.value
            color: Theme.icon
            size: 11
        }
    }

    LevelSlider {
        width: parent.width
        accent: Theme.icon
        value: (st.value - st.from) / Math.max(1, st.to - st.from)
        onMoved: v => st.moved(Math.round(st.from + v * (st.to - st.from)))
    }
}

