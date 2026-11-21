pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import "../theme"

IslandPanel {
    id: root
    property bool overviewVisible: false
    property string profile: "unavailable"
    property var availableProfiles: []
    property string error: ""
    property string requestedProfile: ""
    readonly property var labels: ({"power-saver": "Power Saver", "balanced": "Balanced", "performance": "Performance"})
    readonly property var options: availableProfiles.length ? availableProfiles : Object.keys(labels)
    readonly property string profileLabel: labels[profile] || "Unavailable"
    readonly property int frameW: 330
    readonly property int frameH: body.implicitHeight + 32

    onOpening: refresh()

    function refresh(): void {
        if (!power.running && !slider.pressed)
            run("");
    }

    function select(index: int): void {
        const target = availableProfiles[index];
        if (!power.running && visible && !exiting && target && target !== profile)
            run(target);
    }

    function run(target: string): void {
        const directory = Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config";
        const script = directory + "/waybar/scripts/power-profile.sh";
        requestedProfile = target;
        power.exec(target ? [script, "set", target] : [script, "status"]);
    }

    Process {
        id: power
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const status = JSON.parse(text);
                    root.profile = status.alt;
                    root.availableProfiles = status.profiles || [];
                    root.error = !status.error ? "" : root.requestedProfile
                        ? "Couldn’t change the power profile" : "Power profiles unavailable";
                    if (root.requestedProfile && root.profile === root.requestedProfile && !root.error)
                        Quickshell.execDetached(["pkill", "-SIGRTMIN+8", "-u", Quickshell.env("USER"), "-x", "waybar"]);
                } catch (err) {
                    root.profile = "unavailable";
                    root.availableProfiles = [];
                    root.error = "Power profiles unavailable";
                }
                slider.value = Math.max(0, root.options.indexOf(root.profile));
            }
        }
    }

    Timer {
        interval: 5000
        running: root.visible || root.overviewVisible
        repeat: true
        onTriggered: root.refresh()
    }

    Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16

        Text {
            text: "Power Profile"
            color: Glass.text
            font.family: Glass.font
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }

        Slider {
            id: slider
            width: body.width
            height: 44
            padding: 0
            leftPadding: Math.max(0, width / (2 * root.options.length) - handle.width / 2)
            rightPadding: leftPadding
            to: Math.max(1, root.options.length - 1)
            stepSize: 1
            live: false
            snapMode: Slider.SnapOnRelease
            hoverEnabled: false
            enabled: root.availableProfiles.length > 1
            Accessible.name: "Power Profile"
            Accessible.description: root.profileLabel
            Accessible.onIncreaseAction: root.select(value + 1)
            Accessible.onDecreaseAction: root.select(value - 1)
            onMoved: if (!pressed) root.select(value)
            onPressedChanged: if (!pressed) root.select(value)

            background: Rectangle {
                id: track
                x: slider.leftPadding + slider.handle.width / 2 - radius
                y: (slider.height - height) / 2
                width: slider.availableWidth - slider.handle.width + 2 * radius
                height: 8
                radius: height / 2
                color: "#35373d"

                Rectangle {
                    width: Math.min(parent.width, 2 * parent.radius + slider.visualPosition * (parent.width - 2 * parent.radius))
                    height: parent.height
                    radius: parent.radius
                    color: "#70b3ff"
                    visible: root.availableProfiles.length > 0
                }

                Repeater {
                    model: root.options.length
                    Rectangle {
                        required property int index
                        x: track.radius + index / slider.to * (track.width - 2 * track.radius) - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 3
                        radius: width / 2
                        color: Glass.text
                        opacity: 0.64
                    }
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: (slider.height - height) / 2
                width: 26
                height: 18
                radius: height / 2
                color: Glass.text
                visible: root.availableProfiles.length > 0
                border.color: slider.visualFocus ? "#70b3ff" : "#40000000"
                border.width: slider.visualFocus ? 2 : 1
            }
        }

        Row {
            width: body.width
            Repeater {
                model: root.options
                Text {
                    id: label
                    required property int index
                    required property string modelData
                    width: body.width / root.options.length
                    height: 24
                    horizontalAlignment: Text.AlignHCenter
                    text: root.labels[modelData]
                    color: modelData === root.profile ? Glass.text : Glass.secondary
                    font.family: Glass.font
                    font.pixelSize: 12
                    font.weight: modelData === root.profile ? Font.DemiBold : Font.Normal

                    TapHandler {
                        enabled: slider.enabled
                        onTapped: root.select(label.index)
                    }
                }
            }
        }

        Text {
            visible: !!root.error
            text: root.error
            color: Glass.danger
            font.family: Glass.font
            font.pixelSize: 12
        }
    }
}
