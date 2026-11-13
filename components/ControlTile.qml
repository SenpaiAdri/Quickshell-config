import QtQuick
import "../theme"

Rectangle {
    id: tile
    required property string title
    required property string detail
    required property string glyph
    property bool selected: false
    property bool toggleEnabled: true
    property bool hasDetails: false
    signal toggled()
    signal detailsRequested()
    color: Glass.card
    radius: 16
    implicitHeight: 62

    Rectangle {
        id: badge
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        radius: 17
        color: tile.selected ? Glass.accent : Glass.hover
        Text {
            anchors.centerIn: parent
            text: tile.glyph
            font.family: Theme.iconFont
            font.pixelSize: 16
            color: Glass.text
        }
        Accessible.role: Accessible.Button
        Accessible.name: tile.title + ", " + tile.detail
        Accessible.onPressAction: if (tile.toggleEnabled) tile.toggled()
        activeFocusOnTab: tile.toggleEnabled
        border.color: activeFocus ? Glass.text : "transparent"
        Keys.onSpacePressed: if (tile.toggleEnabled) tile.toggled()
        Keys.onReturnPressed: if (tile.toggleEnabled) tile.toggled()
        MouseArea {
            anchors.fill: parent
            enabled: tile.toggleEnabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
        }
    }
    Item {
        id: labelArea
        anchors.left: badge.right
        anchors.leftMargin: 7
        anchors.right: parent.right
        anchors.rightMargin: 6
        height: parent.height
        Column {
            anchors.left: parent.left
            anchors.right: tile.hasDetails ? arrow.left : parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                text: tile.title
                font.family: Glass.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Glass.text
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: tile.detail
                textFormat: Text.PlainText
                font.family: Glass.font
                font.pixelSize: 11
                color: Glass.secondary
                elide: Text.ElideRight
            }
        }
        Text {
            id: arrow
            visible: tile.hasDetails
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: Glass.secondary
            font.pixelSize: 20
        }
        function activate(): void {
            if (tile.hasDetails) tile.detailsRequested();
            else if (tile.toggleEnabled) tile.toggled();
        }
        activeFocusOnTab: tile.hasDetails
        Accessible.role: Accessible.Button
        Accessible.name: tile.hasDetails ? tile.title + " options" : tile.title
        Accessible.onPressAction: activate()
        Keys.onReturnPressed: activate()
        MouseArea {
            anchors.fill: parent
            enabled: tile.toggleEnabled || tile.hasDetails
            cursorShape: Qt.PointingHandCursor
            onClicked: labelArea.activate()
        }
    }
}
