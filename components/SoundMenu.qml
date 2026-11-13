pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Pipewire
import "../theme"

Rectangle {
    id: root
    color: Glass.panel
    radius: Glass.radius
    border.width: 1
    border.color: Glass.stroke
    clip: true

    property real progress: 0
    property bool exiting: false
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var inputs: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream && n.name.indexOf(".monitor") < 0)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real frameW: 366
    readonly property real expandedHeight: Math.min(640, body.implicitHeight + 40)
    readonly property real frameH: expandedHeight
    opacity: progress
    scale: 0.96 + 0.04 * progress
    transformOrigin: Item.TopRight
    signal hideRequested

    PwObjectTracker {
        objects: root.outputs.concat(root.inputs)
    }

    function open(): void {
        morphOut.stop();
        exiting = false;
        morphIn.restart();
    }
    function close(): void {
        if (exiting)
            return;
        exiting = true;
        morphIn.stop();
        morphOut.restart();
    }
    NumberAnimation {
        id: morphIn
        target: root
        property: "progress"
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: morphOut
        target: root
        property: "progress"
        to: 0
        duration: 180
        easing.type: Easing.InCubic
        onFinished: {
            root.exiting = false;
            root.hideRequested();
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: width
        contentHeight: body.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        opacity: Math.max(0, (root.progress - 0.6) / 0.4)
        enabled: root.progress > 0.95 && !root.exiting

        Column {
            id: body
            width: parent.width
            spacing: 12

            Item {
                width: parent.width
                height: 32
                Text {
                    text: "Sound"
                    color: Glass.text
                    font.family: Glass.font
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    anchors.right: parent.right
                    width: 28
                    height: 28
                    radius: 14
                    color: closeMouse.containsMouse ? Glass.hover : Glass.card
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: Glass.secondary
                        font.pixelSize: 20
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.close()
                    }
                }
            }

            Text {
                width: parent.width
                visible: !Pipewire.ready
                text: "Connecting to the audio service…"
                color: Glass.secondary
                font.family: Glass.font
                font.pixelSize: 12
            }

            AudioLevel {
                width: parent.width
                node: root.sink
                title: "Output volume"
                icon: "󰕾"
            }
            Text {
                text: "OUTPUT"
                color: Glass.secondary
                font.family: Glass.font
                font.pixelSize: 10
                font.letterSpacing: 1.2
            }
            Text {
                visible: root.outputs.length === 0
                text: "No output devices available"
                color: Glass.secondary
                font.family: Glass.font
                font.pixelSize: 12
            }
            Repeater {
                model: root.outputs
                delegate: AudioDeviceRow {
                    required property var modelData
                    width: body.width
                    node: modelData
                    selected: !!root.sink && root.sink.id === modelData.id
                    icon: /bluez/.test(modelData.name) ? "󰂯" : /headphone|headset/i.test(modelData.description) ? "󰋋" : "󰓃"
                    onChosen: Pipewire.preferredDefaultAudioSink = modelData
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Glass.stroke
            }
            AudioLevel {
                width: parent.width
                node: root.source
                title: "Input volume"
                icon: "󰍬"
            }
            Text {
                text: "INPUT"
                color: Glass.secondary
                font.family: Glass.font
                font.pixelSize: 10
                font.letterSpacing: 1.2
            }
            Text {
                visible: root.inputs.length === 0
                text: "No microphones available"
                color: Glass.secondary
                font.family: Glass.font
                font.pixelSize: 12
            }
            Repeater {
                model: root.inputs
                delegate: AudioDeviceRow {
                    required property var modelData
                    width: body.width
                    node: modelData
                    selected: !!root.source && root.source.id === modelData.id
                    icon: "󰍬"
                    onChosen: Pipewire.preferredDefaultAudioSource = modelData
                }
            }
        }
    }
}
