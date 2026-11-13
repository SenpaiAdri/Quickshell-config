import QtQuick
import QtQuick.Controls
import "../theme"

Column {
    id: root
    property string ssid: ""
    property int signal: 0
    property bool secured: false
    property bool active: false
    property bool connecting: false
    property bool expanded: false
    property string passwordDraft: ""
    property bool manage: false
    property bool busy: false
    signal clicked
    signal passwordEntered(password: string)
    signal passwordEdited(password: string)
    signal disconnectRequested
    width: parent ? parent.width : 300
    spacing: 4
    activeFocusOnTab: !busy
    Accessible.role: Accessible.Button
    Accessible.name: ssid + (active ? ", connected" : "")
    Keys.onReturnPressed: {
        if (!busy)
            clicked();
    }
    Keys.onSpacePressed: {
        if (!busy)
            clicked();
    }
    onExpandedChanged: {
        if (expanded)
            password.forceActiveFocus();
    }

    Rectangle {
        width: parent.width
        height: 44
        radius: 9
        color: rowMouse.containsMouse || root.activeFocus ? Glass.hover : "transparent"
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !root.busy
            onClicked: root.clicked()
        }
        Rectangle {
            id: symbol
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            radius: 15
            color: root.active ? Glass.accent : Glass.card
            WifiGlyph {
                anchors.centerIn: parent
                width: 18
                height: 17
                strength: root.signal
                ink: root.active ? "white" : Glass.text
            }
        }
        Text {
            anchors.left: symbol.right
            anchors.leftMargin: 10
            anchors.right: lock.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.ssid
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.family: Glass.font
            font.pixelSize: 13
            font.weight: root.active ? Font.DemiBold : Font.Normal
            color: Glass.text
        }
        Item {
            id: lock
            anchors.right: mark.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            height: 13
            visible: root.secured
            Rectangle {
                x: 2
                width: 6
                height: 8
                radius: 3
                color: "transparent"
                border.color: Glass.secondary
                border.width: 1.4
            }
            Rectangle {
                y: 5
                width: 10
                height: 8
                radius: 2
                color: Glass.secondary
            }
        }
        Text {
            id: mark
            width: 18
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.connecting ? "◌" : root.active ? "✓" : ""
            font.family: Glass.font
            font.pixelSize: 15
            color: Glass.text
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: root.connecting
            }
        }
    }

    Row {
        visible: root.expanded
        width: parent.width
        height: visible ? 38 : 0
        spacing: 6
        TextField {
            id: password
            width: parent.width - join.width - parent.spacing
            height: 34
            placeholderText: "Password"
            placeholderTextColor: Glass.secondary
            echoMode: TextInput.Password
            text: root.expanded ? root.passwordDraft : ""
            onTextEdited: root.passwordEdited(text)
            color: Glass.text
            font.family: Glass.font
            font.pixelSize: 12
            selectByMouse: true
            enabled: !root.busy
            background: Rectangle {
                radius: 7
                color: Glass.card
                border.color: password.activeFocus ? Glass.accent : Glass.stroke
            }
            onAccepted: join.clicked()
        }
        Button {
            id: join
            width: 54
            height: 34
            enabled: password.text.length > 0 && !root.busy
            contentItem: Text {
                text: "Join"
                color: "white"
                font.family: Glass.font
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: 7
                color: Glass.accent
                opacity: join.enabled ? 1 : 0.4
            }
            onClicked: {
                if (!enabled)
                    return;
                root.passwordEntered(password.text);
            }
        }
    }
    Button {
        id: disconnectButton
        visible: root.manage
        width: parent.width
        height: visible ? 32 : 0
        enabled: !root.busy
        contentItem: Text {
            text: "Disconnect"
            color: Glass.text
            font.family: Glass.font
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 7
            color: disconnectButton.hovered ? Glass.hover : Glass.card
        }
        onClicked: root.disconnectRequested()
    }
}
