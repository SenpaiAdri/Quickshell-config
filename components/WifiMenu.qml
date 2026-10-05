// Wi-Fi menu panel: toggle, live network list (nmcli), inline password connect.
// Lives in a fullscreen transparent PanelWindow (see shell.qml wifiWin).
// open() runs one continuous dot→card morph; close() shrinks it back and
// emits hideRequested so the shell can hide the window.
import QtQuick
import Quickshell.Io

import "../theme"

Rectangle {
    id: root
    color: Theme.wifiBg
    // Single continuous morph, same language as the island/center: every
    // dimension is a function of `progress` (0 dot → 1 full card), driven
    // by exactly one animation. Radius blends from a perfect circle into
    // the card corner — no staged retargets.
    radius: (1 - root.progress) * Math.min(root.width, root.height) / 2 + root.progress * Theme.wifiRadius
    border.color: Theme.wifiBorder
    border.width: 1
    clip: true

    property bool wifiEnabled: true
    property bool busy: false
    property string status: ""
    property string pendingSsid: ""
    property string manageSsid: ""
    property bool hiddenExpanded: false
    property string connectingSsid: ""
    property var known: ({})

    // Footer stack heights: rescan (40) + hidden button (40) + optional
    // hidden panel (144). The extra 4s are the column gaps; the trailing
    // -16 in the list height keeps slack so the fixed window never clips.
    property int footerH: 40 + 4 + 40 + (hiddenExpanded ? 4 + 144 : 0)

    // 0 = dot, 1 = full card. Animated once per open (OutExpo: fast
    // expansion, soft landing — the Dynamic Island feel).
    property real progress: 0
    property bool exiting: false

    readonly property real frameW: Theme.wifiDot + (Theme.wifiWidth - Theme.wifiDot) * root.progress
    readonly property real frameH: Theme.wifiDot + (Theme.wifiHeight - Theme.wifiDot) * root.progress
    // Contents fade in over the final stretch of the morph only.
    readonly property real contentOpacity: Math.min(1, Math.max(0, (root.progress - 0.8) / 0.2))

    signal hideRequested()

    function open(): void {
        morphOut.stop();
        root.exiting = false;
        refresh();
        morphIn.start();
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

    // Swallow clicks on the card so the fullscreen backdrop behind it
    // (which dismisses on outside-click) never fires from inside.
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
            color: Theme.wifiAccent

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

    ListModel {
        id: networks
    }

    function setStatus(s: string): void {
        root.status = s;
    }

    // ---- nmcli runners ----
    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: parseList(text)
        }
    }
    Process {
        id: knownProc
        stdout: StdioCollector {
            onStreamFinished: {
                var k = {};
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var n = lines[i].trim();
                    if (n !== "")
                        k[n] = true;
                }
                root.known = k;
            }
        }
    }
    Process {
        id: stateProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.trim() === "enabled";
                if (!root.wifiEnabled) {
                    networks.clear();
                    setStatus("Wi-Fi is off");
                }
            }
        }
    }
    Process {
        id: actionProc
        property string action: ""
        property string actionSsid: ""
        stdout: StdioCollector {
            id: actionOut
        }
        stderr: StdioCollector {
            id: actionErr
        }
        onExited: {
            if (actionProc.action === "connect") {
                if (exitCode === 0) {
                    setStatus("Connected to " + actionProc.actionSsid);
                    root.pendingSsid = "";
                    refreshSoon.restart();
                    hideSoon.restart();
                } else {
                    var err = actionErr.text.trim().split("\n").pop() || "Connection failed";
                    setStatus(err.length > 60 ? err.slice(0, 60) + "…" : err);
                }
                root.connectingSsid = "";
                root.busy = false;
            } else if (actionProc.action === "toggle") {
                refresh();
            } else if (actionProc.action === "disconnect") {
                root.busy = false;
                if (exitCode === 0) {
                    root.manageSsid = "";
                    setStatus("Disconnected");
                    refreshSoon.restart();
                } else {
                    var derr = actionErr.text.trim().split("\n").pop() || "Disconnect failed";
                    setStatus(derr.length > 60 ? derr.slice(0, 60) + "…" : derr);
                }
            }
        }
    }
    // Resolves the active Wi-Fi connection's UUID so doDisconnect()
    // targets exactly this machine's wireless uplink (iface name varies).
    Process {
        id: activeProc
        stdout: StdioCollector {
            onStreamFinished: {
                var uuid = "";
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(":");
                    if (parts.length >= 2 && parts[1] === "802-11-wireless" && parts[0] !== "") {
                        uuid = parts[0];
                        break;
                    }
                }
                if (uuid === "") {
                    root.busy = false;
                    setStatus("Not connected");
                } else {
                    actionProc.action = "disconnect";
                    actionProc.exec(["nmcli", "con", "down", "uuid", uuid]);
                }
            }
        }
    }

    Timer {
        id: refreshSoon
        interval: 1500
        onTriggered: refresh()
    }
    Timer {
        id: hideSoon
        interval: 1800
        onTriggered: root.close()
    }
    Timer {
        id: rescanWait
        interval: 4000
        onTriggered: {
            listProc.exec(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]);
            root.busy = false;
            setStatus("");
        }
    }

    // ---- public ops ----
    function refresh(): void {
        // Menus open in a clean state (matches GNOME/Windows panels).
        root.pendingSsid = "";
        root.manageSsid = "";
        root.hiddenExpanded = false;
        root.busy = true;
        setStatus("Scanning…");
        stateProc.exec(["nmcli", "-t", "-f", "WIFI", "g"]);
        knownProc.exec(["nmcli", "-t", "-f", "NAME", "connection", "show"]);
        listProc.exec(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]);
    }

    function rescan(): void {
        if (root.busy)
            return;
        // A fresh scan rebuilds the list (wiping delegates), so collapse
        // any inline prompt rather than silently dropping typed input.
        root.pendingSsid = "";
        root.manageSsid = "";
        setStatus("Scanning…");
        root.busy = true;
        actionProc.action = "rescan";
        actionProc.exec(["nmcli", "dev", "wifi", "rescan"]);
        rescanWait.restart();
    }

    function toggleWifi(): void {
        actionProc.action = "toggle";
        root.busy = true;
        setStatus(root.wifiEnabled ? "Turning Wi-Fi off…" : "Turning Wi-Fi on…");
        actionProc.exec(["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"]);
    }

    function rowClicked(ssid: string, secured: bool, active: bool): void {
        if (root.connectingSsid !== "" || !root.wifiEnabled)
            return;
        if (active) {
            // Connected row expands a Disconnect panel (GNOME/Windows parity),
            // never a redundant reconnect.
            root.manageSsid = (root.manageSsid === ssid) ? "" : ssid;
            root.pendingSsid = "";
            return;
        }
        root.manageSsid = "";
        if (root.known[ssid] || !secured) {
            doConnect(ssid, "");
        } else {
            root.pendingSsid = (root.pendingSsid === ssid) ? "" : ssid;
        }
    }

    function doDisconnect(): void {
        root.manageSsid = "";
        root.busy = true;
        setStatus("Disconnecting…");
        activeProc.exec(["nmcli", "-t", "-f", "UUID,TYPE", "con", "show", "--active"]);
    }

    function doConnectHidden(ssid: string, password: string): void {
        var name = ssid.trim();
        if (name === "" || root.connectingSsid !== "")
            return;
        root.hiddenExpanded = false;
        hiddenSsidInput.text = "";
        hiddenPwInput.text = "";
        root.pendingSsid = "";
        root.manageSsid = "";
        root.connectingSsid = name;
        root.busy = true;
        setStatus("Connecting to " + name + "…");
        actionProc.action = "connect";
        actionProc.actionSsid = name;
        var cmd = ["nmcli", "-w", "15", "dev", "wifi", "connect", name];
        if (password !== "")
            cmd = cmd.concat(["password", password]);
        cmd = cmd.concat(["hidden", "yes"]);
        actionProc.exec(cmd);
    }

    function doConnect(ssid: string, password: string): void {
        root.connectingSsid = ssid;
        root.pendingSsid = "";
        root.busy = true;
        setStatus("Connecting to " + ssid + "…");
        actionProc.action = "connect";
        actionProc.actionSsid = ssid;
        var cmd = ["nmcli", "-w", "15", "dev", "wifi", "connect", ssid];
        if (password !== "")
            cmd = cmd.concat(["password", password]);
        actionProc.exec(cmd);
    }

    // ---- parsing: IN-USE:SSID:SIGNAL:SECURITY (SSID may contain colons) ----
    function parseList(text: string): void {
        var bySsid = {};
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (line.trim() === "")
                continue;
            var parts = line.split(":");
            if (parts.length < 4)
                continue;
            var inUse = parts[0] === "*";
            var security = parts[parts.length - 1];
            var signal = parseInt(parts[parts.length - 2], 10);
            var ssid = parts.slice(1, parts.length - 2).join(":");
            if (ssid === "" || isNaN(signal))
                continue;
            if (!(ssid in bySsid) || signal > bySsid[ssid].signal || inUse)
                bySsid[ssid] = {
                    ssid: ssid,
                    signal: signal,
                    secured: security !== "" && security !== "--",
                    active: inUse
                };
            if (inUse)
                bySsid[ssid].active = true;
        }
        var arr = [];
        for (var k in bySsid)
            arr.push(bySsid[k]);
        arr.sort(function(a, b) {
            if (a.active !== b.active)
                return a.active ? -1 : 1;
            return b.signal - a.signal;
        });
        networks.clear();
        for (var j = 0; j < arr.length; j++)
            networks.append(arr[j]);
        // Collapse inline panels whose network vanished from the scan so a
        // stale prompt can never target a network that is no longer there.
        if (root.pendingSsid !== "" && !(root.pendingSsid in bySsid))
            root.pendingSsid = "";
        if (root.manageSsid !== "" && (!(root.manageSsid in bySsid) || !bySsid[root.manageSsid].active))
            root.manageSsid = "";
        root.busy = false;
        if (arr.length === 0 && root.wifiEnabled)
            setStatus("No networks found");
        else if (root.connectingSsid === "" && root.status !== "Wi-Fi is off")
            setStatus("");
    }

    // ---- layout ----
    Column {
        anchors.fill: parent
        anchors.margins: Theme.wifiPadding
        spacing: 4
        opacity: root.contentOpacity
        enabled: root.progress > 0.85
        visible: opacity > 0

        // Header: title + status + toggle + close
        Item {
            width: parent.width
            height: Theme.wifiHeaderHeight
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "Wi-Fi"
                color: Theme.wifiText
                font.family: Theme.wifiFont
                font.pixelSize: Theme.wifiTitleSize
                font.bold: true
            }
            // Toggle pill
            Rectangle {
                id: togglePill
                anchors.right: closeBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 24
                radius: 12
                color: root.wifiEnabled ? "#3a8cff" : "#33ffffff"
                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.wifiEnabled ? parent.width - width - 3 : 3
                    Behavior on x {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.toggleWifi()
                }
            }
            Text {
                id: closeBtn
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                color: Theme.wifiDim
                font.family: Theme.wifiFont
                font.pixelSize: 14
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    onClicked: root.close()
                }
            }
        }

        Text {
            width: parent.width
            height: 20
            visible: root.status !== ""
            text: root.status
            elide: Text.ElideRight
            color: Theme.wifiDim
            font.family: Theme.wifiFont
            font.pixelSize: Theme.wifiSmallSize
        }

        ListView {
            id: netList
            width: parent.width
            height: parent.height - Theme.wifiHeaderHeight - (root.status !== "" ? 24 : 4) - root.footerH - 16
            clip: true
            spacing: 2
            model: networks
            delegate: WifiRow {
                ssid: model.ssid
                signal: model.signal
                secured: model.secured
                active: model.active
                connecting: model.ssid === root.connectingSsid
                expanded: model.ssid === root.pendingSsid
                manage: model.ssid === root.manageSsid
                onClicked: root.rowClicked(model.ssid, model.secured, model.active)
                onPasswordEntered: function(pw) {
                    root.doConnect(model.ssid, pw);
                }
                onDisconnectRequested: root.doDisconnect()
            }
        }

        // Footer: rescan
        Rectangle {
            width: parent.width
            height: 40
            radius: Theme.wifiRowRadius
            color: rescanMouse.containsMouse ? Theme.wifiRowHover : "transparent"
            Text {
                anchors.centerIn: parent
                text: root.busy ? "Scanning…" : "⟳  Rescan"
                color: Theme.wifiDim
                font.family: Theme.wifiFont
                font.pixelSize: Theme.wifiBodySize
            }
            MouseArea {
                id: rescanMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.rescan()
            }
        }

        // Footer: join hidden network (SSID broadcast disabled)
        Rectangle {
            width: parent.width
            height: 40
            radius: Theme.wifiRowRadius
            color: hiddenMouse.containsMouse ? Theme.wifiRowHover : "transparent"
            Text {
                anchors.centerIn: parent
                text: (root.hiddenExpanded ? "▾  " : "＋  ") + "Join hidden network…"
                color: Theme.wifiDim
                font.family: Theme.wifiFont
                font.pixelSize: Theme.wifiBodySize
            }
            MouseArea {
                id: hiddenMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    root.hiddenExpanded = !root.hiddenExpanded;
                    root.pendingSsid = "";
                    root.manageSsid = "";
                    if (root.hiddenExpanded)
                        hiddenSsidInput.forceActiveFocus();
                }
            }
        }

        // Hidden-network form: SSID + optional password + Join.
        // Fixed height math (44 + 44 + 40 + 2×8 spacing = 144) must match
        // footerH above so the list shrinks instead of overflowing.
        Column {
            visible: root.hiddenExpanded
            width: parent.width
            height: root.hiddenExpanded ? 144 : 0
            spacing: 8

            Rectangle {
                width: parent.width
                height: 44
                radius: Theme.wifiRowRadius
                color: "#0dffffff"
                border.color: "#33ffffff"
                border.width: 1
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: hiddenSsidInput.text === ""
                    text: "Network name (SSID)…"
                    color: "#66ffffff"
                    font.family: Theme.wifiFont
                    font.pixelSize: Theme.wifiSmallSize
                }
                TextInput {
                    id: hiddenSsidInput
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.wifiText
                    selectionColor: "#66ffffff"
                    font.family: Theme.wifiFont
                    font.pixelSize: Theme.wifiBodySize
                    maximumLength: 32
                    onAccepted: hiddenPwInput.forceActiveFocus()
                }
            }

            Rectangle {
                width: parent.width
                height: 44
                radius: Theme.wifiRowRadius
                color: "#0dffffff"
                border.color: "#33ffffff"
                border.width: 1
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: hiddenPwInput.text === ""
                    text: "Password (leave empty if open)…"
                    color: "#66ffffff"
                    font.family: Theme.wifiFont
                    font.pixelSize: Theme.wifiSmallSize
                }
                TextInput {
                    id: hiddenPwInput
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
                    onAccepted: root.doConnectHidden(hiddenSsidInput.text, hiddenPwInput.text)
                }
            }

            Rectangle {
                width: parent.width
                height: 40
                radius: Theme.wifiRowRadius
                color: joinMouse.containsMouse ? Theme.wifiRowHover : "#0dffffff"
                border.color: "#33ffffff"
                border.width: 1
                opacity: hiddenSsidInput.text.trim() === "" ? 0.5 : 1
                Text {
                    anchors.centerIn: parent
                    text: "Join"
                    color: Theme.wifiText
                    font.family: Theme.wifiFont
                    font.pixelSize: Theme.wifiBodySize
                    font.bold: true
                }
                MouseArea {
                    id: joinMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.doConnectHidden(hiddenSsidInput.text, hiddenPwInput.text)
                }
            }
        }
    }
}
