// Notification history center card (swaync panel replacement).
// Pure view: history list + dnd flag come via props from shell.qml.
pragma ComponentBehavior: Bound
import QtQuick

import "../theme"

Rectangle {
    id: root
    color: Theme.notifBg
    // Single continuous morph, same language as the island: every dimension
    // is a function of `progress` (0 dot → 1 full card), driven by exactly
    // one animation. Radius blends from a perfect circle into the card
    // corner — no staged retargets.
    radius: (1 - root.progress) * Math.min(root.width, root.height) / 2 + root.progress * Theme.notifRadius
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

    // 0 = dot, 1 = full card. Animated once per open (OutExpo: fast
    // expansion, soft landing — the Dynamic Island feel).
    property real progress: 0
    property bool exiting: false

    readonly property real frameW: Theme.centerDot + (Theme.centerWidth - Theme.centerDot) * root.progress
    readonly property real frameH: Theme.centerDot + (Theme.centerHeight - Theme.centerDot) * root.progress
    // Contents fade in over the final stretch of the morph only.
    readonly property real contentOpacity: Math.min(1, Math.max(0, (root.progress - 0.8) / 0.2))

    function open(): void {
        morphOut.stop();
        root.exiting = false;
        morphIn.start();
        root.forceActiveFocus();
    }

    function close(): void {
        if (root.exiting)
            return;
        root.exiting = true;
        morphIn.stop();
        morphOut.start();
    }

    // The one and only morph driver. Entry: fast continuous expansion;
    // exit: quick shrink, then the shell hides the window.
    NumberAnimation {
        id: morphIn
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 650
        easing.type: Easing.OutExpo
    }
    NumberAnimation {
        id: morphOut
        target: root
        property: "progress"
        to: 0
        duration: 220
        easing.type: Easing.InCubic
        onFinished: {
            root.exiting = false;
            root.hideRequested();
        }
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

    // ---- morph start: bare pulsing dot, dissolves as expansion begins ----
    // Outer fades with progress; inner runs the pulse loop so the two
    // opacity drivers never fight over one property.
    Item {
        anchors.centerIn: parent
        width: 8
        height: 8
        opacity: 1 - Math.min(1, root.progress * 4)
        visible: opacity > 0

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: Theme.notifAccent

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.progress < 0.3
                NumberAnimation {
                    to: 0.3
                    duration: 900
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    to: 1
                    duration: 900
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }

    Column {
        id: cardView
        anchors.fill: parent
        anchors.margins: Theme.notifPadding
        spacing: 8
        opacity: root.contentOpacity
        enabled: root.progress > 0.85
        visible: opacity > 0

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
                height: itemRow.implicitHeight + 28
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

                // Row hover layer FIRST (bottom of stacking) so it never
                // swallows presses meant for the close button: hover is
                // broadcast to all layers, presses go to the topmost.
                MouseArea {
                    id: delHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onPressed: notifState.log("row press index=" + index)
                }

                Row {
                    id: itemRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 14
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

                    // Header: app + stamp + close on one baseline. Plain Item
                    // (never a Row) so every child can use real anchors —
                    // anchors inside a positioner break hit geometry.
                    Item {
                        width: parent.width
                        height: 18
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40 - 16 - 12
                            elide: Text.ElideRight
                            text: (modelData.app || "Notification").toUpperCase()
                            color: Theme.notifDim
                            font.family: Theme.notifFont
                            font.pixelSize: Theme.notifSmallSize
                            font.bold: true
                        }
                        Text {
                            anchors.right: xText.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            horizontalAlignment: Text.AlignRight
                            text: modelData.stamp
                            color: "#66ffffff"
                            font.family: Theme.notifFont
                            font.pixelSize: Theme.notifSmallSize
                        }
                        Text {
                            id: xText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            horizontalAlignment: Text.AlignHCenter
                            text: "✕"
                            color: delXHover.containsMouse ? Theme.notifText : "#66ffffff"
                            font.family: Theme.notifFont
                            font.pixelSize: 12
                            MouseArea {
                                id: delXHover
                                anchors.fill: parent
                                anchors.margins: -8
                                hoverEnabled: true
                                onPressed: notifState.log("x press index=" + index)
                                onClicked: root.removeRequested(index)
                            }
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
            }
        }
    }
}
