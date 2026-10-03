// OSD pill: icon + slider + numeric label. Pure view — state comes via props.
import QtQuick

import "../theme"

Rectangle {
    id: root
    property string kind: "volume"
    property int level: 0
    property bool muted: false

    // Icon per kind/level (Nerd Font — same glyphs as waybar)
    property string icon: {
        if (kind === "brightness")
            return "󰃠";
        if (kind === "mic")
            return muted ? "󰍭" : "󰍬";
        if (muted || level <= 0)
            return "󰖁";
        if (level < Theme.iconLowMax)
            return "󰕿";
        if (level < Theme.iconMidMax)
            return "󰖀";
        return "󰕾";
    }
    property string label: {
        if (kind === "mic")
            return muted ? "Muted" : "Live";
        return String(level);
    }

    width: Theme.pillWidth
    height: Theme.pillHeight
    radius: Theme.pillRadius
    color: Theme.pillBg
    border.color: Theme.pillBorder
    border.width: Theme.pillBorderWidth

    Row {
        anchors.centerIn: parent
        spacing: Theme.rowSpacing

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconBoxWidth
            horizontalAlignment: Text.AlignHCenter
            text: root.icon
            color: Theme.iconColor
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
        }

        OsdSlider {
            anchors.verticalCenter: parent.verticalCenter
            level: root.level
            visible: root.kind !== "mic"
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: root.kind === "mic" ? Theme.labelMicWidth : Theme.labelNumWidth
            text: root.label
            color: Theme.labelColor
            font.family: Theme.labelFont
            font.pixelSize: Theme.labelSize
            font.bold: true
        }
    }
}
