// Notification Center: grouped cards and widgets on a floating glass sheet.
pragma ComponentBehavior: Bound
import QtQuick
import "../theme"

Rectangle {
    id: root
    required property var history
    property bool dnd: false
    property int unread: 0
    property real progress: 0
    property bool exiting: false
    property var expandedGroups: ({})
    readonly property real frameW: 400
    readonly property real frameH: 700
    signal hideRequested
    signal clearRequested
    signal removeRequested(int index)
    signal removeGroupRequested(string appKey)
    signal dndToggled

    color: Glass.panel
    radius: Glass.radius
    border.width: 1
    border.color: Glass.stroke
    clip: true
    opacity: progress
    transform: Translate {
        x: (1 - root.progress) * 48
    }
    focus: true

    function open(): void {
        exiting = false;
        entrance.to = 1;
        entrance.start();
        calendar.refresh();
        forceActiveFocus();
    }
    function close(): void {
        if (exiting)
            return;
        exiting = true;
        entrance.to = 0;
        entrance.start();
    }
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
    NumberAnimation {
        id: entrance
        target: root
        property: "progress"
        duration: 240
        easing.type: Easing.OutCubic
        onFinished: if (root.exiting) {
            root.exiting = false;
            root.hideRequested();
        }
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
                color: Glass.text
                font.family: Glass.font
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
            Rectangle {
                anchors.right: parent.right
                width: 28
                height: 28
                radius: 14
                color: closeHover.containsMouse ? Glass.hover : Glass.card
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: Glass.secondary
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
            color: Glass.card
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Text {
                    text: "☾"
                    color: root.dnd ? Glass.accent : Glass.text
                    font.pixelSize: 23
                }
                Column {
                    Text {
                        text: "Do Not Disturb"
                        color: Glass.text
                        font.family: Glass.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: root.dnd ? "Notifications delivered quietly" : "Allow notifications"
                        color: Glass.secondary
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
                color: root.dnd ? Glass.accent : "#65708090"
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    y: 2
                    x: root.dnd ? 16 : 2
                    color: "white"
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
                        color: Glass.secondary
                        font.family: Glass.font
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clear All"
                        visible: root.history.length > 0
                        color: clearHover.containsMouse ? Glass.text : Glass.secondary
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
                    color: Glass.card
                    visible: root.history.length === 0
                    Text {
                        anchors.centerIn: parent
                        text: "No Notifications"
                        color: Glass.secondary
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
                                color: Glass.secondary
                                font.family: Glass.font
                                font.pixelSize: 11
                            }
                            Text {
                                anchors.right: parent.right
                                text: "Show Less"
                                color: Glass.secondary
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
                                Rectangle {
                                    id: card
                                    width: parent.width
                                    height: entry.index === 0 ? Math.max(76, row.implicitHeight + 24)
                                            : group.firstHeight * (1 - group.expansion)
                                              + Math.max(76, row.implicitHeight + 24) * group.expansion
                                    Behavior on height {
                                        enabled: entry.index === 0 && root.visible && group.expansion > 0
                                        NumberAnimation { duration: 360; easing.type: Easing.OutCubic }
                                    }
                                    radius: 18
                                    color: cardHover.containsMouse ? "#f0404248"
                                           : entry.index > 0 && group.expansion < 1 ? "#ee454950" : "#ee303238"
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                    border.color: Glass.stroke
                                    border.width: 1
                                    MouseArea {
                                        id: cardHover
                                        anchors.fill: parent
                                        hoverEnabled: true
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
                                            color: "#535863"
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
                                                color: Glass.text
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
                                                    color: Glass.secondary
                                                    font.family: Glass.font
                                                    font.pixelSize: 10
                                                    font.weight: Font.DemiBold
                                                }
                                                Text {
                                                    anchors.right: parent.right
                                                    text: entry.stack ? group.modelData.items.length + " notifications" : (entry.h.stamp || "now")
                                                    color: Glass.secondary
                                                    font.family: Glass.font
                                                    font.pixelSize: 10
                                                }
                                            }
                                            Text {
                                                width: parent.width
                                                text: entry.h.summary || ""
                                                textFormat: Text.PlainText
                                                color: Glass.text
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
                                                color: Glass.text
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
                                                        color: actionHover.containsMouse ? Glass.hover : Glass.card
                                                        Text {
                                                            id: actionLabel
                                                            anchors.centerIn: parent
                                                            width: Math.min(implicitWidth, 210)
                                                            elide: Text.ElideRight
                                                            text: action.modelData.text
                                                            textFormat: Text.PlainText
                                                            color: Glass.text
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
                                        color: "#6c6e74"
                                        visible: (entry.index === 0 || group.expanded)
                                                 && (cardHover.containsMouse || dismissHover.containsMouse)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "×"
                                            color: "white"
                                            font.pixelSize: 17
                                        }
                                        MouseArea {
                                            id: dismissHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: entry.stack ? root.removeGroupRequested(group.modelData.key) : root.removeRequested(entry.modelData)
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
            width: parent.width
            height: implicitHeight
        }
    }
}
