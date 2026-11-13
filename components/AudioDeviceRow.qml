import QtQuick
import "../theme"

Rectangle {
    id: root
    required property var node
    property bool selected: false
    property string icon: "󰓃"
    signal chosen
    height: 46
    radius: 11
    color: selected ? Glass.card : rowMouse.containsMouse ? Glass.hover : "transparent"
    activeFocusOnTab: true
    Accessible.role: Accessible.RadioButton
    Accessible.name: node.description || node.nickname || node.name
    Accessible.onPressAction: root.chosen()
    Keys.onReturnPressed: root.chosen()
    Keys.onSpacePressed: root.chosen()
    Text {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        font.family: Theme.iconFont
        font.pixelSize: 19
        color: root.selected ? Glass.accent : Glass.text
    }
    Text {
        anchors.left: parent.left
        anchors.leftMargin: 44
        anchors.right: parent.right
        anchors.rightMargin: 38
        anchors.verticalCenter: parent.verticalCenter
        text: root.node.description || root.node.nickname || root.node.name
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Glass.text
        font.family: Glass.font
        font.pixelSize: 12
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 13
        anchors.verticalCenter: parent.verticalCenter
        text: "✓"
        visible: root.selected
        color: Glass.accent
        font.pixelSize: 16
    }
    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.chosen();
        }
    }
}
