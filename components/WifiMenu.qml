// Wi-Fi menu panel: toggle, live network list (nmcli), inline password connect.
// Exposes refresh() so the shell can reload on open; emits hideRequested on success.
import QtQuick
import Quickshell.Io

import "../theme"

Rectangle {
    id: root
    color: Theme.wifiBg
    radius: Theme.wifiRadius
    border.color: Theme.wifiBorder
    border.width: 1

    property bool wifiEnabled: true
    property bool busy: false
    property string status: ""
    property string pendingSsid: ""
    property string connectingSsid: ""
    property var known: ({})

    signal hideRequested()

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
            if (root.action === "connect") {
                if (exitCode === 0) {
                    setStatus("Connected to " + root.actionSsid);
                    root.pendingSsid = "";
                    refreshSoon.restart();
                    hideSoon.restart();
                } else {
                    var err = actionErr.text.trim().split("\n").pop() || "Connection failed";
                    setStatus(err.length > 60 ? err.slice(0, 60) + "…" : err);
                }
                root.connectingSsid = "";
                root.busy = false;
            } else if (root.action === "toggle") {
                refresh();
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
        onTriggered: root.hideRequested()
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
        root.busy = true;
        setStatus("Scanning…");
        stateProc.exec(["nmcli", "-t", "-f", "WIFI", "g"]);
        knownProc.exec(["nmcli", "-t", "-f", "NAME", "connection", "show"]);
        listProc.exec(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]);
    }

    function rescan(): void {
        setStatus("Scanning…");
        root.busy = true;
        actionProc.action = "rescan";
        actionProc.exec(["nmcli", "dev", "wifi", "rescan"]);
        rescanWait.restart();
    }

    function toggleWifi(): void {
        actionProc.action = "toggle";
        actionProc.exec(["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"]);
    }

    function rowClicked(ssid: string, secured: bool): void {
        if (root.connectingSsid !== "" || !root.wifiEnabled)
            return;
        if (root.known[ssid] || !secured) {
            doConnect(ssid, "");
        } else {
            root.pendingSsid = (root.pendingSsid === ssid) ? "" : ssid;
        }
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
        root.busy = false;
        if (arr.length === 0 && root.wifiEnabled)
            setStatus("No networks found");
        else if (root.connectingSsid === "")
            setStatus("");
    }

    // ---- layout ----
    Column {
        anchors.fill: parent
        anchors.margins: Theme.wifiPadding
        spacing: 4

        // Header: title + status + toggle + close
        Item {
            width: parent.width - Theme.wifiPadding * 2
            height: Theme.wifiHeaderHeight
            Text {
                anchors.left: parent.left
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
                anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                color: Theme.wifiDim
                font.family: Theme.wifiFont
                font.pixelSize: 14
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    onClicked: root.hideRequested()
                }
            }
        }

        Text {
            width: parent.width - Theme.wifiPadding * 2
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
            width: parent.width - Theme.wifiPadding * 2
            height: parent.height - Theme.wifiHeaderHeight - (root.status !== "" ? 24 : 4) - Theme.wifiFooterHeight - 12
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
                onClicked: root.rowClicked(model.ssid, model.secured)
                onPasswordEntered: function(pw) {
                    root.doConnect(model.ssid, pw);
                }
            }
        }

        // Footer: rescan
        Rectangle {
            width: parent.width - Theme.wifiPadding * 2
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
    }
}
