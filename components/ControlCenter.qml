import QtQuick
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../theme"

IslandPanel {
    id: root
    required property bool dnd
    signal dndToggled()
    signal wifiRequested()
    signal soundRequested()
    signal profileRequested()
    required property string profile
    required property string profileLabel
    readonly property int frameW: 356
    readonly property int frameH: content.implicitHeight + 32
    readonly property var devices: Networking.devices
    readonly property var wifiDevices: devices.values.filter(d => d.type === DeviceType.Wifi)
    readonly property var adapter: wifiDevices.find(d => d.connected)
    readonly property var wireless: adapter ? adapter.networks.values.find(net => net.connected) : null
    expandedRadius: Glass.radius
    panelColor: Glass.panel
    panelBorder: Glass.stroke

    PwObjectTracker { objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : [] }
    Keys.onEscapePressed: close()
    MouseArea { anchors.fill: parent }
    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 9
        Text {
            text: "Control Center"
            font.family: Glass.font
            font.pixelSize: 18
            font.weight: Font.DemiBold
            color: Glass.text
            bottomPadding: 3
        }
        Row {
            width: parent.width
            spacing: 8
            ControlTile {
                width: (parent.width - parent.spacing) / 2
                height: implicitHeight
                title: "Wi-Fi"
                glyph: ""
                selected: root.wifiDevices.length > 0 && Networking.wifiEnabled && Networking.wifiHardwareEnabled
                detail: !root.wifiDevices.length ? "Unavailable" : root.wireless ? root.wireless.name : selected ? "On" : "Off"
                hasDetails: true
                toggleEnabled: root.wifiDevices.length > 0 && Networking.wifiHardwareEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                onDetailsRequested: root.wifiRequested()
            }
            ControlTile {
                width: (parent.width - parent.spacing) / 2
                height: implicitHeight
                title: "Focus"
                detail: root.dnd ? "Do Not Disturb" : "Off"
                glyph: ""
                selected: root.dnd
                onToggled: root.dndToggled()
            }
        }
        ControlTile {
            width: parent.width
            height: implicitHeight
            title: "Power Profile"
            glyph: "󰓅"
            selected: root.profile === "performance"
            detail: root.profileLabel
            hasDetails: true
            onToggled: root.profileRequested()
            onDetailsRequested: root.profileRequested()
        }
        Rectangle {
            width: parent.width
            height: 107
            radius: 16
            color: Glass.card
            AudioLevel {
                anchors.fill: parent
                anchors.margins: 12
                title: "Sound"
                node: Pipewire.defaultAudioSink
            }
        }
        Rectangle {
            width: parent.width
            height: 34
            color: soundArea.containsMouse || activeFocus ? Glass.hover : "transparent"
            radius: 10
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Sound options"
            Accessible.onPressAction: root.soundRequested()
            Keys.onReturnPressed: root.soundRequested()
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "Sound options"
                color: Glass.text
                font.family: Glass.font
                font.pixelSize: 13
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                color: Glass.secondary
                font.pixelSize: 20
            }
            MouseArea {
                id: soundArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.soundRequested()
            }
        }
    }
}
