// One wifi network row: signal bars, SSID, lock/check, optional password box.
// Pure view — parent wires clicked() / passwordEntered().
import QtQuick

import "../theme"

Column {
    id: root
    property string ssid: ""
    property int signal: 0
    property bool secured: false
    property bool active: false
    property bool connecting: false
    property bool expanded: false

    signal clicked()
    signal passwordEntered(password: string)

    width: parent.width

    Rectangle {
        width: parent.width
        height: Theme.wifiRowHeight
        radius: Theme.wifiRowRadius
        color: rowMouse.containsMouse ? Theme.wifiRowHover : "transparent"

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.clicked()
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            // Signal bars (custom drawn — no icon font needed)
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 14
                Row {
                    anchors.bottom: parent.bottom
                    spacing: 2
                    Repeater {
                        model: [5, 8, 11, 14]
                        Rectangle {
                            width: 3
                            height: modelData
                            radius: 1.5
                            anchors.bottom: parent.bottom
                            color: {
                                var on = [20, 45, 70, 90];
                                return root.signal >= on[index] ? (root.active ? Theme.wifiAccent : Theme.wifiDim) : "#33ffffff";
                            }
                        }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 18 - 12 - 20 - 24
                text: root.connecting ? "Connecting…" : root.ssid
                elide: Text.ElideRight
                color: root.active ? Theme.wifiAccent : Theme.wifiText
                font.family: Theme.wifiFont
                font.pixelSize: Theme.wifiBodySize
                font.bold: root.active
            }

            // Lock (drawn) or connected check
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 16
                Text {
                    anchors.centerIn: parent
                    visible: root.active
                    text: "✓"
                    color: Theme.wifiAccent
                    font.family: Theme.wifiFont
                    font.pixelSize: 14
                    font.bold: true
                }
                Item {
                    anchors.centerIn: parent
                    visible: !root.active && root.secured
                    width: 14
                    height: 15
                    Rectangle {
                        x: 3
                        width: 8
                        height: 8
                        radius: 4
                        color: "transparent"
                        border.color: Theme.wifiDim
                        border.width: 2
                    }
                    Rectangle {
                        y: 6
                        width: 14
                        height: 9
                        radius: 2.5
                        color: Theme.wifiDim
                    }
                }
            }
        }
    }

    // Inline password prompt
    Rectangle {
        visible: root.expanded
        width: parent.width
        height: root.expanded ? 44 : 0
        radius: Theme.wifiRowRadius
        color: "#0dffffff"
        border.color: "#33ffffff"
        border.width: 1

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: pwdInput.text === ""
            text: "Password…"
            color: "#66ffffff"
            font.family: Theme.wifiFont
            font.pixelSize: Theme.wifiSmallSize
        }

        TextInput {
            id: pwdInput
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.wifiText
            selectionColor: "#66ffffff"
            font.family: Theme.wifiFont
            font.pixelSize: Theme.wifiBodySize
            echoMode: TextInput.Password
            onAccepted: {
                root.passwordEntered(pwdInput.text);
                pwdInput.text = "";
            }
            onVisibleChanged: {
                if (visible)
                    forceActiveFocus();
            }
        }
    }
}
