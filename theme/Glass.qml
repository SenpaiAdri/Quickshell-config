pragma Singleton
import QtQuick

QtObject {
    readonly property color panel: Theme.islandBg
    readonly property color card: Theme.notifRowBg
    readonly property color hover: Theme.islandHover
    readonly property color stroke: Theme.islandBorder
    readonly property color text: Theme.islandText
    readonly property color secondary: Theme.islandDim
    readonly property color accent: Theme.islandAccent
    readonly property color accentText: Theme.islandTodayText
    readonly property color danger: Theme.notifCritical
    readonly property string font: "Inter"
    readonly property int radius: 22
}
