import QtQuick
import QtQuick.Controls.Basic
import "../theme"

Button {
    id: button
    property bool pill: false
    width: pill ? 58 : 28
    height: 28
    padding: 0
    hoverEnabled: true

    background: Rectangle {
        radius: button.pill ? height / 2 : 8
        color: button.hovered || button.down ? Theme.islandHover : button.pill ? Theme.notifRowBg : "transparent"
        border.width: button.pill || button.visualFocus ? 1 : 0
        border.color: button.visualFocus ? Theme.islandAccent : Theme.islandBorder
    }
    contentItem: Text {
        text: button.text
        color: button.pill || button.hovered || button.visualFocus ? Theme.islandText : Theme.islandDim
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: Glass.font
        font.pixelSize: button.pill ? 11 : 20
        font.weight: Font.DemiBold
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
