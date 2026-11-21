// Notification Center: grouped cards and widgets on a floating glass sheet.
pragma ComponentBehavior: Bound
import QtQuick
import "../theme"

IslandPanel {
    id: root
    required property var history
    property bool dnd: false
    property int unread: 0
    property var expandedGroups: ({})
    readonly property real frameW: 400
    readonly property real frameH: 900
    signal clearRequested
    signal removeRequested(int index)
    signal removeGroupRequested(string appKey)
    signal dndToggled

    panelColor: Theme.islandBg
    expandedRadius: Glass.radius
    panelBorder: Theme.islandBorder
    clip: true
    focus: true

    onOpening: calendar.refresh()
    function toggleGroup(key): void {
        var next = Object.assign({}, expandedGroups);
        next[key] = !next[key];
        expandedGroups = next;
    }
    function invokeDefault(h): void {
        if (!h || !h.note)
            return;
        var actions = h.note.actions;
        for (var i = 0; i < actions.length; i++) {
            if (actions[i].identifier === "default") {
                actions[i].invoke();
                close();
                return;
            }
        }
    }
    readonly property var groups: {
        var output = [];
        for (var i = 0; i < history.length; i++) {
            var h = history[i];
            var key = ((h.app || "Notification") + "").toLowerCase();
            var group = null;
            for (var j = 0; j < output.length; j++) {
                if (output[j].key === key) {
                    group = output[j];
                    break;
                }
            }
            if (group === null) {
                group = {
                    key: key,
                    app: h.app || "Notification",
                    items: []
                };
                output.push(group);
            }
            group.items.push(i);
        }
        return output;
    }
    Keys.onEscapePressed: close()
    // Consume inside clicks; the shell owns the outside-click backdrop.
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    Column {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14
        Item {
            width: parent.width
            height: 32
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Notification Center"
                color: Theme.islandText
                font.family: Glass.font
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
            Rectangle {
                anchors.right: parent.right
                width: 28
                height: 28
                radius: 14
                color: closeHover.containsMouse ? Theme.islandHover : Theme.notifRowBg
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: Theme.islandDim
                    font.pixelSize: 20
                }
                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.close()
                }
            }
        }
        Rectangle {
            width: parent.width
            height: 50
            radius: 16
            color: Theme.notifRowBg
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Text {
                    text: "☾"
                    color: root.dnd ? Theme.islandAccent : Theme.islandText
                    font.pixelSize: 23
                }
                Column {
                    Text {
                        text: "Do Not Disturb"
                        color: Theme.islandText
                        font.family: Glass.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: root.dnd ? "Notifications delivered quietly" : "Allow notifications"
                        color: Theme.islandDim
                        font.family: Glass.font
                        font.pixelSize: 10
                    }
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 20
                radius: 10
                color: root.dnd ? Theme.islandAccent : Theme.islandHover
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    y: 2
                    x: root.dnd ? 16 : 2
                    color: root.dnd ? Theme.islandTodayText : Theme.islandText
                    Behavior on x {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.dndToggled()
            }
        }
        Flickable {
            id: notificationList
            width: parent.width
            height: Math.max(0, parent.height - 124 - calendar.height)
            contentHeight: contents.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            Column {
                id: contents
                width: parent.width
                spacing: 14
                Item {
                    width: parent.width
                    height: 24
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Notifications"
                        color: Theme.islandDim
                        font.family: Glass.font
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clear All"
                        visible: root.history.length > 0
                        color: clearHover.containsMouse ? Theme.islandText : Theme.islandDim
                        font.family: Glass.font
                        font.pixelSize: 12
                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            anchors.margins: -5
                            hoverEnabled: true
                            onClicked: root.clearRequested()
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 74
                    radius: 18
                    color: Theme.notifRowBg
                    visible: root.history.length === 0
                    Text {
                        anchors.centerIn: parent
                        text: "No Notifications"
                        color: Theme.islandDim
                        font.family: Glass.font
                        font.pixelSize: 14
                    }
                }
                Repeater {
                    model: root.groups
                    delegate: Item {
                        id: group
                        required property var modelData
                        width: contents.width
                        readonly property bool expanded: !!root.expandedGroups[modelData.key]
                        readonly property bool stacked: modelData.items.length > 1 && !expanded
                        property real expansion: expanded ? 1 : 0
                        readonly property real firstHeight: entries.count && entries.itemAt(0) ? entries.itemAt(0).height : 0
                        readonly property real expandedHeight: {
                            let total = 0;
                            for (let i = 0; i < entries.count; i++) {
                                const item = entries.itemAt(i);
                                if (item) total += item.height + (i ? 7 : 0);
                            }
                            return total;
                        }
                        height: groupTitle.height + 7 * expansion + firstHeight
                                + (expandedHeight - firstHeight) * expansion
                                + (modelData.items.length > 1 ? 10 * (1 - expansion) : 0)
                        Behavior on expansion {
                            NumberAnimation {
                                duration: 360
                                easing.type: Easing.OutCubic
                            }
                        }
                        Item {
                            id: groupTitle
                            width: parent.width
                            height: group.modelData.items.length > 1 ? 22 * group.expansion : 0
                            opacity: group.expansion
                            visible: height > 0
                            enabled: group.expanded
                            Text {
                                anchors.left: parent.left
                                textFormat: Text.PlainText
                                text: group.modelData.app
                                color: Theme.islandDim
                                font.family: Glass.font
                                font.pixelSize: 11
                            }
                            Text {
                                anchors.right: parent.right
                                text: "Show Less"
                                color: Theme.islandDim
                                font.family: Glass.font
                                font.pixelSize: 11
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    onClicked: root.toggleGroup(group.modelData.key)
                                }
                            }
                        }
                        Repeater {
                            id: entries
                            model: group.modelData.items
                            delegate: Item {
                                id: entry
                                required property int index
                                required property int modelData
                                readonly property var h: root.history[modelData] || ({})
                                readonly property bool stack: group.stacked
                                readonly property var swipeLeader: stack && index > 0 ? entries.itemAt(0) : entry
                                readonly property real swipeDistance: group.width * 0.62
                                property real swipeX: 0
                                property bool dismissing: false
                                readonly property real expandedY: {
                                    let offset = 0;
                                    for (let i = 0; i < index; i++) {
                                        const previous = entries.itemAt(i);
                                        if (previous) offset += previous.height + 7;
                                    }
                                    return offset;
                                }
                                x: Math.min(index, 2) * 6 * (1 - group.expansion)
                                y: groupTitle.height + 7 * group.expansion
                                   + Math.min(index, 2) * 5 * (1 - group.expansion)
                                   + expandedY * group.expansion
                                width: group.width - x * 2
                                height: card.height
                                opacity: index < 3 ? 1 : group.expansion
                                visible: opacity > 0
                                enabled: index === 0 || group.expanded
                                z: group.modelData.items.length - index

                                function dismiss(): void {
                                    if (stack)
                                        root.removeGroupRequested(group.modelData.key);
                                    else
                                        root.removeRequested(modelData);
                                }

                                function settleSwipe(released: bool): void {
                                    dismissing = released && Math.abs(swipeX) >= Math.min(110, swipeDistance / 2);
                                    swipeAnimation.to = dismissing ? Math.sign(swipeX) * swipeDistance : 0;
                                    swipeAnimation.start();
                                }

                                DragHandler {
                                    target: null
                                    yAxis.enabled: false
                                    enabled: !swipeAnimation.running && !entry.dismissing
                                    cursorShape: Qt.ClosedHandCursor
                                    onActiveTranslationChanged: if (active) entry.swipeX = activeTranslation.x
                                    onGrabChanged: function (transition, point) {
                                        if (transition === PointerDevice.UngrabExclusive)
                                            entry.settleSwipe(true);
                                        else if (transition === PointerDevice.CancelGrabExclusive)
                                            entry.settleSwipe(false);
                                    }
                                }
                                NumberAnimation {
                                    id: swipeAnimation
                                    target: entry
                                    property: "swipeX"
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                    onFinished: if (entry.dismissing) entry.dismiss()
                                }

                                Rectangle {
                                    id: card
                                    readonly property real dragOffset: entry.swipeLeader ? entry.swipeLeader.swipeX : 0
                                    enabled: !entry.dismissing
                                    width: parent.width
                                    height: entry.index === 0 ? Math.max(76, row.implicitHeight + 24)
                                            : group.firstHeight * (1 - group.expansion)
                                              + Math.max(76, row.implicitHeight + 24) * group.expansion
                                    Behavior on height {
                                        enabled: entry.index === 0 && root.visible && group.expansion > 0
                                        NumberAnimation { duration: 360; easing.type: Easing.OutCubic }
                                    }
                                    radius: 18
                                    transform: Translate { x: card.dragOffset }
                                    opacity: 1 - Math.min(1, Math.abs(dragOffset) / Math.max(1, entry.swipeDistance))
                                    color: Qt.tint(Theme.islandBg, (cardHover.hovered && dragOffset === 0)
                                                   || (entry.index > 0 && group.expansion < 1) ? Theme.islandHover : Theme.notifRowBg)
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                    border.color: Theme.islandBorder
                                    border.width: 1
                                    HoverHandler {
                                        id: cardHover
                                        blocking: false
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: entry.stack ? root.toggleGroup(group.modelData.key) : root.invokeDefault(entry.h)
                                    }
                                    Row {
                                        id: row
                                        opacity: entry.index === 0 ? 1 : group.expansion
                                        x: 12
                                        y: 12
                                        width: parent.width - 24
                                        spacing: 10
                                        Rectangle {
                                            width: 36
                                            height: 36
                                            radius: 9
                                            color: Theme.islandHover
                                            Image {
                                                id: artwork
                                                anchors.fill: parent
                                                source: entry.h.img || ""
                                                fillMode: Image.PreserveAspectFit
                                                visible: status === Image.Ready
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                visible: !artwork.visible
                                                text: (entry.h.app || "N").charAt(0).toUpperCase()
                                                font.family: Glass.font
                                                font.pixelSize: 18
                                                font.weight: Font.DemiBold
                                                color: Theme.islandText
                                            }
                                        }
                                        Column {
                                            width: parent.width - 46
                                            spacing: 3
                                            Item {
                                                width: parent.width
                                                height: 15
                                                Text {
                                                    width: parent.width - 70
                                                    elide: Text.ElideRight
                                                    text: entry.h.app || "Notification"
                                                    textFormat: Text.PlainText
                                                    color: Theme.islandDim
                                                    font.family: Glass.font
                                                    font.pixelSize: 10
                                                    font.weight: Font.DemiBold
                                                }
                                                Text {
                                                    anchors.right: parent.right
                                                    text: entry.stack ? group.modelData.items.length + " notifications" : (entry.h.stamp || "now")
                                                    color: Theme.islandDim
                                                    font.family: Glass.font
                                                    font.pixelSize: 10
                                                }
                                            }
                                            Text {
                                                width: parent.width
                                                text: entry.h.summary || ""
                                                textFormat: Text.PlainText
                                                color: Theme.islandText
                                                font.family: Glass.font
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                width: parent.width
                                                text: entry.h.body || ""
                                                textFormat: Text.PlainText
                                                visible: text !== ""
                                                color: Theme.islandText
                                                font.family: Glass.font
                                                font.pixelSize: 12
                                                wrapMode: Text.Wrap
                                                maximumLineCount: group.expanded ? 12 : 3
                                                elide: Text.ElideRight
                                            }
                                            Flow {
                                                width: parent.width
                                                spacing: 4
                                                visible: !entry.stack
                                                Repeater {
                                                    model: entry.h.note ? entry.h.note.actions : []
                                                    delegate: Rectangle {
                                                        id: action
                                                        required property var modelData
                                                        visible: modelData.identifier !== "default"
                                                        width: visible ? Math.min(actionLabel.implicitWidth + 20, 230) : 0
                                                        height: visible ? 26 : 0
                                                        radius: 8
                                                        color: actionHover.containsMouse ? Theme.islandHover : Theme.notifRowBg
                                                        Text {
                                                            id: actionLabel
                                                            anchors.centerIn: parent
                                                            width: Math.min(implicitWidth, 210)
                                                            elide: Text.ElideRight
                                                            text: action.modelData.text
                                                            textFormat: Text.PlainText
                                                            color: Theme.islandText
                                                            font.family: Glass.font
                                                            font.pixelSize: 11
                                                        }
                                                        MouseArea {
                                                            id: actionHover
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            onClicked: {
                                                                action.modelData.invoke();
                                                                root.close();
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Rectangle {
                                        x: 4
                                        y: 4
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: Qt.tint(Theme.islandBg, Theme.islandHover)
                                        visible: entry.enabled && cardHover.hovered && card.dragOffset === 0
                                        Text {
                                            anchors.centerIn: parent
                                            text: "×"
                                            color: Theme.islandText
                                            font.pixelSize: 17
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: entry.dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        CalendarWidget {
            id: calendar
            compact: true
            width: parent.width
            height: implicitHeight
        }
    }
}
