// Single notification toast (top-right stack).
// Stable object: spawned dynamically by shell.qml (never Repeater-pooled),
// so timers/animations always belong to the content they show.
// Display data is copied to plain props at spawn; `note` is only kept for
// action invocation + withdraw handling (guarded — the server may drop it).
// Same single-driver morph language as the island: one `progress` value
// (0 gone → 1 settled) drives slide + fade; the timeout bar is time-based.
import QtQuick

import "../theme"

Rectangle {
    id: root
    color: Theme.notifBg
    radius: Theme.notifRadius
    border.color: Theme.notifBorder
    border.width: 1
    // No clip: the hover close button intentionally overlaps the corner.

    required property int toastId
    required property string app
    required property string summary
    required property string body
    required property string imgSrc
    required property string stamp
    property var note
    property bool sticky: false
    property int timeoutMs: 6000

    property real progress: 0
    property bool leaving: false
    // Swipe-to-dismiss offset (sideways only). The card follows the
    // pointer 1:1 while held; release past the threshold (or a fast
    // flick) flings it away, otherwise it snaps back.
    property real dragX: 0
    readonly property real dragDist: Math.abs(root.dragX)

    readonly property bool hasActions: root.note ? root.note.actions.length > 0 : false

    width: Theme.notifWidth
    // Height follows content; the column defines it.
    height: body.implicitHeight + 24

    opacity: root.progress * (1 - Math.min(1, root.dragDist / 220))
    x: (1 - root.progress) * 56 + root.dragX
    // Scale the whole container (background + content) while held so the
    // card feels picked up. cardHover is declared below — forward ref is
    // fine (same as the close button's containsMouse binding).
    scale: cardHover.pressed ? 1.02 : 1

    Behavior on scale {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }

    function show(): void {
        notifState.log("toast show id=" + root.toastId + " sticky=" + root.sticky + " timeout=" + root.timeoutMs);
        enterAnim.start();
        if (!sticky)
            expireTimer.start();
    }

    function dismiss(): void {
        if (root.leaving)
            return;
        root.leaving = true;
        notifState.log("toast dismiss id=" + root.toastId);
        expireTimer.stop();
        exitAnim.start();
    }

    NumberAnimation {
        id: enterAnim
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 500
        easing.type: Easing.OutExpo
    }
    NumberAnimation {
        id: exitAnim
        target: root
        property: "progress"
        to: 0
        duration: 220
        easing.type: Easing.InCubic
        onFinished: {
            notifState.log("toast exitDone id=" + root.toastId);
            root.destroy();
        }
    }

    // Snap back when a swipe is released short of the threshold.
    NumberAnimation {
        id: snapBack
        target: root
        property: "dragX"
        to: 0
        duration: 260
        easing.type: Easing.OutCubic
    }

    // Fling out sideways after a hard flick, then gone.
    NumberAnimation {
        id: flingX
        target: root
        property: "dragX"
        duration: 180
        easing.type: Easing.OutCubic
        onFinished: root.destroy()
    }

    Timer {
        id: expireTimer
        interval: root.timeoutMs
        repeat: false
        onTriggered: {
            notifState.log("toast expired id=" + root.toastId);
            root.dismiss();
        }
    }

    Component.onCompleted: {
        // App withdrew the notification (replaced/superseded) — leave quietly.
        if (root.note)
            root.note.closed.connect(function() {
                root.dismiss();
            });
        root.show();
    }

    // Card gesture: click clears the banner (macOS behavior), sideways
    // drag swipes it away. Hover-tracking reveals the close button.
    MouseArea {
        id: cardHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: cardHover.pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor

        property real pressX: 0
        property real pressOX: 0
        property bool moved: false
        property var samples: []

        onPressed: function(mouse) {
            notifState.log("toast press id=" + root.toastId + " at=" + Math.round(mouse.x) + "," + Math.round(mouse.y));
            if (root.leaving) {
                mouse.accepted = false;
                return;
            }
            snapBack.stop();
            cardHover.pressX = mouse.x;
            cardHover.pressOX = root.dragX;
            cardHover.moved = false;
            cardHover.samples = [{
                x: mouse.x,
                t: Date.now()
            }];
        }
        onPositionChanged: function(mouse) {
            if (!cardHover.pressed || root.leaving)
                return;
            var dx = mouse.x - cardHover.pressX;
            if (Math.abs(dx) > 8)
                cardHover.moved = true;
            if (!cardHover.moved)
                return;
            root.dragX = cardHover.pressOX + dx;
            var now = Date.now();
            cardHover.samples.push({
                x: mouse.x,
                t: now
            });
            while (cardHover.samples.length > 2 && now - cardHover.samples[0].t > 120)
                cardHover.samples.shift();
        }
        onReleased: function(mouse) {
            if (root.leaving)
                return;
            if (!cardHover.moved) {
                root.dismiss();
                return;
            }
            var vx = 0;
            var n = cardHover.samples.length;
            if (n > 1) {
                var a = cardHover.samples[0], b = cardHover.samples[n - 1];
                var dt = Math.max(1, b.t - a.t);
                vx = (b.x - a.x) / dt * 1000;
            }
            var dist = root.dragDist;
            if (dist > 110 || Math.abs(vx) > 900) {
                // Fling out sideways in the flick direction, then gone.
                var dir = Math.abs(vx) > 100 ? (vx > 0 ? 1 : -1) : (root.dragX >= 0 ? 1 : -1);
                flingX.to = dir * 560;
                notifState.log("toast fling id=" + root.toastId + " dist=" + Math.round(dist) + " speed=" + Math.round(vx));
                root.leaving = true;
                expireTimer.stop();
                flingX.start();
            } else {
                notifState.log("toast snapback id=" + root.toastId + " dist=" + Math.round(dist));
                snapBack.start();
            }
        }
    }

    // Swipe layer: plain content wrapper. The drag offset + pickup scale
    // live on the root itself (the Column stack only owns y, so root.x is
    // free) — that way the background/border move together with the
    // content instead of the content sliding out of a parked container.
    Item {
        id: slider
        x: 0
        y: 0
        width: parent.width
        height: parent.height

    Row {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.leftMargin: Theme.notifPadding
        anchors.rightMargin: Theme.notifPadding
        spacing: 12

        // App artwork; macOS-style initial tile when none is sent.
        Rectangle {
            id: iconTile
            anchors.top: parent.top
            width: 48
            height: 48
            radius: 10
            color: thumbImg.visible ? "transparent" : "#2c2c30"
            clip: true

            Image {
                id: thumbImg
                anchors.fill: parent
                visible: root.imgSrc !== "" && status !== Image.Error
                source: root.imgSrc
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }
            Text {
                anchors.centerIn: parent
                visible: !thumbImg.visible
                text: root.app.charAt(0).toUpperCase()
                color: "#a0a0a8"
                font.family: Theme.notifFont
                font.pixelSize: 20
                font.bold: true
            }
        }

        Column {
            width: parent.width - iconTile.width - parent.spacing
            spacing: 2

        Text {
            width: parent.width
            visible: text !== ""
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: root.summary
            color: Theme.notifText
            font.family: Theme.notifFont
            font.pixelSize: Theme.notifTitleSize
            font.bold: true
        }

        Text {
            width: parent.width
            visible: text !== ""
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            text: root.body
            color: Theme.notifDim
            font.family: Theme.notifFont
            font.pixelSize: Theme.notifBodySize
        }

        Row {
            width: parent.width
            visible: root.hasActions
            spacing: 8
            Repeater {
                model: root.note ? root.note.actions : []
                delegate: Rectangle {
                    required property var modelData
                    width: Math.min(actionLabel.implicitWidth + 24, 160)
                    height: 30
                    radius: 15
                    color: btnHover.containsMouse ? Theme.notifHover : "#0dffffff"
                    border.color: Theme.notifBorder
                    border.width: 1
                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        width: parent.width - 24
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: modelData.text
                        color: Theme.notifText
                        font.family: Theme.notifFont
                        font.pixelSize: Theme.notifSmallSize
                        font.bold: true
                    }
                    MouseArea {
                        id: btnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            modelData.invoke();
                            root.dismiss();
                        }
                    }
                }
            }
        }
        }
    }

    // Hover-reveal close, parked on the top-left corner (macOS style).
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: -9
        anchors.top: parent.top
        anchors.topMargin: -9
        width: 22
        height: 22
        radius: 11
        color: "#48484a"
        opacity: cardHover.containsMouse ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: "#ffffff"
            font.family: Theme.notifFont
            font.pixelSize: 11
            font.bold: true
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: root.dismiss()
        }
    }
    }
}
