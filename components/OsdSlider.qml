// OSD slider: background track + level fill.
import QtQuick

import "../theme"

Rectangle {
    id: track
    property int level: 0

    width: Theme.trackWidth
    height: Theme.trackHeight
    radius: Theme.trackRadius
    color: Theme.trackBg

    Rectangle {
        width: track.width * Math.max(0, Math.min(100, track.level)) / 100
        height: parent.height
        radius: Theme.trackRadius
        color: Theme.fillColor
    }
}
