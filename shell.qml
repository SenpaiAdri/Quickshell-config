// Shell entry — OSD toast + Wi-Fi menu.
// Triggered via: quickshell ipc call osd popup <...> | quickshell ipc call wifi toggle
// Window chrome + IPC live here; visuals live in components/ (tuned via theme/).
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
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
}
