import QtQuick
import "../theme"

Item {
    id: root
    required property var node
    property string title: "Volume"
    property string icon: "󰕾"
    readonly property bool available: !!node && !!node.audio && node.ready
    readonly property real volume: available ? node.audio.volume : 0
    readonly property bool muted: available && node.audio.muted
    implicitHeight: 83
    opacity: available ? 1 : 0.45

    function setVolume(value: real): void {
        if (!available)
            return;
        node.audio.volume = Math.max(0, Math.min(1, value));
    }

    Text {
        anchors.left: parent.left
        text: root.title
        color: Glass.text
        font.family: Glass.font
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }
    Text {
        anchors.right: parent.right
        text: !root.available ? "Unavailable" : root.muted ? "Muted" : Math.round(root.volume * 100) + "%"
        color: Glass.secondary
        font.family: Glass.font
        font.pixelSize: 12
    }
    Rectangle {
        id: muteButton
        y: 29
        width: 38
        height: 38
        radius: 19
        color: muteMouse.containsMouse ? Glass.hover : Glass.card
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: root.muted ? "Unmute " + root.title : "Mute " + root.title
        Accessible.onPressAction: if (root.available)
            root.node.audio.muted = !root.muted
        Keys.onSpacePressed: if (root.available)
            root.node.audio.muted = !root.muted
        Keys.onReturnPressed: if (root.available)
            root.node.audio.muted = !root.muted
        Text {
            anchors.centerIn: parent
            text: root.muted ? "󰖁" : root.icon
            color: root.muted ? Glass.secondary : Glass.text
            font.family: Theme.iconFont
            font.pixelSize: 19
        }
        MouseArea {
            id: muteMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.available
            cursorShape: Qt.PointingHandCursor
            onClicked: root.node.audio.muted = !root.muted
        }
    }
    Item {
        id: slider
        anchors.left: muteButton.right
        anchors.leftMargin: 13
        anchors.right: parent.right
        y: 29
        height: 38
        activeFocusOnTab: true
        Accessible.role: Accessible.Slider
        Accessible.name: root.title
        Accessible.description: "Use left and right arrows to adjust volume"
        Keys.onLeftPressed: root.setVolume(root.volume - 0.05)
        Keys.onRightPressed: root.setVolume(root.volume + 0.05)
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Home) {
                root.setVolume(0);
                event.accepted = true;
            } else if (event.key === Qt.Key_End) {
                root.setVolume(1);
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 8
            radius: 4
            color: Glass.hover
            Rectangle {
                width: parent.width * Math.min(1, root.volume)
                height: parent.height
                radius: 4
                color: root.muted ? Glass.secondary : Glass.accent
            }
        }
        Rectangle {
            x: Math.min(1, root.volume) * (slider.width - width)
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: 9
            color: Glass.text
            border.width: slider.activeFocus ? 2 : 0
            border.color: Glass.accent
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.available
            cursorShape: Qt.PointingHandCursor
            function updateVolume(x: real): void {
                root.setVolume((x - 9) / Math.max(1, width - 18));
            }
            onPressed: function (mouse) {
                slider.forceActiveFocus();
                updateVolume(mouse.x);
            }
            onPositionChanged: function (mouse) {
                if (pressed)
                    updateVolume(mouse.x);
            }
            onWheel: function (wheel) {
                root.setVolume(root.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05));
                wheel.accepted = true;
            }
        }
    }
}
