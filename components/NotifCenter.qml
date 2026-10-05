// Notification history center card (swaync panel replacement).
// Pure view: history list + dnd flag come via props from shell.qml.
pragma ComponentBehavior: Bound
import QtQuick

import "../theme"

Rectangle {
    id: root
    color: Theme.notifBg
    radius: Theme.notifRadius
    border.color: Theme.notifBorder
    border.width: 1
    clip: true

    required property var history
    property bool dnd: false
    property int unread: 0

    signal hideRequested()
    signal clearRequested()
    signal removeRequested(int index)
    signal dndToggled()

    // Same single-driver entry language as the island.
    property real progress: 0

    width: Theme.centerWidth
    height: Theme.centerHeight
    opacity: root.progress
    y: (1 - root.progress) * -24

    function open(): void {
        exitAnim.stop();
        enterAnim.start();
        root.forceActiveFocus();
    }

    function close(): void {
        enterAnim.stop();
        exitAnim.start();
    }

    NumberAnimation {
        id: enterAnim
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 450
        easing.type: Easing.OutExpo
    }
    NumberAnimation {
        id: exitAnim
        target: root
        property: "progress"
        to: 0
        duration: 180
        easing.type: Easing.InCubic
        onFinished: root.hideRequested()
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.close();
            event.accepted = true;
        }
    }

    // Swallow card clicks so the backdrop never fires from inside.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {}
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.notifPadding
        spacing: 8

        // Header
        Item {
            width: parent.width
            height: 30
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.unread > 0 ? "Notifications  (" + root.unread + " new)" : "Notifications"
                color: Theme.notifText
                font.family: Theme.notifFont
                font.pixelSize: Theme.notifTitleSize
                font.bold: true
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                // DND toggle pill
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 76
                    height: 26
                    radius: 13
                    color: root.dnd ? "#3a8cff" : "#0dffffff"
                    border.color: Theme.notifBorder
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: root.dnd ? "DND on" : "DND"
                        color: Theme.notifText
                        font.family: Theme.notifFont
                        font.pixelSize: Theme.notifSmallSize
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.dndToggled()
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.history.length > 0
                    text: "Clear all"
                    color: clearHover.containsMouse ? Theme.notifText : Theme.notifDim
                    font.family: Theme.notifFont
                    font.pixelSize: Theme.notifSmallSize
                    MouseArea {
                        id: clearHover
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        onClicked: root.clearRequested()
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: closeHover.containsMouse ? Theme.notifText : Theme.notifDim
                    font.family: Theme.notifFont
                    font.pixelSize: 14
                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        onClicked: root.close()
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.notifDivider
        }

        // Empty state
        Text {
            width: parent.width
            visible: root.history.length === 0
            horizontalAlignment: Text.AlignHCenter
            topPadding: 60
            text: root.dnd ? "Do Not Disturb is on.\nNew notifications wait here quietly." : "All caught up.\nNew notifications land here."
            color: Theme.notifDim
            font.family: Theme.notifFont
            font.pixelSize: Theme.notifBodySize
        }

        ListView {
            width: parent.width
            height: parent.height - 30 - 1 - 16
            visible: root.history.length > 0
            clip: true
            spacing: 8
            model: root.history
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: itemRow.implicitHeight + 36
                radius: 12
                color: delHover.containsMouse ? Theme.notifHover : Theme.notifRowBg
                border.color: Theme.notifBorder
                border.width: 1
                clip: true

                readonly property string imgSrc: {
                    var p = modelData.img || "";
                    if (p === "")
                        return "";
                    return p.indexOf("://") >= 0 ? p : "file://" + p;
                }

                Row {
                    id: itemRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 15
                    anchors.rightMargin: 30
                    anchors.topMargin: 18
                    spacing: 8

                    Rectangle {
                        anchors.top: parent.top
                        width: visible ? 36 : 0
                        height: 36
                        radius: 8
                        color: "transparent"
                        clip: true
                        visible: imgSrc !== "" && itemImg.status !== Image.Error

                        Image {
                            id: itemImg
                            anchors.fill: parent
                            source: imgSrc
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

                    Column {
                        width: parent.width - (imgSrc !== "" ? 44 : 0)
                        spacing: 10

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - 44
                            elide: Text.ElideRight
                            text: (modelData.app || "Notification").toUpperCase()
                            color: Theme.notifDim
                            font.family: Theme.notifFont
                            font.pixelSize: Theme.notifSmallSize
                            font.bold: true
                        }
                        Text {
                            width: 44
                            horizontalAlignment: Text.AlignRight
                            text: modelData.stamp
                            color: "#66ffffff"
                            font.family: Theme.notifFont
                            font.pixelSize: Theme.notifSmallSize
                        }
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: modelData.summary
                        color: Theme.notifText
                        font.family: Theme.notifFont
                        font.pixelSize: Theme.notifTitleSize
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        text: modelData.body
                        color: Theme.notifDim
                        font.family: Theme.notifFont
                        font.pixelSize: Theme.notifBodySize
                    }
                    }
                }

                // Row hover layer FIRST (bottom of stacking) so it never
                // swallows presses meant for the close button or links:
                // hover is broadcast to all layers, presses go topmost.
                MouseArea {
                    id: delHover
                    anchors.fill: parent
                    hoverEnabled: true
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    text: "✕"
                    color: delXHover.containsMouse ? Theme.notifText : "#66ffffff"
                    font.family: Theme.notifFont
                    font.pixelSize: 12
                    MouseArea {
                        id: delXHover
                        anchors.fill: parent
                        anchors.margins: -10
                        hoverEnabled: true
                        onClicked: root.removeRequested(index)
                    }
                }
            }
        }
    }
}
