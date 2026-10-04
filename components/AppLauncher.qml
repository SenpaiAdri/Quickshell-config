// App launcher: modern rofi drun replacement.
// Exposes open() so the shell can reset + focus on show; emits hideRequested on dismiss/launch.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets

import "../theme"

Rectangle {
    id: root
    color: Theme.launcherBg
    radius: Theme.launcherRadius
    border.color: Theme.launcherBorder
    border.width: 1

    signal hideRequested()

    property string query: ""
    property int selected: 0
    property int resultCount: filtered.count

    ListModel {
        id: filtered
    }

    function open(): void {
        root.query = "";
        searchInput.text = "";
        root.selected = 0;
        rebuild();
        searchInput.forceActiveFocus();
    }

    function score(name: string, q: string): int {
        var n = name.toLowerCase();
        var needle = q.toLowerCase().trim();
        if (needle === "")
            return 1000;
        if (n === needle)
            return 3000;
        if (n.startsWith(needle))
            return 2000;
        if (n.includes(needle))
            return 1500;
        // subsequence fuzzy: all chars in order
        var ni = 0;
        for (var i = 0; i < n.length && ni < needle.length; i++) {
            if (n[i] === needle[ni])
                ni++;
        }
        if (ni === needle.length)
            return 1000 - n.length;
        return -1;
    }

    function rebuild(): void {
        var q = root.query;
        var scored = [];
        var apps = DesktopEntries.applications.values;
        for (var i = 0; i < apps.length; i++) {
            var app = apps[i];
            if (app.noDisplay)
                continue;
            var s = score(app.name, q);
            if (s < 0) {
                // also try genericName / keywords so "browser" finds Brave etc.
                var alt = (app.genericName || "") + " " + (app.keywords ? app.keywords.join(" ") : "");
                if (alt.trim() !== "")
                    s = score(app.name + " " + alt, q);
                if (s < 0)
                    continue;
            }
            scored.push({
                entryId: app.id,
                name: app.name,
                comment: app.comment || app.genericName || "",
                icon: app.icon || "",
                rank: s
            });
        }
        scored.sort(function(a, b) {
            if (a.rank !== b.rank)
                return b.rank - a.rank;
            return a.name.localeCompare(b.name);
        });
        filtered.clear();
        var cap = Math.min(scored.length, 8);
        for (var j = 0; j < cap; j++)
            filtered.append(scored[j]);
        if (root.selected >= filtered.count)
            root.selected = Math.max(0, filtered.count - 1);
    }

    function launchCurrent(): void {
        if (filtered.count === 0)
            return;
        var idx = Math.max(0, Math.min(root.selected, filtered.count - 1));
        var entryId = filtered.get(idx).entryId;
        var entry = DesktopEntries.byId(entryId);
        if (entry)
            entry.execute();
        root.hideRequested();
    }

    function launchAt(idx: int): void {
        if (idx < 0 || idx >= filtered.count)
            return;
        var entry = DesktopEntries.byId(filtered.get(idx).entryId);
        if (entry)
            entry.execute();
        root.hideRequested();
    }

    onQueryChanged: {
        rebuild();
        root.selected = 0;
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged(): void {
            root.rebuild();
        }
    }

    Component.onCompleted: rebuild()

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.hideRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier))) {
            root.selected = Math.min(filtered.count - 1, root.selected + 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))) {
            root.selected = Math.max(0, root.selected - 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.launchCurrent();
            event.accepted = true;
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.launcherPadding
        spacing: 8

        // Search bar
        Rectangle {
            width: parent.width
            height: 48
            radius: 12
            color: "#0dffffff"
            border.color: "#33ffffff"
            border.width: 1

            Item {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14

                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: Theme.launcherDim
                    font.pixelSize: 16
                }

                TextInput {
                    id: searchInput
                    anchors.left: searchIcon.right
                    anchors.right: escHint.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.launcherText
                    selectionColor: "#66ffffff"
                    font.family: Theme.launcherFont
                    font.pixelSize: Theme.launcherBodySize
                    focus: true
                    onTextChanged: root.query = text
                    onAccepted: root.launchCurrent()
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Down) {
                            root.selected = Math.min(filtered.count - 1, root.selected + 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            root.selected = Math.max(0, root.selected - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.hideRequested();
                            event.accepted = true;
                        }
                        // Return/Enter falls through to onAccepted -> launch
                    }
                }

                Text {
                    anchors.left: searchInput.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text === ""
                    text: "Search apps…"
                    color: "#66ffffff"
                    font.family: Theme.launcherFont
                    font.pixelSize: Theme.launcherBodySize
                }

                Text {
                    id: escHint
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "esc"
                    color: Theme.launcherDim
                    font.family: Theme.launcherFont
                    font.pixelSize: Theme.launcherSmallSize
                    opacity: 0.7
                }
            }
            // Clicking empty area focuses the input (behind text entry so typing still works)
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: searchInput.forceActiveFocus()
            }
        }

        // Results
        ListView {
            id: list
            width: parent.width
            height: Math.max(0, parent.height - 48 - 8)
            clip: true
            spacing: 2
            model: filtered
            currentIndex: root.selected
            highlightMoveDuration: 120
            delegate: Rectangle {
                id: row
                required property string entryId
                required property string name
                required property string comment
                required property string icon
                required property int index

                readonly property bool isSelected: row.index === root.selected

                width: list.width
                height: Theme.launcherRowHeight
                radius: Theme.launcherRowRadius
                color: isSelected ? Theme.launcherRowSelected : (rowMouse.containsMouse ? Theme.launcherRowHover : "transparent")
                border.color: isSelected ? "#33ffffff" : "transparent"
                border.width: 1

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selected = row.index
                    onClicked: root.launchAt(row.index)
                }

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        source: Quickshell.iconPath(row.icon, true)
                        asynchronous: true
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 28 - 12 - 20
                        spacing: 1

                        Text {
                            width: parent.width
                            text: row.name
                            elide: Text.ElideRight
                            color: Theme.launcherText
                            font.family: Theme.launcherFont
                            font.pixelSize: Theme.launcherBodySize
                            font.bold: row.isSelected
                        }
                        Text {
                            width: parent.width
                            visible: row.comment !== ""
                            text: row.comment
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            color: Theme.launcherDim
                            font.family: Theme.launcherFont
                            font.pixelSize: Theme.launcherSmallSize
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.isSelected
                        text: "↵"
                        color: Theme.launcherDim
                        font.pixelSize: 14
                    }
                }
            }
        }

        Text {
            visible: filtered.count === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "No apps found"
            color: Theme.launcherDim
            font.family: Theme.launcherFont
            font.pixelSize: Theme.launcherBodySize
        }
    }
}
