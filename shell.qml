// Desktop shell and Waybar IPC endpoints.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtCore

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
            item: pill.morphItem
        }
        BackgroundEffect.blurRegion: Region { item: pill.morphItem; radius: pill.expandedRadius }

        property string kind: "volume"
        property int level: 0
        property bool muted: false

        Timer {
            id: hideTimer
            interval: Theme.hideAfterMs
            repeat: false
            onTriggered: pill.close()
        }

        function showOsd(k: string, v: int, m: bool): void {
            osd.kind = k;
            osd.level = Math.max(0, Math.min(100, v));
            osd.muted = m;
            osd.visible = true;
            pill.open();
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
            anchors.centerIn: parent
            kind: osd.kind
            level: osd.level
            muted: osd.muted
            onOpened: hideTimer.restart()
            onHideRequested: osd.visible = false
        }
    }

    PanelWindow {
        id: wallWin
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

        // On-demand keyboard focus (Esc close); outside-click dismissal
        // via focus grab, like the island and notification center.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Keys.onEscapePressed: wallMenu.close()

        // Modal popup behavior: keep keyboard focus while open (Esc + typing
        // work immediately), auto-dismiss when anything outside is clicked.
        HyprlandFocusGrab {
            windows: [wallWin]
            active: wallWin.visible
            onCleared: wallMenu.close()
        }

        IpcHandler {
            target: "wallpaper"
            function toggle(): void {
                if (wallWin.visible)
                    wallMenu.close();
                else {
                    wallWin.visible = true;
                    wallMenu.open();
                }
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
                wallMenu.close();
            }
        }

        // Backdrop — click outside shrinks the picker away
        MouseArea {
            anchors.fill: parent
            onClicked: wallMenu.close()
        }

        WallpaperPicker {
            id: wallMenu
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.wallTopMargin
            width: wallMenu.frameW
            height: wallMenu.frameH
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

    // ---- notifications: server + toast stack + history center ----
    // State lives here; arrays are always reassigned (never mutated in
    // place) so bindings and Repeaters update.
    Settings {
        id: preferences
        location: "file://" + Quickshell.stateDir + "/controls.ini"
        property bool doNotDisturb: false
    }

    QtObject {
        id: notifState
        property var history: []
        readonly property int unread: history.filter(h => h.unread).length
        readonly property bool dnd: preferences.doNotDisturb
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
            const previous = history.find(h => h.id === id);
            const remaining = history.filter(h => h.id !== id);
            const centerOpen = tray.visible && tray.page === "notifications";
            const showBanner = !dnd && !centerOpen && !n.lastGeneration;
            for (const banner of toastStack.children) {
                if (banner.toastId === id) {
                    banner.visible = false;
                    banner.destroy();
                }
            }
            if (n.transient) {
                if (previous) history = remaining;
                if (showBanner) spawnToast(n, stamp);
                else n.expire();
                return;
            }
            const entries = [{
                id: id, note: n,
                unread: !n.lastGeneration && !centerOpen && (!previous || previous.unread),
                app: n.appName, summary: n.summary, body: n.body,
                urg: Number(n.urgency), img: imageFor(n), stamp: stamp
            }].concat(remaining);
            history = entries.slice(0, 50);
            for (const old of entries.slice(50)) if (old.note) old.note.expire();
            if (!previous || previous.note !== n)
                n.closed.connect(() => { history = history.filter(h => h.note !== n); });
            if (showBanner) spawnToast(n, stamp);
        }

        function imageFor(n): string {
            let image = String(n.image || "");
            if (!image && n.appIcon) image = String(Quickshell.iconPath(n.appIcon, true) || "");
            return image.startsWith("/") ? "file://" + image : image;
        }

        function spawnToast(n, stamp: string): void {
            var t = n.expireTimeout;
            var critical = Number(n.urgency) === 2;
            var sticky = t === 0 || (critical && t < 0);
            var timeout = sticky ? 0 : (t > 0 ? t : Theme.notifTimeoutMs);
            const newest = toastComponent.createObject(toastStack, {
                toastId: n.id,
                app: n.appName || "Notification",
                summary: n.summary || "",
                body: n.body || "",
                imgSrc: imageFor(n),
                stamp: stamp,
                note: n,
                sticky: sticky,
                timeoutMs: timeout
            });
            // Count active banners, excluding those already animating out.
            var active = [];
            for (var j = 0; j < toastStack.children.length; j++)
                if (!toastStack.children[j].leaving && (toastStack.children[j] === newest || toastStack.children[j].toastId !== n.id))
                    active.push(toastStack.children[j]);
            while (active.length > Theme.notifMaxShown) active.shift().dismiss();
        }

        function clearHistory(): void {
            history.forEach(function(h) { if (h.note) h.note.dismiss(); });
            history = [];
        }

        function removeHistory(i: int): void {
            const entry = history[i];
            if (!entry) return;
            history = history.filter(h => h.id !== entry.id);
            if (entry.note) entry.note.dismiss();
        }

        function removeGroup(key: string): void {
            history.forEach(function(h) {
                if (((h.app || "Notification") + "").toLowerCase() === key && h.note) h.note.dismiss();
            });
            history = history.filter(function(h) {
                return ((((h && h.app) || "Notification") + "").toLowerCase() !== key);
            });
        }

        function toggleDnd(): void {
            preferences.doNotDisturb = !dnd;
            if (dnd) {
                for (var i = 0; i < toastStack.children.length; i++) toastStack.children[i].dismiss();
            }
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
        screen: tray.currentScreen()
        margins {
            top: 36
        }
        implicitHeight: toastStack.implicitHeight
        BackgroundEffect.blurRegion: toastWin.mask
        visible: toastStack.children.length > 0
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: false
        color: "transparent"

        mask: Region {
            regions: toastStack.children.filter(banner => banner.visible && banner.opacity > 0)
                                        .map(banner => banner.surfaceRegion)
        }

        Component {
            id: toastComponent
            NotifToast {
                id: banner
                originX: tray.originFor("notifications", toastWin.screen, toastStack.x, width, width - 48)
                // The surface morphs inside a card that also moves and scales when dragged.
                readonly property TransformWatcher movement: TransformWatcher {
                    a: banner.morphItem
                    b: toastWin.contentItem
                }
                readonly property rect surfaceBounds: {
                    movement.transform
                    const surface = banner.morphItem
                    return surface.mapToItem(toastWin.contentItem, Qt.rect(0, 0, surface.width, surface.height))
                }
                readonly property Region surfaceRegion: Region {
                    x: Math.round(banner.surfaceBounds.x)
                    y: Math.round(banner.surfaceBounds.y)
                    width: Math.round(banner.surfaceBounds.x + banner.surfaceBounds.width) - x
                    height: Math.round(banner.surfaceBounds.y + banner.surfaceBounds.height) - y
                    radius: Math.round(banner.morphItem.radius * banner.scale)
                }
            }
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

    // A single right-edge surface keeps keyboard focus stable when opening a detail view.
    PanelWindow {
        id: tray
        property string page: "controls"
        readonly property var views: ({"controls": controls, "wifi": wifiMenu, "sound": soundMenu, "profile": profileMenu,
                                        "island": island, "notifications": center})
        readonly property var current: views[page]
        property bool fromOverview: false
        property var buttonOrigins: ({})
        property var buttonScreen: null
        readonly property real panelLeft: screen ? screen.width - content.width - 10 : 0
        function originFor(name: string, monitor: var, left: real, panelWidth: real, fallback: real): real {
            const suffix = "@" + (monitor ? monitor.name : "");
            let position = buttonOrigins[name + suffix];
            if (position === undefined && fromOverview)
                position = buttonOrigins["controls" + suffix];
            const origin = position === undefined ? fallback : position - left;
            return Math.max(0.5, Math.min(panelWidth - 0.5, origin));
        }
        function toggleFromButton(name: string, monitorName: string, position: int): void {
            const origins = Object.assign({}, buttonOrigins);
            origins[name + "@" + monitorName] = position;
            buttonOrigins = origins;
            if (visible && page === name && !current.exiting && screen && screen.name === monitorName) {
                current.close();
                return;
            }
            buttonScreen = Quickshell.screens.find(s => s.name === monitorName) || currentScreen();
            showPage(name, false);
        }
        function currentScreen(): var {
            const monitor = Hyprland.focusedMonitor;
            return Quickshell.screens.find(s => monitor && s.name === monitor.name) || Quickshell.screens[0] || null;
        }
        function showPage(name: string, detail: bool): void {
            if (!visible || buttonScreen) screen = buttonScreen || currentScreen();
            buttonScreen = null;
            fromOverview = !!detail;
            page = name;
            visible = true;
            if (name === "notifications") {
                notifState.history = notifState.history.map(h => Object.assign({}, h, {unread: false}));
                for (const banner of toastStack.children) banner.dismiss();
            }
            current.open();
            current.forceActiveFocus();
        }
        function togglePage(name: string): void {
            if (visible && page === name && !current.exiting) current.close();
            else showPage(name, false);
        }
        function closePage(name: string): void {
            if (visible && page === name) current.close();
        }
        function finish(name: string): void {
            if (page === name) visible = false;
        }

        anchors { top: true; left: page === "island"; right: true }
        margins { top: 36; right: page === "island" ? 0 : 10 }
        implicitWidth: Math.min(screen ? screen.width - 20 : 400, Math.ceil(current.frameW))
        implicitHeight: Math.min(screen ? screen.height - 48 : Math.ceil(current.frameH), Math.ceil(current.frameH) + (back.visible ? 32 : 0))
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        visible: false
        color: "transparent"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "desktop-controls"
        BackgroundEffect.blurRegion: Region {
            item: tray.page === "island" ? island : tray.current.morphItem
            radius: Glass.radius
            Region { item: back }
        }
        mask: Region {
            item: tray.page === "island" ? island : tray.current.morphItem
            Region { item: back }
        }

        HyprlandFocusGrab {
            windows: [tray]
            active: tray.visible
            onCleared: if (tray.visible) tray.current.close()
        }
        IpcHandler {
            target: "controls"
            function status(): string { return "ready"; }
            function toggle(): void { tray.togglePage("controls"); }
            function toggleAt(monitor: string, x: int): void { tray.toggleFromButton("controls", monitor, x); }
            function show(): void { tray.showPage("controls", false); }
            function hide(): void { tray.closePage("controls"); }
        }
        IpcHandler {
            target: "sound"
            function toggle(): void { tray.togglePage("sound"); }
            function toggleAt(monitor: string, x: int): void { tray.toggleFromButton("sound", monitor, x); }
            function show(): void { tray.showPage("sound", false); }
            function hide(): void { tray.closePage("sound"); }
        }
        IpcHandler {
            target: "wifi"
            function toggle(): void { tray.togglePage("wifi"); }
            function toggleAt(monitor: string, x: int): void { tray.toggleFromButton("wifi", monitor, x); }
            function show(): void { tray.showPage("wifi", false); }
            function hide(): void { tray.closePage("wifi"); }
        }
        IpcHandler {
            target: "profile"
            function toggle(): void { tray.togglePage("profile"); }
            function toggleAt(monitor: string, x: int): void { tray.toggleFromButton("profile", monitor, x); }
        }
        IpcHandler {
            target: "island"
            function toggle(): void { tray.togglePage("island"); }
            function show(): void { tray.showPage("island", false); }
            function hide(): void { tray.closePage("island"); }
        }
        IpcHandler {
            target: "notifs"
            function toggle(): void { tray.togglePage("notifications"); }
            function toggleAt(monitor: string, x: int): void { tray.toggleFromButton("notifications", monitor, x); }
            function show(): void { tray.showPage("notifications", false); }
            function hide(): void { tray.closePage("notifications"); }
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


        FocusScope {
            id: panelContent
            anchors.fill: parent
            Keys.onEscapePressed: tray.current.close()
            Rectangle {
                id: back
                visible: tray.visible && tray.fromOverview
                width: parent.width
                height: visible ? 32 : 0
                opacity: Math.max(0, Math.min(1, (tray.current.progress - 0.8) / 0.2))
                enabled: tray.current.progress > 0.85
                color: Glass.panel
                border.color: Glass.stroke
                radius: 14
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Back to Control Center"
                Accessible.onPressAction: tray.showPage("controls", false)
                Keys.onReturnPressed: tray.showPage("controls", false)
                Text {
                    anchors.centerIn: parent
                    text: "‹   Control Center"
                    color: Glass.text
                    font.family: Glass.font
                    font.pixelSize: 12
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tray.showPage("controls", false)
                }
            }
            Item {
                id: content
                anchors { top: back.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
                WifiMenu {
                    id: wifiMenu
                    originX: tray.originFor("wifi", tray.screen, tray.panelLeft, width, width - 0.5)
                    anchors.fill: parent
                    visible: tray.visible && tray.page === "wifi"
                    onHideRequested: tray.finish("wifi")
                }
                SoundMenu {
                    id: soundMenu
                    originX: tray.originFor("sound", tray.screen, tray.panelLeft, width, width - 0.5)
                    anchors.fill: parent
                    visible: tray.visible && tray.page === "sound"
                    onHideRequested: tray.finish("sound")
                }
                ProfileMenu {
                    id: profileMenu
                    originX: tray.originFor("profile", tray.screen, tray.panelLeft, width, width - 0.5)
                    anchors.fill: parent
                    visible: tray.visible && tray.page === "profile"
                    overviewVisible: controls.visible
                    onHideRequested: tray.finish("profile")
                }
                ControlCenter {
                    id: controls
                    originX: tray.originFor("controls", tray.screen, tray.panelLeft, width, width - 0.5)
                    anchors.fill: parent
                    visible: tray.visible && tray.page === "controls"
                    dnd: notifState.dnd
                    profile: profileMenu.profile
                    profileLabel: profileMenu.profileLabel
                    onOpening: profileMenu.refresh()
                    onDndToggled: notifState.toggleDnd()
                    onWifiRequested: tray.showPage("wifi", true)
                    onSoundRequested: tray.showPage("sound", true)
                    onProfileRequested: tray.showPage("profile", true)
                    onHideRequested: tray.finish("controls")
                }
                IslandClock {
                    id: island
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    width: frameW
                    height: frameH
                    visible: tray.visible && tray.page === "island"
                    onHideRequested: tray.finish("island")
                }
                NotifCenter {
                    id: center
                    originX: tray.originFor("notifications", tray.screen, tray.panelLeft, width, width - 0.5)
                    anchors.fill: parent
                    visible: tray.visible && tray.page === "notifications"
                    history: notifState.history
                    dnd: notifState.dnd
                    unread: notifState.unread
                    onDndToggled: notifState.toggleDnd()
                    onHideRequested: tray.finish("notifications")
                    onClearRequested: notifState.clearHistory()
                    onRemoveRequested: i => notifState.removeHistory(i)
                    onRemoveGroupRequested: k => notifState.removeGroup(k)
                }
            }
        }
    }
}
