// Single notification toast (top-right stack).
// Stable object: spawned dynamically by shell.qml (never Repeater-pooled),
// so timers/animations always belong to the content they show.
// Display data is copied to plain props at spawn; `note` is only kept for
// action invocation + withdraw handling (guarded — the server may drop it).
// Same single-driver morph language as the island: one `progress` value
// (0 dot → 1 expanded) drives its surface and content fade.
pragma ComponentBehavior: Bound
import QtQuick

import "../theme"

IslandPanel {
    id: root
    panelColor: Glass.panel
    expandedRadius: 18
    panelBorder: Glass.stroke

    required property int toastId
    required property string app
    required property string summary
    required property string body
    required property string imgSrc
    required property string stamp
    property var note
    property bool sticky: false
    property int timeoutMs: 6000
    // Remaining expiry while held: press pauses the timer, release resumes
    // with what's left (not a fresh full timeout).
    property int remainingMs: timeoutMs
    property double timerStart: 0

    property bool leaving: false
    // Swipe-to-dismiss offset (sideways only). The card follows the
    // pointer 1:1 while held; release past the threshold (or a fast
    // flick) flings it away, otherwise it snaps back.
    property real dragX: 0
    readonly property real dragDist: Math.abs(root.dragX)

    readonly property bool hasActions: root.note ? root.note.actions.length > 0 : false

    width: 380
    // Height follows content; the column defines it.
    height: body.implicitHeight + 24

    opacity: 1 - Math.min(1, root.dragDist / 220)
    x: root.dragX
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
        root.open();
        if (!sticky) {
            root.remainingMs = root.timeoutMs;
        }
    }

    function pauseExpiry(): void {
        if (root.sticky || !expireTimer.running)
            return;
        root.remainingMs = Math.max(1, expireTimer.interval - (Date.now() - root.timerStart));
        expireTimer.stop();
    }

    function resumeExpiry(): void {
        if (root.sticky || root.leaving || root.progress < 1 || expireTimer.running)
            return;
        root.timerStart = Date.now();
        expireTimer.interval = root.remainingMs;
        expireTimer.start();
    }

    function dismiss(): void {
        hideBanner(true);
    }

    function dismissNotification(): void {
        if (root.leaving)
            return;
        hideBanner(false);
        if (root.note && root.note.tracked)
            root.note.dismiss();
    }

    function hideBanner(expireTransient): void {
        if (root.leaving)
            return;
        root.leaving = true;

        expireTimer.stop();
        // Transient notifications have no history card to own their lifetime.
        if (expireTransient && root.note && root.note.tracked && root.note.transient)
            root.note.expire();
        root.close();
    }


    onOpened: if (!sticky && !leaving && !hoverDetect.containsMouse) resumeExpiry()
    onHideRequested: root.destroy()

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
    }

    Timer {
        id: expireTimer
        interval: root.timeoutMs
        repeat: false
        onTriggered: {
            root.dismiss();
        }
    }

    Component.onCompleted: {
        // App withdrew the notification (replaced/superseded) — leave quietly.
        if (root.note)
            root.note.closed.connect(function () {
                root.hideBanner(false);
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

        onPressed: function (mouse) {
            if (root.leaving) {
                mouse.accepted = false;
                return;
            }
            root.pauseExpiry();
            snapBack.stop();
            cardHover.pressX = cardHover.mapToItem(null, mouse.x, mouse.y).x;
            cardHover.pressOX = root.dragX;
            cardHover.moved = false;
            cardHover.samples = [
                {
                    x: cardHover.mapToItem(null, mouse.x, mouse.y).x,
                    t: Date.now()
                }
            ];
        }
        onPositionChanged: function (mouse) {
            if (!cardHover.pressed || root.leaving)
                return;
            var dx = cardHover.mapToItem(null, mouse.x, mouse.y).x - cardHover.pressX;
            if (Math.abs(dx) > 8)
                cardHover.moved = true;
            if (!cardHover.moved)
                return;
            root.dragX = cardHover.pressOX + dx;
            var now = Date.now();
            cardHover.samples.push({
                x: cardHover.mapToItem(null, mouse.x, mouse.y).x,
                t: now
            });
            while (cardHover.samples.length > 2 && now - cardHover.samples[0].t > 120)
                cardHover.samples.shift();
        }
        onCanceled: {
            snapBack.start();
            root.resumeExpiry();
        }
        onReleased: function (mouse) {
            if (root.leaving)
                return;
            if (!cardHover.moved) {
                if (root.note) {
                    for (var i = 0; i < root.note.actions.length; i++) {
                        if (root.note.actions[i].identifier === "default") {
                            root.note.actions[i].invoke();
                            break;
                        }
                    }
                }
                root.dismiss();
                return;
            }
            var vx = 0;
            var n = cardHover.samples.length;
            // A fast movement followed by a hold is no longer a flick.
            // Movement samples alone otherwise retain stale release velocity.
            if (n > 1 && Date.now() - cardHover.samples[n - 1].t < 120) {
                var a = cardHover.samples[0], b = cardHover.samples[n - 1];
                var dt = Math.max(1, b.t - a.t);
                vx = (b.x - a.x) / dt * 1000;
            }
            var dist = root.dragDist;
            if (dist > 110 || Math.abs(vx) > 900) {
                // Fling out sideways in the flick direction, then gone.
                var dir = Math.abs(vx) > 100 ? (vx > 0 ? 1 : -1) : (root.dragX >= 0 ? 1 : -1);
                flingX.to = dir * 560;

                root.hideBanner(false);
                if (root.note && root.note.tracked)
                    root.note.dismiss();
                flingX.start();
            } else {
                if (!hoverDetect.containsMouse)
                    root.resumeExpiry();
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
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            // App artwork; macOS-style initial tile when none is sent.
            Rectangle {
                id: iconTile
                anchors.top: parent.top
                width: 48
                height: 48
                radius: 10
                color: thumbImg.visible ? "transparent" : Glass.hover
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
                    color: Glass.secondary
                    font.family: Glass.font
                    font.pixelSize: 20
                    font.bold: true
                }
            }

            Column {
                width: parent.width - iconTile.width - parent.spacing
                spacing: 2

                Item {
                    width: parent.width
                    height: 15
                    Text {
                        anchors.left: parent.left
                        anchors.right: bannerTime.left
                        anchors.rightMargin: 6
                        text: root.app
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Glass.secondary
                        font.family: Glass.font
                        font.pixelSize: 10
                    }
                    Text {
                        id: bannerTime
                        anchors.right: parent.right
                        text: root.stamp
                        color: Glass.secondary
                        font.family: Glass.font
                        font.pixelSize: 10
                    }
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: root.summary
                    color: Glass.text
                    font.family: Glass.font
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: root.body
                    color: Glass.secondary
                    font.family: Glass.font
                    font.pixelSize: 12
                }

                Flow {
                    width: parent.width
                    visible: root.hasActions
                    spacing: 8
                    Repeater {
                        model: root.note ? root.note.actions : []
                        delegate: Rectangle {
                            id: toastAction
                            required property var modelData
                            visible: modelData.identifier !== "default"
                            width: Math.min(actionLabel.implicitWidth + 24, 160)
                            height: 30
                            radius: 15
                            color: btnHover.containsMouse ? Glass.hover : Glass.card
                            border.color: Glass.stroke
                            border.width: 1
                            Text {
                                id: actionLabel
                                anchors.centerIn: parent
                                width: parent.width - 24
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                text: toastAction.modelData.text
                                color: Glass.text
                                font.family: Glass.font
                                font.pixelSize: 11
                                font.bold: true
                            }
                            MouseArea {
                                id: btnHover
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    toastAction.modelData.invoke();
                                    root.dismiss();
                                }
                            }
                        }
                    }
                }
            }
        }

        // Hover-reveal close, parked just inside the top-left corner. (Was
        // -9/-9 overlapping outside, which clipped above the layer surface
        // for the topmost toast — the window has no headroom there. Inside
        // keeps every row identical with no window padding changes.)
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.top: parent.top
            anchors.topMargin: 8
            width: 22
            height: 22
            radius: 11
            color: Qt.tint(Glass.panel, Glass.hover)
            opacity: hoverDetect.containsMouse ? 1 : 0
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
                color: Glass.text
                font.family: Glass.font
                font.pixelSize: 11
                font.bold: true
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                onClicked: root.dismissNotification()
            }
        }
    }

    // Topmost hover detector: Qt reports containsMouse only to the uppermost
    // hover-enabled area, so the action buttons used to steal hover from
    // cardHover and the close button flickered (show → steal → hide → show).
    // This layer sits above everything, tracks hover alone, and accepts no
    // buttons — presses fall through to cardHover / action / close below.
    MouseArea {
        id: hoverDetect
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.pauseExpiry()
        onExited: if (!cardHover.pressed)
            root.resumeExpiry()
    }
}
