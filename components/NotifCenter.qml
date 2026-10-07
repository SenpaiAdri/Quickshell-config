// Notification history center card (swaync panel replacement).
// Pure view: history list + dnd flag come via props from shell.qml.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Mpris

import "../theme"

Rectangle {
    id: root
    // Fully opaque (alpha stripped from notifBg): rows are only ~5%
    // white, so any card translucency lets behind-content bleed through
    // the list. Opaque card keeps rows readable.
    color: "#141414"
    // Single continuous morph, same language as the island: every dimension
    // is a function of `progress` (0 dot → 1 full card), driven by exactly
    // one animation. Radius blends from a perfect circle into the card
    // corner — no staged retargets.
    radius: (1 - root.progress) * Math.min(root.width, root.height) / 2 + root.progress * Theme.notifRadius
    border.color: Theme.notifBorder
    border.width: 1
    clip: true

    required property var history
    property bool dnd: false
    property int unread: 0

    signal hideRequested()
    signal clearRequested()
    signal removeRequested(int index)
    signal removeGroupRequested(string appKey)
    signal dndToggled()

    // Active media player (swaync `mpris` widget parity): prefer the
    // playing player, else the first one advertising a track. Null when
    // nothing is available — the card below collapses to height 0.
    readonly property var mprisPlayers: Mpris.players.values
    readonly property var activePlayer: {
        var ps = root.mprisPlayers;
        var fallback = null;
        for (var i = 0; i < ps.length; i++) {
            var p = ps[i];
            if (!p)
                continue;
            if (p.isPlaying)
                return p;
            if (fallback === null && p.trackTitle !== "")
                fallback = p;
        }
        return fallback !== null ? fallback : (ps.length > 0 ? ps[0] : null);
    }
    readonly property bool hasMedia: root.activePlayer !== null && root.activePlayer.trackTitle !== ""

    // App-grouped view of history: newest group first, newest item first
    // within each group. Expanded/collapsed state lives here (keyed by
    // lowercase app name) so it survives history updates.
    property var expandedGroups: ({})
    readonly property var groups: {
        var out = [];
        for (var i = 0; i < root.history.length; i++) {
            var h = root.history[i];
            var key = (((h && h.app) || "Notification") + "").toLowerCase();
            var gi = -1;
            for (var j = 0; j < out.length; j++) {
                if (out[j].key === key) {
                    gi = j;
                    break;
                }
            }
            if (gi < 0) {
                out.push({
                    key: key,
                    app: (h && h.app) || "Notification",
                    items: [i]
                });
            } else {
                out[gi].items.push(i);
            }
        }
        return out;
    }

    function toggleGroup(key: string): void {
        var e = Object.assign({}, root.expandedGroups);
        e[key] = !e[key];
        root.expandedGroups = e;
    }

    // 0 = dot, 1 = full card. Animated once per open (OutExpo: fast
    // expansion, soft landing — the Dynamic Island feel).
    property real progress: 0
    property bool exiting: false

    readonly property real frameW: Theme.centerDot + (Theme.centerWidth - Theme.centerDot) * root.progress
    readonly property real frameH: Theme.centerDot + (Theme.centerHeight - Theme.centerDot) * root.progress
    // Contents fade in over the final stretch of the morph only.
    readonly property real contentOpacity: Math.min(1, Math.max(0, (root.progress - 0.8) / 0.2))

    function open(): void {
        morphOut.stop();
        root.exiting = false;
        morphIn.start();
        root.forceActiveFocus();
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

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.close();
            event.accepted = true;
        }
    }

    // Swallow card clicks so the backdrop never fires from inside.
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
            color: Theme.notifAccent

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

    Column {
        id: cardView
        anchors.fill: parent
        anchors.margins: Theme.notifPadding
        spacing: 8
        opacity: root.contentOpacity
        enabled: root.progress > 0.85
        visible: opacity > 0

        // Header
        Item {
            width: parent.width
            height: 30
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.unread > 0 ? "Notifications  (" + root.unread + " new)" : "Notifications"
                color: Theme.notifText
                font.family: Theme.notifFont
                font.pixelSize: Theme.notifTitleSize
                font.bold: true
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                // DND toggle pill
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 76
                    height: 26
                    radius: 13
                    color: root.dnd ? "#3a8cff" : "#0dffffff"
                    border.color: Theme.notifBorder
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: root.dnd ? "DND on" : "DND"
                        color: Theme.notifText
                        font.family: Theme.notifFont
                        font.pixelSize: Theme.notifSmallSize
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.dndToggled()
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.history.length > 0
                    text: "Clear all"
                    color: clearHover.containsMouse ? Theme.notifText : Theme.notifDim
                    font.family: Theme.notifFont
                    font.pixelSize: Theme.notifSmallSize
                    MouseArea {
                        id: clearHover
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        onClicked: root.clearRequested()
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: closeHover.containsMouse ? Theme.notifText : Theme.notifDim
                    font.family: Theme.notifFont
                    font.pixelSize: 14
                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        onClicked: root.close()
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.notifDivider
        }

        // ---- now-playing (swaync `mpris` parity) ----
        // Full player card: album art + title/artist + transport controls.
        // Collapses to height 0 when no player advertises a track, and the
        // list below reclaims the space via mediaWrap.height.
        Item {
            id: mediaWrap
            width: parent.width
            height: root.hasMedia ? 96 : 0
            visible: height > 0.5 || mediaCard.opacity > 0.01
            clip: true
            Behavior on height {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                id: mediaCard
                width: parent.width
                // Fixed card height; the wrapper animates 0 <-> card.
                height: 96
                radius: 12
                color: "#202020"
                border.color: Theme.notifBorder
                border.width: 1
                clip: true
                opacity: root.hasMedia ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 72
                        height: 72
                        radius: 8
                        color: "#141414"
                        clip: true
                        visible: root.hasMedia

                        Image {
                            anchors.fill: parent
                            source: root.hasMedia ? (root.activePlayer.trackArtUrl || "") : ""
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            visible: status !== Image.Error && status !== Image.Null
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !root.hasMedia || (root.activePlayer && (root.activePlayer.trackArtUrl || "") === "")
                            text: "♪"
                            color: Theme.notifDim
                            font.pixelSize: 28
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 72 - 12 - 96
                        spacing: 2

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: root.hasMedia ? (root.activePlayer.identity || "Music").toUpperCase() + (root.activePlayer.isPlaying ? "  ·  PLAYING" : "  ·  PAUSED") : ""
                            color: Theme.notifDim
                            font.family: Theme.notifFont
                            font.pixelSize: Theme.notifSmallSize
                            font.bold: true
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: root.hasMedia ? root.activePlayer.trackTitle : ""
                            color: Theme.notifText
                            font.family: Theme.notifFont
                            font.pixelSize: Theme.notifTitleSize
                            font.bold: true
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            text: root.hasMedia ? ([root.activePlayer.trackArtist, root.activePlayer.trackAlbum].filter(function(s) {
                                return s !== "";
                            }).join(" — ")) : ""
                            color: Theme.notifDim
                            font.family: Theme.notifFont
                            font.pixelSize: Theme.notifBodySize
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 96
                        spacing: 4

                        Item {
                            width: 28
                            height: 40
                            Text {
                                anchors.centerIn: parent
                                text: "⏮"
                                color: (root.hasMedia && root.activePlayer.canGoPrevious) ? Theme.notifText : Theme.notifLow
                                font.pixelSize: 18
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: root.hasMedia && root.activePlayer.canGoPrevious
                                onClicked: root.activePlayer.previous()
                            }
                        }
                        Item {
                            width: 32
                            height: 40
                            Text {
                                anchors.centerIn: parent
                                text: (root.hasMedia && root.activePlayer.isPlaying) ? "⏸" : "▶"
                                color: Theme.notifText
                                font.pixelSize: 20
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: root.hasMedia
                                onClicked: root.activePlayer.togglePlaying()
                            }
                        }
                        Item {
                            width: 28
                            height: 40
                            Text {
                                anchors.centerIn: parent
                                text: "⏭"
                                color: (root.hasMedia && root.activePlayer.canGoNext) ? Theme.notifText : Theme.notifLow
                                font.pixelSize: 18
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: root.hasMedia && root.activePlayer.canGoNext
                                onClicked: root.activePlayer.next()
                            }
                        }
                    }
                }
            }
        }

        // Empty state
        Text {
            width: parent.width
            visible: root.history.length === 0
            horizontalAlignment: Text.AlignHCenter
            topPadding: 60
            text: root.dnd ? "Do Not Disturb is on.\nNew notifications wait here quietly." : "All caught up.\nNew notifications land here."
            color: Theme.notifDim
            font.family: Theme.notifFont
            font.pixelSize: Theme.notifBodySize
        }

        ListView {
            width: parent.width
            // Header (30) + divider (1) + column gaps. With media visible the
            // column holds 4 items (3 gaps = 24); without, 3 items (2 gaps).
            height: parent.height - 30 - 1 - mediaWrap.height - (root.hasMedia ? 24 : 16)
            visible: root.history.length > 0
            clip: true
            spacing: 12
            displaced: Transition {
                // Short: followers ride an expanding stack's height
                // frame-synchronously instead of trailing it. Still long
                // enough to glide on insert/remove jumps.
                NumberAnimation {
                    properties: "y"
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
            model: root.groups
            // One group per app: singles render exactly like before; multi
            // stacks show the latest card with older cards peeking behind
            // (macOS style), click fans out to the full list.
            delegate: Item {
                id: groupRoot
                required property var modelData
                required property int index
                width: ListView.view.width
                height: cardsCol.implicitHeight + groupRoot.peekExtra
                // No Behavior here: the wrapper heights below already
                // animate, so this tracks the fan frame-synchronously.
                // A Behavior would chase the moving target (double lag)
                // and let expanding cards paint past the lagging delegate
                // bounds over the follower below.

                readonly property string gkey: modelData.key
                readonly property string gapp: modelData.app
                readonly property var gflats: modelData.items
                readonly property bool gopen: !!root.expandedGroups[modelData.key]
                readonly property bool isStack: gflats.length > 1 && !gopen
                readonly property bool showHeader: gflats.length > 1 && gopen
                // Fan followers: the peek strips ARE cards 2 and 3 unfolding.
                // Each tracks its card wrapper's expand ratio (0 tucked → 1
                // fanned) plus that card's live slot and height, so the strip
                // glides from behind the top card into its notification's
                // place instead of crossfading away. Pure followers — the
                // wrappers drive, so no Behaviors here and no feedback loops
                // (nothing below feeds back into the Column layout).
                readonly property real kFar: (cardsRep.count > 2 && cardsRep.itemAt(2)) ? cardsRep.itemAt(2).expandRatio : 0
                readonly property real kNear: (cardsRep.count > 1 && cardsRep.itemAt(1)) ? cardsRep.itemAt(1).expandRatio : 0
                readonly property real slotFar: (cardsRep.count > 2 && cardsRep.itemAt(2)) ? cardsRep.itemAt(2).y + cardsRep.itemAt(2).gapAbove : 0
                readonly property real slotNear: (cardsRep.count > 1 && cardsRep.itemAt(1)) ? cardsRep.itemAt(1).y + cardsRep.itemAt(1).gapAbove : 0
                readonly property real cardFarH: (cardsRep.count > 2 && cardsRep.itemAt(2)) ? cardsRep.itemAt(2).cardH : 0
                readonly property real cardNearH: (cardsRep.count > 1 && cardsRep.itemAt(1)) ? cardsRep.itemAt(1).cardH : 0
                // Tucked overhang below the top card; shrinks to zero as the
                // cards take their slots.
                readonly property real peekExtra: gflats.length > 2 ? 14 * (1 - groupRoot.kFar) : (gflats.length > 1 ? 7 * (1 - groupRoot.kNear) : 0)

                // Peek cards tucked behind the top card (painted first =
                // bottom). Full card-sized layers nudged down, so only a
                // rounded strip shows below the top card — never a floating
                // sliver poking past the card's corners.
                // Solid fills: the top card is opaque, and translucent peeks
                // would ghost through it — same for the rows.
                Rectangle {
                    id: peekFar
                    visible: groupRoot.gflats.length > 2 && opacity > 0.01
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 14 * (1 - groupRoot.kFar) + groupRoot.slotFar * groupRoot.kFar
                    width: parent.width - 32 * (1 - groupRoot.kFar)
                    height: groupRoot.cardFarH
                    opacity: 1 - groupRoot.kFar
                    radius: 12
                    color: "#202020"
                    border.color: Theme.notifBorder
                    border.width: 1
                }
                Rectangle {
                    id: peekNear
                    visible: groupRoot.gflats.length > 1 && opacity > 0.01
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 7 * (1 - groupRoot.kNear) + groupRoot.slotNear * groupRoot.kNear
                    width: parent.width - 16 * (1 - groupRoot.kNear)
                    height: groupRoot.cardNearH
                    opacity: 1 - groupRoot.kNear
                    radius: 12
                    color: "#202020"
                    border.color: Theme.notifBorder
                    border.width: 1
                }

                // Gaps live inside each wrapper's height (not Column
                // spacing) so the 8px gaps fan with the cards instead of
                // snapping.
                Column {
                    id: cardsCol
                    width: parent.width
                    spacing: 0

                    // Expanded group header: app + count, collapse, drop all.
                    // Wrapper carries the 8px gap below the header in its
                    // height. Leads on expand, trails the cards on collapse.
                    Item {
                        width: parent.width
                        height: groupRoot.showHeader ? 36 : 0
                        opacity: groupRoot.showHeader ? 1 : 0
                        visible: groupRoot.showHeader ? true : (height > 0.5 || opacity > 0.01)
                        clip: true
                        Behavior on height {
                            SequentialAnimation {
                                PauseAnimation {
                                    duration: groupRoot.showHeader ? 0 : groupRoot.gflats.length * 35
                                }
                                NumberAnimation {
                                    duration: 320
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: 12
                        color: "transparent"
                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: (groupRoot.gapp || "Notification").toUpperCase() + "  ·  " + groupRoot.gflats.length
                                color: Theme.notifDim
                                font.family: Theme.notifFont
                                font.pixelSize: Theme.notifSmallSize
                                font.bold: true
                            }
                            Text {
                                anchors.right: gCloseText.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Collapse"
                                color: collapseHover.containsMouse ? Theme.notifText : Theme.notifDim
                                font.family: Theme.notifFont
                                font.pixelSize: Theme.notifSmallSize
                                MouseArea {
                                    id: collapseHover
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    onClicked: root.toggleGroup(groupRoot.gkey)
                                }
                            }
                            Text {
                                id: gCloseText
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "✕"
                                color: gCloseHover.containsMouse ? Theme.notifText : Theme.notifDim
                                font.family: Theme.notifFont
                                font.pixelSize: 12
                                MouseArea {
                                    id: gCloseHover
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    hoverEnabled: true
                                    onClicked: root.removeGroupRequested(groupRoot.gkey)
                                }
                            }
                        }
                        }
                    }

                    Repeater {
                        id: cardsRep
                        model: groupRoot.gflats
                        // Wrapper carries the 8px gap above the card in its
                        // height so gaps fan with the cards. All flats stay
                        // instantiated — i > 0 collapse to height 0 instead
                        // of being destroyed — so both directions animate.
                        // Expand cascades top-down, collapse tucks
                        // bottom-first.
                        delegate: Item {
                            id: cardWrap
                            required property int modelData
                            required property int index
                            readonly property int flat: modelData
                            readonly property bool isFirst: index === 0
                            readonly property bool hidden: groupRoot.isStack && index > 0
                            readonly property int gapAbove: isFirst ? 0 : 8
                            readonly property int fanDelay: hidden ? (cardsRep.count - 1 - index) * 35 : index * 35
                            // Live unfold state for the peek followers above:
                            // card content height (stable) and 0-tucked →
                            // 1-fanned ratio of this wrapper.
                            readonly property real cardH: cardRect.height
                            readonly property real expandRatio: height / Math.max(1, cardH + gapAbove)
                            width: groupRoot.width
                            height: cardWrap.hidden ? 0 : cardRect.height + cardWrap.gapAbove
                            opacity: cardWrap.hidden ? 0 : 1
                            visible: !cardWrap.hidden || height > 0.5 || opacity > 0.01
                            clip: true
                            Behavior on height {
                                SequentialAnimation {
                                    PauseAnimation {
                                        duration: cardWrap.fanDelay
                                    }
                                    NumberAnimation {
                                        duration: 340
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                            Behavior on opacity {
                                SequentialAnimation {
                                    PauseAnimation {
                                        duration: cardWrap.fanDelay
                                    }
                                    NumberAnimation {
                                        duration: 260
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        Rectangle {
                            id: cardRect
                            y: cardWrap.gapAbove
                            readonly property var h: (cardWrap.flat >= 0 && cardWrap.flat < root.history.length) ? root.history[cardWrap.flat] : null
                            readonly property string app: h ? (h.app || "Notification") : "Notification"
                            readonly property string summary: h ? h.summary : ""
                            readonly property string body: h ? h.body : ""
                            readonly property string stamp: h ? h.stamp : ""
                            readonly property bool stackTop: groupRoot.isStack
                            width: groupRoot.width
                            height: itemRow.implicitHeight + 28
                            radius: 12
                            // Solid equivalents of hover/rowBg over the opaque
                            // card (both were translucent and let stacked peeks
                            // ghost through the top card).
                            color: delHover.containsMouse ? "#262626" : "#202020"
                            border.color: Theme.notifBorder
                            border.width: 1
                            clip: true

                            readonly property string imgSrc: {
                                var p = h ? (h.img || "") : "";
                                if (p === "")
                                    return "";
                                return p.indexOf("://") >= 0 ? p : "file://" + p;
                            }

                            // Row hover layer FIRST (bottom of stacking) so it never
                            // swallows presses meant for the close button.
                            // Clicking a peeked stack fans it out.
                            MouseArea {
                                id: delHover
                                anchors.fill: parent
                                hoverEnabled: true
                                onPressed: notifState.log("row press flat=" + cardWrap.flat)
                                onClicked: {
                                    if (cardRect.stackTop)
                                        root.toggleGroup(groupRoot.gkey);
                                }
                            }

                Row {
                    id: itemRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 14
                    spacing: 8

                    Rectangle {
                        anchors.top: parent.top
                        width: visible ? 36 : 0
                        height: 36
                        radius: 8
                        color: "transparent"
                        clip: true
                        visible: cardRect.imgSrc !== "" && itemImg.status !== Image.Error

                        Image {
                            id: itemImg
                            anchors.fill: parent
                            source: cardRect.imgSrc
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

                    Column {
                        width: parent.width - (cardRect.imgSrc !== "" ? 44 : 0)
                        spacing: 10

                    // Header: app + count + stamp + close on one baseline.
                    // Plain Item (never a Row) so every child can use real
                    // anchors — anchors inside a positioner break geometry.
                    Item {
                        width: parent.width
                        height: 18
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40 - 16 - 12 - (cardRect.stackTop ? 30 : 0)
                            elide: Text.ElideRight
                            text: cardRect.app.toUpperCase()
                            color: Theme.notifDim
                            font.family: Theme.notifFont
                            font.pixelSize: Theme.notifSmallSize
                            font.bold: true
                        }
                        Rectangle {
                            visible: cardRect.stackTop
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: stampText.left
                            anchors.rightMargin: 6
                            width: visible ? 24 : 0
                            height: 18
                            radius: 9
                            color: "#1effffff"
                            Text {
                                anchors.centerIn: parent
                                text: groupRoot.gflats.length
                                color: Theme.notifText
                                font.family: Theme.notifFont
                                font.pixelSize: Theme.notifSmallSize
                                font.bold: true
                            }
                        }
                        Text {
                            id: stampText
                            anchors.right: xText.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            horizontalAlignment: Text.AlignRight
                            text: cardRect.stamp
                            color: "#66ffffff"
                            font.family: Theme.notifFont
                            font.pixelSize: Theme.notifSmallSize
                        }
                        Text {
                            id: xText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            horizontalAlignment: Text.AlignHCenter
                            text: "✕"
                            color: delXHover.containsMouse ? Theme.notifText : "#66ffffff"
                            font.family: Theme.notifFont
                            font.pixelSize: 12
                            MouseArea {
                                id: delXHover
                                anchors.fill: parent
                                anchors.margins: -8
                                hoverEnabled: true
                                onPressed: notifState.log("x press flat=" + cardWrap.flat)
                                onClicked: {
                                    if (cardRect.stackTop)
                                        root.removeGroupRequested(groupRoot.gkey);
                                    else
                                        root.removeRequested(cardWrap.flat);
                                }
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: cardRect.summary
                        color: Theme.notifText
                        font.family: Theme.notifFont
                        font.pixelSize: Theme.notifTitleSize
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        text: cardRect.body
                        color: Theme.notifDim
                        font.family: Theme.notifFont
                        font.pixelSize: Theme.notifBodySize
                    }
                    }
                }
                        }
                        }
                    }
                }
            }
        }
    }
}
