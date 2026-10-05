// Dynamic-Island clock/calendar card.
// Lives in a fullscreen transparent PanelWindow (see shell.qml islandWin).
// open() runs one continuous dot→card morph; close() shrinks it back and
// emits hideRequested so the shell can hide the window.
pragma ComponentBehavior: Bound
import QtQuick

import "../theme"

Rectangle {
    id: root
    color: Theme.islandBg
    // Single continuous morph: every dimension is a function of `progress`
    // (0 dot → 1 full card), driven by exactly one animation. Radius blends
    // from a perfect circle into the card corner — no staged retargets.
    radius: (1 - root.progress) * Math.min(root.width, root.height) / 2 + root.progress * Theme.islandRadiusExpanded
    border.color: Theme.islandBorder
    border.width: 1
    clip: true

    signal hideRequested()

    // 0 = dot, 1 = full card. Animated once per open (OutExpo: fast
    // expansion, soft landing — the Dynamic Island feel).
    property real progress: 0
    property bool exiting: false
    property int monthOffset: 0
    property date now: new Date()

    readonly property real frameW: Theme.islandDot + (Theme.islandExpandedW - Theme.islandDot) * root.progress
    readonly property real frameH: Theme.islandDot + (Theme.islandExpandedH - Theme.islandDot) * root.progress
    // Contents fade in over the final stretch of the morph only.
    readonly property real contentOpacity: Math.min(1, Math.max(0, (root.progress - 0.8) / 0.2))

    ListModel {
        id: calModel
    }

    // Live clock strings (manual formatting — locale-independent)
    readonly property string bigTime: {
        var h = now.getHours();
        var h12 = h % 12;
        if (h12 === 0)
            h12 = 12;
        var m = now.getMinutes();
        return (h12 < 10 ? "0" + h12 : "" + h12) + ":" + (m < 10 ? "0" + m : "" + m);
    }
    readonly property string ampm: now.getHours() < 12 ? "AM" : "PM"
    readonly property string seconds: (now.getSeconds() < 10 ? "0" : "") + now.getSeconds()
    readonly property string dayName: Qt.formatDate(now, "dddd")
    readonly property string fullDate: Qt.formatDate(now, "d MMMM yyyy")
    readonly property string viewLabel: {
        var v = new Date(now.getFullYear(), now.getMonth() + monthOffset, 1);
        return Qt.formatDate(v, "MMMM yyyy");
    }
    readonly property real dayFrac: (now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds()) / 86400

    function open(): void {
        morphOut.stop();
        root.exiting = false;
        root.monthOffset = 0;
        root.rebuild();
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

    function rebuild(): void {
        var v = new Date(now.getFullYear(), now.getMonth() + monthOffset, 1);
        var vy = v.getFullYear(), vm = v.getMonth();
        var startDay = (v.getDay() + 6) % 7; // Monday-first
        calModel.clear();
        for (var i = 0; i < 42; i++) {
            var cd = new Date(vy, vm, i - startDay + 1);
            calModel.append({
                d: cd.getDate(),
                inMonth: cd.getMonth() === vm,
                isToday: cd.getFullYear() === now.getFullYear() && cd.getMonth() === now.getMonth() && cd.getDate() === now.getDate()
            });
        }
    }

    onMonthOffsetChanged: rebuild()

    Component.onCompleted: rebuild()

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            var rolled = d.getFullYear() !== root.now.getFullYear() || d.getMonth() !== root.now.getMonth() || d.getDate() !== root.now.getDate();
            root.now = d;
            if (rolled)
                root.rebuild();
        }
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
        } else if (event.key === Qt.Key_Left) {
            root.monthOffset--;
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            root.monthOffset++;
            event.accepted = true;
        } else if (event.key === Qt.Key_T) {
            root.monthOffset = 0;
            event.accepted = true;
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
            color: Theme.islandAccent

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

    // ---- expanded card: hero clock + month calendar ----
    Column {
        id: cardView
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.islandPadding
        spacing: 10
        opacity: root.contentOpacity
        enabled: root.progress > 0.85
        visible: opacity > 0

        // Hero: big time left, date right — no dead space
        Item {
            width: parent.width
            height: 92

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Text {
                    anchors.bottom: parent.bottom
                    text: root.bigTime
                    color: Theme.islandText
                    font.family: Theme.islandFont
                    font.pixelSize: Theme.islandHeroSize
                    font.bold: true
                }
                Column {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    Text {
                        text: root.ampm
                        color: Theme.islandText
                        font.family: Theme.islandFont
                        font.pixelSize: Theme.islandSubSize
                        font.bold: true
                    }
                    Text {
                        text: ":" + root.seconds
                        color: Theme.islandDim
                        font.family: Theme.islandFont
                        font.pixelSize: Theme.islandSubSize
                    }
                }
            }

            Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    anchors.right: parent.right
                    text: root.dayName
                    color: Theme.islandText
                    font.family: Theme.islandFont
                    font.pixelSize: 17
                    font.bold: true
                }
                Text {
                    anchors.right: parent.right
                    text: root.fullDate
                    color: Theme.islandDim
                    font.family: Theme.islandFont
                    font.pixelSize: Theme.islandSmallSize
                }
            }
        }

        // Day-progress bar (thin live activity strip)
        Rectangle {
            width: parent.width
            height: 3
            radius: 1.5
            color: "#1effffff"
            Rectangle {
                width: parent.width * root.dayFrac
                height: parent.height
                radius: 1.5
                color: Theme.islandAccent
                Behavior on width {
                    NumberAnimation {
                        duration: 900
                        easing.type: Easing.Linear
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#14ffffff"
        }

        // Month nav
        Item {
            width: parent.width
            height: 28
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "‹"
                    color: prevHover.containsMouse ? Theme.islandText : Theme.islandDim
                    font.family: Theme.islandFont
                    font.pixelSize: 20
                    MouseArea {
                        id: prevHover
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        onClicked: root.monthOffset--
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.viewLabel
                    color: Theme.islandText
                    font.family: Theme.islandFont
                    font.pixelSize: Theme.islandBodySize
                    font.bold: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    color: nextHover.containsMouse ? Theme.islandText : Theme.islandDim
                    font.family: Theme.islandFont
                    font.pixelSize: 20
                    MouseArea {
                        id: nextHover
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        onClicked: root.monthOffset++
                    }
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                height: 26
                radius: 13
                color: todayHover.containsMouse ? "#1effffff" : "#0dffffff"
                border.color: Theme.islandBorder
                border.width: 1
                visible: root.monthOffset !== 0
                Text {
                    anchors.centerIn: parent
                    text: "Today"
                    color: Theme.islandText
                    font.family: Theme.islandFont
                    font.pixelSize: Theme.islandSmallSize
                    font.bold: true
                }
                MouseArea {
                    id: todayHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.monthOffset = 0
                }
            }
        }

        // Weekday header (Monday-first)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                delegate: Text {
                    required property string modelData
                    width: 44
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.islandDim
                    font.family: Theme.islandFont
                    font.pixelSize: Theme.islandSmallSize
                    font.bold: true
                }
            }
        }

        // Month grid — always 6 rows so the card never resizes mid-spring
        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 7
            rows: 6
            columnSpacing: 4
            rowSpacing: 2
            Repeater {
                model: calModel
                delegate: Item {
                    required property int d
                    required property bool inMonth
                    required property bool isToday
                    width: 44
                    height: 30
                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: isToday ? Theme.islandTodayBg : (dayHover.containsMouse && inMonth ? Theme.islandHover : "transparent")
                        Text {
                            anchors.centerIn: parent
                            text: d
                            color: isToday ? Theme.islandTodayText : (inMonth ? Theme.islandText : "#55ffffff")
                            font.family: Theme.islandFont
                            font.pixelSize: Theme.islandBodySize
                            font.bold: isToday
                        }
                    }
                    MouseArea {
                        id: dayHover
                        anchors.fill: parent
                        hoverEnabled: true
                        // Clicking a filler day flips to that month,
                        // like every native calendar.
                        onClicked: {
                            if (!inMonth) {
                                if (d > 15)
                                    root.monthOffset--;
                                else
                                    root.monthOffset++;
                            }
                        }
                    }
                }
            }
        }
    }
}
