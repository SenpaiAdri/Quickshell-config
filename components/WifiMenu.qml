pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Networking
import "../theme"

Rectangle {
    id: root
    color: Glass.panel
    radius: Glass.radius
    border.color: Glass.stroke
    border.width: 1
    clip: true
    property real progress: 0
    property bool exiting: false
    readonly property real frameW: 340
    readonly property real frameH: Math.min(480, 162 + Math.max(60, networkColumn.implicitHeight) + (status ? statusLabel.height + 7 : 0))
    readonly property var wifiDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wifi)
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool hardwareEnabled: Networking.wifiHardwareEnabled
    readonly property bool available: wifiDevices.length > 0
    readonly property bool busy: selected ? selected.stateChanging : false
    property bool failed: false
    property string message: ""
    readonly property string status: message || (!available ? "No Wi-Fi adapter found" : !hardwareEnabled ? "Wi-Fi is disabled by the hardware switch" : !wifiEnabled ? "Wi-Fi is off" : Networking.connectivity === NetworkConnectivity.Portal ? "Sign in to this network in your browser" : "")
    readonly property var networks: {
        let result = [];
        for (const device of wifiDevices)
            result = result.concat(device.networks.values);
        return result.sort((a, b) => Number(b.connected) - Number(a.connected) || Number(b.known) - Number(a.known) || b.signalStrength - a.signalStrength || a.name.localeCompare(b.name));
    }
    property var selected: null
    property var pendingNetwork: null
    // Scan updates can reorder/recreate rows while a password is being typed.
    property string passwordDraft: ""
    onPendingNetworkChanged: passwordDraft = ""
    onVisibleChanged: if (!visible) pendingNetwork = null
    property var manageNetwork: null
    property bool otherExpanded: true
    property bool scanPause: false
    signal hideRequested
    opacity: progress
    scale: 0.96 + 0.04 * progress
    transformOrigin: Item.TopRight

    function open(): void {
        exiting = false;
        pendingNetwork = null;
        manageNetwork = null;
        message = "";
        failed = false;
        closing.stop();
        opening.restart();
    }
    function close(): void {
        if (exiting)
            return;
        exiting = true;
        pendingNetwork = null;
        opening.stop();
        closing.restart();
    }
    NumberAnimation {
        id: opening
        target: root
        property: "progress"
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: closing
        target: root
        property: "progress"
        to: 0
        duration: 120
        onFinished: root.hideRequested()
    }

    function isPersonal(network): bool {
        return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].indexOf(network.security) >= 0;
    }
    function isOpen(network): bool {
        return network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe;
    }
    function join(network, password): void {
        if (busy || !wifiEnabled)
            return;
        selected = network;
        pendingNetwork = null;
        failed = false;
        message = "Joining " + network.name + "…";
        if (password)
            network.connectWithPsk(password);
        else
            network.connect();
        operationTimeout.restart();
    }
    function rowClicked(network): void {
        if (busy)
            return;
        selected = network;
        failed = false;
        message = "";
        if (network.connected) {
            manageNetwork = manageNetwork === network ? null : network;
            pendingNetwork = null;
        } else if (network.known || isOpen(network)) {
            manageNetwork = null;
            join(network, "");
        } else if (isPersonal(network)) {
            manageNetwork = null;
            pendingNetwork = pendingNetwork === network ? null : network;
        } else {
            failed = true;
            message = "Configure this network in Network Settings.";
        }
    }
    function toggleWifi(): void {
        if (!available || !hardwareEnabled)
            return;
        failed = false;
        message = "";
        pendingNetwork = null;
        manageNetwork = null;
        Networking.wifiEnabled = !wifiEnabled;
    }
    function disconnectNetwork(network): void {
        selected = network;
        manageNetwork = null;
        failed = false;
        message = "Disconnecting…";
        network.disconnect();
        operationTimeout.restart();
    }
    function openSettings(): void {
        settingsProcess.command = ["sh", "-c", "if command -v nm-connection-editor >/dev/null 2>&1; then exec nm-connection-editor; else exec kitty -e nmtui; fi"];
        settingsProcess.startDetached();
        close();
    }
    Process {
        id: settingsProcess
    }
    Connections {
        target: root.selected
        function onConnectionFailed(reason) {
            operationTimeout.stop();
            root.failed = true;
            root.message = reason === ConnectionFailReason.NoSecrets ? "A password is required. Try again." : "Could not join. Check the password or Network Settings.";
            if (root.selected && root.isPersonal(root.selected))
                root.pendingNetwork = root.selected;
        }
        function onStateChanged() {
            if (!root.selected)
                return;
            if (root.selected.state === ConnectionState.Connected) {
                operationTimeout.stop();
                root.failed = false;
                root.message = "";
            } else if (root.selected.state === ConnectionState.Disconnected && !root.failed) {
                operationTimeout.stop();
                root.message = "";
            }
        }
    }
    Timer {
        id: operationTimeout
        interval: 45000
        onTriggered: {
            root.failed = true;
            root.message = "The network request timed out. Try Network Settings.";
        }
    }
    // Native scanning follows the popup's lifetime, without background polling.
    Repeater {
        model: root.wifiDevices
        delegate: Item {
            id: scanner
            required property var modelData
            Binding {
                target: scanner.modelData
                property: "scannerEnabled"
                value: root.visible && root.progress > 0 && !root.exiting && root.wifiEnabled && !root.scanPause
            }
        }
    }
    Timer {
        id: scanRestart
        interval: 150
        onTriggered: root.scanPause = false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }
    Column {
        id: contents
        anchors.fill: parent
        anchors.margins: 12
        spacing: 7
        Item {
            width: parent.width
            height: 38
            Text {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "Wi-Fi"
                color: Glass.text
                font.family: Glass.font
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Rectangle {
                id: wifiSwitch
                activeFocusOnTab: root.available && root.hardwareEnabled
                Accessible.role: Accessible.CheckBox
                Accessible.name: "Wi-Fi"
                Accessible.checked: root.wifiEnabled
                Accessible.onToggleAction: root.toggleWifi()
                Keys.onSpacePressed: root.toggleWifi()
                Keys.onReturnPressed: root.toggleWifi()
                border.width: activeFocus ? 1 : 0
                border.color: Glass.text
                anchors.right: parent.right
                anchors.rightMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 23
                radius: 12
                color: root.wifiEnabled ? Glass.accent : Glass.hover
                opacity: !root.hardwareEnabled || !root.available ? 0.5 : 1
                Rectangle {
                    y: 2
                    x: root.wifiEnabled ? 17 : 2
                    width: 19
                    height: 19
                    radius: 10
                    color: "white"
                    Behavior on x {
                        NumberAnimation {
                            duration: 130
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.hardwareEnabled && root.available
                    onClicked: root.toggleWifi()
                }
            }
        }
        Rectangle {
            width: parent.width
            height: 1
            color: Glass.stroke
        }
        Text {
            id: statusLabel
            width: parent.width - 16
            x: 8
            visible: root.status !== ""
            text: root.status
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: root.failed ? Glass.danger : Glass.secondary
            font.family: Glass.font
            font.pixelSize: 11
        }
        Flickable {
            id: scroll
            width: parent.width
            height: Math.max(60, contents.height - 38 - footer.height - 29 - (root.status ? statusLabel.height + 7 : 0))
            contentHeight: networkColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            Column {
                id: networkColumn
                width: scroll.width
                spacing: 3
                Text {
                    x: 8
                    height: 28
                    visible: root.wifiEnabled && root.networks.some(n => n.known)
                    text: "Known Networks"
                    color: Glass.secondary
                    font.family: Glass.font
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    verticalAlignment: Text.AlignVCenter
                }
                Repeater {
                    model: root.wifiEnabled ? root.networks.filter(n => n.known) : []
                    delegate: WifiRow {
                        required property var modelData
                        ssid: modelData.name
                        signal: Math.round(modelData.signalStrength * 100)
                        secured: !root.isOpen(modelData)
                        active: modelData.connected
                        connecting: modelData.state === ConnectionState.Connecting
                        expanded: root.pendingNetwork === modelData
                        passwordDraft: expanded ? root.passwordDraft : ""
                        manage: root.manageNetwork === modelData
                        busy: root.busy
                        onClicked: root.rowClicked(modelData)
                        onPasswordEntered: password => root.join(modelData, password)
                        onPasswordEdited: password => root.passwordDraft = password
                        onDisconnectRequested: root.disconnectNetwork(modelData)
                    }
                }
                Item {
                    width: parent.width
                    height: root.wifiEnabled ? 31 : 0
                    visible: root.wifiEnabled
                    Text {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Other Networks"
                        color: Glass.secondary
                        font.family: Glass.font
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.otherExpanded ? "⌃" : "⌄"
                        color: Glass.secondary
                        font.pixelSize: 15
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.otherExpanded = !root.otherExpanded
                    }
                }
                Repeater {
                    model: root.wifiEnabled && root.otherExpanded ? root.networks.filter(n => !n.known) : []
                    delegate: WifiRow {
                        required property var modelData
                        ssid: modelData.name
                        signal: Math.round(modelData.signalStrength * 100)
                        secured: !root.isOpen(modelData)
                        active: modelData.connected
                        connecting: modelData.state === ConnectionState.Connecting
                        expanded: root.pendingNetwork === modelData
                        passwordDraft: expanded ? root.passwordDraft : ""
                        manage: root.manageNetwork === modelData
                        busy: root.busy
                        onClicked: root.rowClicked(modelData)
                        onPasswordEntered: password => root.join(modelData, password)
                        onPasswordEdited: password => root.passwordDraft = password
                        onDisconnectRequested: root.disconnectNetwork(modelData)
                    }
                }
                Text {
                    x: 8
                    visible: root.wifiEnabled && !root.networks.length && !root.busy
                    text: "No networks found"
                    color: Glass.secondary
                    font.family: Glass.font
                    font.pixelSize: 12
                    height: 35
                }
            }
        }
        Column {
            id: footer
            width: parent.width
            spacing: 3
            Rectangle {
                width: parent.width
                height: 1
                color: Glass.stroke
            }
            Row {
                width: parent.width
                height: 31
                spacing: 2
                Button {
                    id: scanButton
                    width: 100
                    height: 30
                    enabled: root.wifiEnabled && !root.busy
                    contentItem: Text {
                        text: "Scan Again"
                        color: Glass.secondary
                        font.family: Glass.font
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 7
                        color: scanButton.hovered ? Glass.hover : "transparent"
                    }
                    onClicked: {
                        root.scanPause = true;
                        scanRestart.restart();
                    }
                }
                Button {
                    id: otherButton
                    width: parent.width - 102
                    height: 30
                    enabled: root.wifiEnabled && !root.busy
                    contentItem: Text {
                        text: "Join Other Network…"
                        color: Glass.secondary
                        font.family: Glass.font
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 7
                        color: otherButton.hovered ? Glass.hover : "transparent"
                    }
                    onClicked: root.openSettings()
                }
            }
            Button {
                id: settingsButton
                width: parent.width
                height: 33
                contentItem: Text {
                    text: "Network Settings…"
                    color: Glass.text
                    font.family: Glass.font
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 8
                }
                background: Rectangle {
                    radius: 7
                    color: settingsButton.hovered ? Glass.hover : "transparent"
                }
                onClicked: root.openSettings()
            }
        }
    }
}
