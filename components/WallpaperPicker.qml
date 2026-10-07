// Wallpaper filmstrip picker: sliding carousel (dim sides, bright center).
// Lives in a fullscreen transparent PanelWindow (see shell.qml wallWin).
// open() runs one continuous dot→card morph; close() shrinks it back and
// emits hideRequested so the shell can hide the window.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

import "../theme"

Rectangle {
    id: root
    color: Theme.wallBg
    // Single continuous morph, same language as the island/wifi/center:
    // every dimension is a function of `progress` (0 dot → 1 full card),
    // driven by exactly one animation. Radius blends from a perfect circle
    // into the card corner — no staged retargets.
    radius: (1 - root.progress) * Math.min(root.width, root.height) / 2 + root.progress * Theme.wallRadius
    border.color: Theme.wallBorder
    border.width: 1
    clip: true

    signal hideRequested()

    property var files: []
    property int count: 0
    property int selected: 0
    property bool busy: false
    // True while parseList syncs `selected` to the live wallpaper — the
    // film jumps straight to the current theme instead of sliding in
    // from the stale index (the x Behavior stays off for that one change).
    property bool snapping: false

    // 0 = dot, 1 = full card. Animated once per open (OutExpo: fast
    // expansion, soft landing — the Dynamic Island feel).
    property real progress: 0
    property bool exiting: false

    readonly property real frameW: Theme.wallDot + (Theme.wallWidth - Theme.wallDot) * root.progress
    readonly property real frameH: Theme.wallDot + (Theme.wallHeight - Theme.wallDot) * root.progress
    // Contents fade in over the final stretch of the morph only.
    readonly property real contentOpacity: Math.min(1, Math.max(0, (root.progress - 0.8) / 0.2))

    focus: true

    function open(): void {
        morphOut.stop();
        root.exiting = false;
        refresh();
        root.focus = true;
        root.forceActiveFocus();
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
            color: Theme.wallActiveBorder

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

    function refresh(): void {
        root.busy = true;
        listProc.exec(["bash", "-c", "exec \"$HOME/.config/hypr/scripts/wallpaper-thumbs.sh\""]);
    }

    function move(d: int): void {
        if (count === 0)
            return;
        root.selected = Math.max(0, Math.min(count - 1, root.selected + d));
    }

    function applyCurrent(): void {
        if (count === 0)
            return;
        var path = files[selected].full;
        applyProc.exec(["bash", "-c", "exec \"$HOME/.config/hypr/scripts/wallpaper.sh\" \"$1\"", "wallpaper-picker", path]);
        root.close();
    }

    function parseList(text: string): void {
        var lines = text.split("\n");
        var cur = "";
        var list = [];
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === "")
                continue;
            if (line.startsWith("CUR:")) {
                cur = line.slice(4).trim();
            } else {
                var sep = line.indexOf("|");
                if (sep > 0)
                    list.push({
                        full: line.slice(0, sep),
                        thumb: line.slice(sep + 1)
                    });
            }
        }
        root.files = list;
        root.count = list.length;
        // Snap, don't slide: `selected` still holds the stale index from
        // the last open (or 0 on first run), so the film would visibly
        // travel from the wrong theme once CUR resolves. Disable the x
        // Behavior for this one sync; user moves keep animating.
        root.snapping = true;
        if (list.length === 0) {
            root.selected = 0;
        } else {
            var idx = -1;
            for (var j = 0; j < list.length; j++) {
                if (list[j].full === cur) {
                    idx = j;
                    break;
                }
            }
            root.selected = idx >= 0 ? idx : Math.min(root.selected, list.length - 1);
        }
        root.busy = false;
        Qt.callLater(function() {
            root.snapping = false;
        });
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: parseList(text)
        }
    }
    Process {
        id: applyProc
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            if (event.angleDelta.y > 0 || event.angleDelta.x < 0)
                root.move(-1);
            else if (event.angleDelta.y < 0 || event.angleDelta.x > 0)
                root.move(1);
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            root.move(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            root.move(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.applyCurrent();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.close();
            event.accepted = true;
        }
    }

    Item {
        id: strip
        anchors.fill: parent
        anchors.margins: Theme.wallPadding
        clip: true
        opacity: root.contentOpacity
        enabled: root.progress > 0.85
        visible: opacity > 0

        Row {
            id: film
            height: Theme.wallThumbH
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.wallSpacing
            x: strip.width / 2 - (root.selected * (Theme.wallThumbW + Theme.wallSpacing) + Theme.wallThumbW / 2)

            Behavior on x {
                // User moves only: during the dot→card morph film.x tracks
                // the growing strip width, so animating it would trail the
                // target and glide in from the left. Same for the parseList
                // snap (see `snapping`).
                enabled: !root.snapping && root.progress >= 1
                NumberAnimation {
                    duration: Theme.wallSlideMs
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                model: root.files
                delegate: Rectangle {
                    id: thumb
                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: thumb.index === root.selected

                    width: Theme.wallThumbW
                    height: Theme.wallThumbH
                    color: "#1a1a1a"
                    scale: isCurrent ? Theme.wallActiveScale : Theme.wallSideScale
                    opacity: isCurrent ? 1 : Theme.wallSideOpacity
                    z: isCurrent ? 10 : 1
                    border.color: isCurrent ? Theme.wallActiveBorder : Theme.wallThumbBorder
                    border.width: isCurrent ? 2 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.wallPopMs
                            easing.type: Easing.OutBack
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.wallPopMs
                        }
                    }

                    Image {
                        anchors.fill: parent
                        source: "file://" + thumb.modelData.thumb
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (thumb.isCurrent)
                                root.applyCurrent();
                            else
                                root.selected = thumb.index;
                        }
                    }
                }
            }
        }
    }
}
