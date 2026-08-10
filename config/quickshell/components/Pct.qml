import QtQuick
import "root:/"

SliderRow {
    id: pct

    signal picked(real value)

    readout: `${Math.round(pct.value * 100)}%`
    onMoved: v => pct.picked(Math.round(v * 100) / 100)
}

