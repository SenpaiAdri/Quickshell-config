// Shell entry — OSD toast + Wi-Fi menu.
// Triggered via: quickshell ipc call osd popup <...> | quickshell ipc call wifi toggle
// Window chrome + IPC live here; visuals live in components/ (tuned via theme/).
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

import "components"
import "theme"

ShellRoot {
    PanelWindow {
        id: osd
        anchors {
            bottom: true
        }
        margins {
            bottom: Theme.bottomMargin
        }
        // Explicit window size — content-implicit sizing is unreliable here.
        implicitWidth: Theme.windowWidth
        implicitHeight: Theme.windowHeight
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: false
        visible: false
        color: "transparent"

        // Clicks pass through everywhere except the pill itself.
        mask: Region {
            item: pill
        }

        property string kind: "volume"
        property int level: 0
        property bool muted: false

        Timer {
            id: hideTimer
            interval: Theme.hideAfterMs
            repeat: false
            onTriggered: osd.visible = false
        }

        function showOsd(k: string, v: int, m: bool): void {
            osd.kind = k;
            osd.level = Math.max(0, Math.min(100, v));
            osd.muted = m;
            osd.visible = true;
            hideTimer.restart();
        }

        IpcHandler {
            target: "osd"
            function popup(kind: string, level: int, muted: bool): void {
                osd.showOsd(kind, level, muted);
            }
        }

        OsdPill {
            id: pill
            kind: osd.kind
            level: osd.level
            muted: osd.muted
        }
    }

    PanelWindow {
        id: wifiWin
        anchors {
            top: true
            right: true
        }
        margins {
            top: Theme.wifiTopMargin
            right: Theme.wifiRightMargin
        }
        implicitWidth: Theme.wifiWidth
        implicitHeight: Theme.wifiHeight
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: true
        visible: false
        color: "transparent"

        // On-demand keyboard focus: keys work once the menu is clicked;
        // (Exclusive broke outside-click dismissal, so it stays off.)
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Keys.onEscapePressed: wifiWin.visible = false

        // Modal popup behavior: keep keyboard focus while open (Esc + typing
        // work immediately), auto-dismiss when anything outside is clicked.
        HyprlandFocusGrab {
            id: grab
            windows: [wifiWin]
            active: wifiWin.visible
            onCleared: wifiWin.visible = false
        }

        IpcHandler {
            target: "wifi"
            function toggle(): void {
                wifiWin.visible = !wifiWin.visible;
                if (wifiWin.visible)
                    wifiMenu.refresh();
            }
            function show(): void {
                wifiWin.visible = true;
                wifiMenu.refresh();
            }
            function hide(): void {
                wifiWin.visible = false;
            }
        }

        WifiMenu {
            id: wifiMenu
            anchors.fill: parent
            onHideRequested: wifiWin.visible = false
        }
    }

    PanelWindow {
        id: wallWin
        anchors {
            bottom: true
        }
        margins {
            bottom: Theme.wallBottomMargin
        }
        implicitWidth: Theme.wallWidth
        implicitHeight: Theme.wallHeight
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: true
        visible: false
        color: "transparent"

        // On-demand keyboard focus: keys work once the menu is clicked;
        // (Exclusive broke outside-click dismissal, so it stays off.)
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        // Modal popup behavior: keep keyboard focus while open (Esc + typing
        // work immediately), auto-dismiss when anything outside is clicked.
        HyprlandFocusGrab {
            windows: [wallWin]
            active: wallWin.visible
            onCleared: wallWin.visible = false
        }

        IpcHandler {
            target: "wallpaper"
            function toggle(): void {
                wallWin.visible = !wallWin.visible;
                if (wallWin.visible)
                    wallMenu.open();
            }
            function show(): void {
                wallWin.visible = true;
                wallMenu.open();
            }
            function open(): void {
                wallWin.visible = true;
                wallMenu.open();
            }
            function hide(): void {
                wallWin.visible = false;
            }
        }

        WallpaperPicker {
            id: wallMenu
            anchors.fill: parent
            onHideRequested: wallWin.visible = false
        }
    }

    PanelWindow {
        id: launcherWin
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: true
        visible: false
        color: "transparent"

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        HyprlandFocusGrab {
            windows: [launcherWin]
            active: launcherWin.visible
            onCleared: launcherWin.visible = false
        }

        IpcHandler {
            target: "launcher"
            function toggle(): void {
                launcherWin.visible = !launcherWin.visible;
                if (launcherWin.visible)
                    launcher.open();
            }
            function show(): void {
                launcherWin.visible = true;
                launcher.open();
            }
            function open(): void {
                launcherWin.visible = true;
                launcher.open();
            }
            function hide(): void {
                launcherWin.visible = false;
            }
        }

        // Dim backdrop — click outside to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: launcherWin.visible = false
        }

        AppLauncher {
            id: launcher
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.launcherTopMargin
            width: Theme.launcherWidth
            // Height grows with results (search + up to 8 rows), capped
            height: Theme.launcherPadding * 2 + 48 + 8 + Math.min(8, Math.max(1, launcher.resultCount)) * (Theme.launcherRowHeight + 2) + 8
            onHideRequested: launcherWin.visible = false
        }
    }

    PanelWindow {
        id: powerWin
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: true
        visible: false
        color: "transparent"

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        HyprlandFocusGrab {
            windows: [powerWin]
            active: powerWin.visible
            onCleared: powerWin.visible = false
        }

        IpcHandler {
            target: "powermenu"
            function toggle(): void {
                powerWin.visible = !powerWin.visible;
                if (powerWin.visible)
                    powerMenu.open();
            }
            function show(): void {
                powerWin.visible = true;
                powerMenu.open();
            }
            function open(): void {
                powerWin.visible = true;
                powerMenu.open();
            }
            function hide(): void {
                powerWin.visible = false;
            }
        }

        // Dim backdrop — click outside cancels confirmation, else dismisses
        Rectangle {
            anchors.fill: parent
            color: "#bf11111b"

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (powerMenu.confirming)
                        powerMenu.cancel();
                    else
                        powerWin.visible = false;
                }
            }
        }

        PowerMenu {
            id: powerMenu
            anchors.centerIn: parent
            width: powerMenu.collapsed ? Theme.powerTileW + Theme.powerPadding * 2 : Theme.powerWidth
            height: Theme.powerPadding * 2 + Theme.powerTileH

            // Dynamic-Island-style spring: slight overshoot as the card
            // morphs between full menu and single-tile confirmation.
            Behavior on width {
                SpringAnimation {
                    spring: 3.5
                    damping: 0.3
                }
            }

            onHideRequested: powerWin.visible = false
        }
    }

    PanelWindow {
        id: islandWin
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: true
        visible: false
        color: "transparent"

        // On-demand keyboard focus (month ←/→, T today, Esc close);
        // outside-click dismissal via focus grab, like the wifi menu.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Keys.onEscapePressed: island.close()

        HyprlandFocusGrab {
            windows: [islandWin]
            active: islandWin.visible
            onCleared: island.close()
        }

        IpcHandler {
            target: "island"
            function toggle(): void {
                if (islandWin.visible) {
                    islandWin.visible = false;
                } else {
                    islandWin.visible = true;
                    island.open();
                }
            }
            function show(): void {
                islandWin.visible = true;
                island.open();
            }
            function hide(): void {
                islandWin.visible = false;
            }
        }

        // Backdrop — click outside shrinks the island away
        MouseArea {
            anchors.fill: parent
            onClicked: island.close()
        }

        IslandClock {
            id: island
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.islandTopMargin
            width: island.frameW
            height: island.frameH
            onHideRequested: islandWin.visible = false
        }
    }

    // ---- notifications: server + toast stack + history center ----
    // State lives here; arrays are always reassigned (never mutated in
    // place) so bindings and Repeaters update.
    QtObject {
        id: notifState
        property var history: []
        property int unread: 0
        property bool dnd: false
        property var dbg: []

        function log(m: string): void {
            var t = new Date();
            var ts = (t.getHours() < 10 ? "0" : "") + t.getHours() + ":" + (t.getMinutes() < 10 ? "0" : "") + t.getMinutes() + ":" + (t.getSeconds() < 10 ? "0" : "") + t.getSeconds();
            dbg = dbg.concat([ts + " " + m]).slice(-30);
        }

        function stampNow(): string {
            var d = new Date();
            var h = d.getHours(), m = d.getMinutes();
            return (h < 10 ? "0" + h : "" + h) + ":" + (m < 10 ? "0" + m : "" + m);
        }

        function notify(n): void {
            var id = n.id;
            log("notify id=" + id + " app=" + n.appName + " urg=" + Number(n.urgency) + " exp=" + n.expireTimeout);
            // Keep the server object alive: untracked notifications may be
            // destroyed while a toast still references them.
            n.tracked = true;
            var stamp = stampNow();
            history = [{
                app: n.appName,
                summary: n.summary,
                body: n.body,
                urg: Number(n.urgency),
                img: n.image || "",
                stamp: stamp
            }].concat(history).slice(0, 50);
            unread++;
            if (!dnd)
                spawnToast(n, stamp);
        }

        function spawnToast(n, stamp: string): void {
            // Replace semantics: a re-sent id supersedes the old toast.
            for (var i = toastStack.children.length - 1; i >= 0; i--) {
                var old = toastStack.children[i];
                if (old.toastId === n.id)
                    old.destroy();
            }
            var t = n.expireTimeout;
            var critical = Number(n.urgency) === 2;
            var sticky = critical && (t === 0 || t < 0);
            var timeout = sticky ? 0 : (t > 0 ? Math.min(t, 15000) : Theme.notifTimeoutMs);
            var img = n.image || "";
            if (img !== "" && img.indexOf("://") < 0)
                img = "file://" + img;
            toastComponent.createObject(toastStack, {
                toastId: n.id,
                app: n.appName || "Notification",
                summary: n.summary || "",
                body: n.body || "",
                imgSrc: img,
                stamp: stamp,
                note: n,
                sticky: sticky,
                timeoutMs: timeout
            });
            // Cap the stack; oldest non-leaving toast leaves to make room.
            while (toastStack.children.length > Theme.notifMaxShown) {
                var victim = null;
                for (var j = 0; j < toastStack.children.length; j++) {
                    if (!toastStack.children[j].leaving) {
                        victim = toastStack.children[j];
                        break;
                    }
                }
                if (!victim)
                    break;
                victim.dismiss();
            }
        }

        function openCenter(): void {
            centerWin.visible = true;
            center.open();
            unread = 0;
        }

        function clearHistory(): void {
            history = [];
            unread = 0;
        }

        function removeHistory(i: int): void {
            history = history.filter(function(item, j) {
                return j !== i;
            });
        }

        function removeGroup(key: string): void {
            history = history.filter(function(h) {
                return ((((h && h.app) || "Notification") + "").toLowerCase() !== key);
            });
        }

        function toggleDnd(): void {
            dnd = !dnd;
        }

        function statusJson(): string {
            var bell = dnd ? "" : "";
            var tip = dnd ? "Do Not Disturb is on" : (unread > 0 ? unread + " unread notification" + (unread > 1 ? "s" : "") : "No new notifications");
            var cls = dnd ? "dnd" : (unread > 0 ? "unread" : "");
            return JSON.stringify({
                text: bell,
                tooltip: tip,
                class: cls
            });
        }
    }

    NotificationServer {
        id: notifServer
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        inlineReplySupported: false
        persistenceSupported: true
        onNotification: function(n) {
            notifState.notify(n);
        }
    }

    PanelWindow {
        id: toastWin
        anchors {
            top: true
            left: true
            right: true
        }
        margins {
            top: Theme.notifTopMargin
        }
        implicitHeight: toastStack.implicitHeight
        visible: toastStack.children.length > 0
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: false
        color: "transparent"

        mask: Region {
            item: toastStack
        }

        Component {
            id: toastComponent
            NotifToast {}
        }

        // Right-aligned stack in a full-width strip: swiped cards stay
        // visible through their whole travel instead of clipping at a
        // toast-sized window edge.
        Column {
            id: toastStack
            anchors.right: parent.right
            anchors.rightMargin: Theme.notifRightMargin
            width: Theme.notifWidth
            spacing: Theme.notifSpacing
        }
    }

    PanelWindow {
        id: centerWin
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: true
        visible: false
        color: "transparent"

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Keys.onEscapePressed: center.close()

        HyprlandFocusGrab {
            windows: [centerWin]
            active: centerWin.visible
            onCleared: center.close()
        }

        IpcHandler {
            target: "notifs"
            function toggle(): void {
                if (centerWin.visible)
                    center.close();
                else
                    notifState.openCenter();
            }
            function show(): void {
                notifState.openCenter();
            }
            function hide(): void {
                center.close();
            }
            function clear(): void {
                notifState.clearHistory();
            }
            function dnd(): void {
                notifState.toggleDnd();
            }
            function status(): string {
                return notifState.statusJson();
            }
            function debug(): string {
                var items = [];
                for (var i = 0; i < toastStack.children.length; i++)
                    items.push({
                        id: toastStack.children[i].toastId,
                        leaving: toastStack.children[i].leaving
                    });
                return JSON.stringify({
                    toasts: items,
                    log: notifState.dbg
                });
            }
        }

        // Backdrop — click outside shrinks the center away
        MouseArea {
            anchors.fill: parent
            onClicked: center.close()
        }

        NotifCenter {
            id: center
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Theme.notifTopMargin
            anchors.rightMargin: Theme.notifRightMargin
            width: center.frameW
            height: center.frameH
            history: notifState.history
            dnd: notifState.dnd
            unread: notifState.unread
            onHideRequested: centerWin.visible = false
            onClearRequested: notifState.clearHistory()
            onRemoveRequested: function(i) {
                notifState.log("history remove tap index=" + i);
                notifState.removeHistory(i);
            }
            onRemoveGroupRequested: function(k) {
                notifState.log("history remove group key=" + k);
                notifState.removeGroup(k);
            }
            onDndToggled: notifState.toggleDnd()
        }
    }
}
