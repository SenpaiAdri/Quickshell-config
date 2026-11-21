pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../theme"

Rectangle {
    id: tile
    required property string title
    required property string detail
    required property string glyph
    property bool selected: false
    property bool toggleEnabled: true
    property bool hasDetails: false
    property bool fadeDetail: false
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
            color: tile.selected ? Glass.accentText : Glass.text
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
        anchors.rightMargin: badge.anchors.leftMargin
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
                id: detailLabel
                readonly property real fadeStart: Math.max(0.5, 1 - 32 / Math.max(1, width))
                width: parent.width
                text: tile.detail
                textFormat: Text.PlainText
                font.family: Glass.font
                font.pixelSize: 11
                color: Glass.secondary
                elide: tile.fadeDetail ? Text.ElideNone : Text.ElideRight
                clip: tile.fadeDetail && implicitWidth > width
                layer.enabled: tile.fadeDetail && implicitWidth > width * fadeStart && GraphicsInfo.api !== GraphicsInfo.Software
                layer.effect: MultiEffect {
                    autoPaddingEnabled: false
                    maskEnabled: true
                    maskSource: fadeMask
                    // Blend across the mask's full alpha range.
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }

                Rectangle {
                    id: fadeMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: detailLabel.layer.enabled
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: detailLabel.fadeStart; color: "white" }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
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
