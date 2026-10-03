// Wallpaper filmstrip picker: sliding carousel (dim sides, bright center).
// Exposes open() so the shell can refresh + focus on show; emits hideRequested on dismiss/apply.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

import "../theme"

Rectangle {
    id: root
    color: Theme.wallBg
    radius: Theme.wallRadius
    border.color: Theme.wallBorder
    border.width: 1

    signal hideRequested()

    property var files: []
    property int count: 0
    property int selected: 0
    property bool busy: false

    focus: true

    function open(): void {
        refresh();
        root.focus = true;
        root.forceActiveFocus();
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
        root.hideRequested();
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
            root.hideRequested();
            event.accepted = true;
        }
    }

    Item {
        id: strip
        anchors.fill: parent
        anchors.margins: Theme.wallPadding
        clip: true

        Row {
            id: film
            height: Theme.wallThumbH
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.wallSpacing
            x: strip.width / 2 - (root.selected * (Theme.wallThumbW + Theme.wallSpacing) + Theme.wallThumbW / 2)

            Behavior on x {
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
