pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Pipewire
import "../theme"

IslandPanel {
    id: root
    panelColor: Glass.panel
    expandedRadius: Glass.radius
    panelBorder: Glass.stroke
    clip: true

    readonly property var outputs: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var inputs: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream && n.name.indexOf(".monitor") < 0)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real frameW: 366
    readonly property real expandedHeight: Math.min(640, body.implicitHeight + 40)
    readonly property real frameH: expandedHeight

    PwObjectTracker {
        objects: root.outputs.concat(root.inputs)
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
