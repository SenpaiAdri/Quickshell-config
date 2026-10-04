// Power menu: centered icon grid (wlogout replacement).
// Exposes open() so the shell can reset + focus on show; emits hideRequested on dismiss/run.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import "../theme"

Rectangle {
    id: root
    color: Theme.powerBg
    radius: Theme.powerRadius
    border.color: Theme.powerBorder
    border.width: 1

    signal hideRequested()

    property int selected: 0
    // Confirmation state: pendingKey arms logout/reboot/shutdown.
    // collapsed flips after the fade-out so the card springs shut
    // around the single tile (Dynamic-Island-style morph).
    property string pendingKey: ""
    property bool collapsed: false
    readonly property bool confirming: root.pendingKey !== ""
    // Full-grid width, so tiles can be positioned manually (needed to glide
    // the armed tile to center instead of teleporting when the Row collapses).
    readonly property real gridW: actions.count * Theme.powerTileW + (actions.count - 1) * Theme.powerSpacing

    // Neutral highlight for all tiles; Shutdown keeps its red danger accent.
    ListModel {
        id: actions
        ListElement {
            key: "lock"
            label: "Lock"
            icon: ""
        }
        ListElement {
            key: "logout"
            label: "Logout"
            icon: ""
        }
        ListElement {
            key: "suspend"
            label: "Suspend"
            icon: ""
        }
        ListElement {
            key: "reboot"
            label: "Reboot"
            icon: ""
        }
        ListElement {
            key: "shutdown"
            label: "Shutdown"
            icon: ""
        }
    }

    function open(): void {
        collapseTimer.stop();
        root.pendingKey = "";
        root.collapsed = false;
        root.selected = 0;
        root.forceActiveFocus();
    }

    function cancel(): void {
        collapseTimer.stop();
        root.collapsed = false;
        root.pendingKey = "";
    }

    Timer {
        id: collapseTimer
        interval: 150
        repeat: false
        onTriggered: root.collapsed = true
    }

    function run(key: string): void {
        if (key === "lock")
            Quickshell.execDetached(["hyprlock"]);
        else if (key === "logout")
            Quickshell.execDetached(["hyprctl", "dispatch", "exit"]);
        else if (key === "suspend")
            Quickshell.execDetached(["bash", "-c", "hyprlock & sleep 0.5 && systemctl suspend"]);
        else if (key === "reboot")
            Quickshell.execDetached(["systemctl", "reboot"]);
        else if (key === "shutdown")
            Quickshell.execDetached(["systemctl", "poweroff"]);
        else
            return;
        root.hideRequested();
    }

    // Lock/Suspend run instantly; logout/reboot/shutdown arm a confirmation.
    function choose(index: int): void {
        if (index < 0 || index >= actions.count)
            return;
        var key = actions.get(index).key;
        if (root.confirming) {
            if (key === root.pendingKey)
                root.run(key);
            return;
        }
        root.selected = index;
        if (key === "logout" || key === "reboot" || key === "shutdown") {
            root.pendingKey = key;
            collapseTimer.restart();
        } else {
            root.run(key);
        }
    }

    function move(d: int): void {
        if (actions.count === 0)
            return;
        var n = (root.selected + d) % actions.count;
        if (n < 0)
            n += actions.count;
        root.selected = n;
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (root.confirming)
                root.cancel();
            else
                root.hideRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            if (root.confirming)
                root.cancel();
            else
                root.move(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            if (root.confirming)
                root.cancel();
            else
                root.move(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.choose(root.selected);
            event.accepted = true;
        }
    }

    Item {
        id: tileLayer
        anchors.fill: parent

        Repeater {
            model: actions
            delegate: Rectangle {
                id: tile
                required property string key
                required property string label
                required property string icon
                required property int index

                readonly property bool isSelected: tile.index === root.selected
                readonly property bool isDanger: tile.key === "shutdown"
                readonly property bool isArmed: tile.key === root.pendingKey
                // Grid slot normally; card center when armed. Both destinations
                // are constants (full/confirm widths) so the spring never
                // chases a moving target mid-flight — that chase is what made
                // the tile wait outside until the card settled.
                readonly property real targetX: root.collapsed ? Theme.powerPadding : (Theme.powerWidth - root.gridW) / 2 + tile.index * (Theme.powerTileW + Theme.powerSpacing)

                x: tile.targetX
                anchors.verticalCenter: parent.verticalCenter

                // Same physics as the card width spring so tile and card
                // morph in lockstep instead of one finishing before the other.
                Behavior on x {
                    SpringAnimation {
                        spring: 3.5
                        damping: 0.3
                    }
                }

                width: Theme.powerTileW
                height: Theme.powerTileH
                radius: 14
                color: isSelected ? Theme.powerTileSelected : Theme.powerTileBg
                border.color: isSelected ? (tile.isDanger ? Theme.powerDanger : Theme.powerTileBorder) : Theme.powerTileBorder
                border.width: isSelected ? 2 : 1

                // Confirm morph: bystanders fade out, then collapse out of
                // layout; the armed tile pops slightly while the card springs.
                visible: !root.collapsed || tile.isArmed
                opacity: (!root.confirming || tile.isArmed) ? 1 : 0
                scale: (root.confirming && tile.isArmed) ? 1.05 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selected = tile.index
                    onClicked: root.choose(tile.index)
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.icon
                        color: tile.isDanger ? Theme.powerDanger : Theme.powerText
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.powerIconSize
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.label
                        color: Theme.powerText
                        font.family: Theme.powerFont
                        font.pixelSize: Theme.powerLabelSize
                        font.bold: tile.isSelected
                    }
                }
            }
        }
    }
}
