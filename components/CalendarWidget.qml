// Shared calendar widget for the date popup and Notification Center.
pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: root
    implicitWidth: 364
    implicitHeight: 350
    radius: 20
    color: "#d92b2b30"
    border.color: "#24ffffff"
    border.width: 1

    property date now: new Date()
    property date selectedDate: new Date()
    property int monthOffset: 0
    readonly property int firstWeekday: Qt.locale().firstDayOfWeek % 7
    readonly property date viewMonth: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)
    readonly property string monthLabel: Qt.formatDate(viewMonth, "MMMM yyyy")
    readonly property string selectedLabel: Qt.formatDate(selectedDate, "dddd, d MMMM")
    signal dateSelected(date value)

    function refresh(): void {
        root.now = new Date();
        rebuild();
    }
    function open(): void {
        root.monthOffset = 0;
        root.selectedDate = new Date();
        refresh();
    }
    function today(): void {
        open();
        root.dateSelected(root.selectedDate);
    }
    function rebuild(): void {
        var first = root.viewMonth;
        var offset = (first.getDay() - root.firstWeekday + 7) % 7;
        days.clear();
        for (var i = 0; i < 42; ++i) {
            var date = new Date(first.getFullYear(), first.getMonth(), i - offset + 1);
            days.append({
                day: date.getDate(),
                month: date.getMonth(),
                year: date.getFullYear(),
                inMonth: date.getMonth() === first.getMonth(),
                isToday: date.toDateString() === root.now.toDateString()
            });
        }
    }
    onMonthOffsetChanged: rebuild()
    Component.onCompleted: refresh()
    ListModel {
        id: days
    }
    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        onTriggered: root.refresh()
    }
    // Consume card clicks so the popup backdrop only handles outside clicks.
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    Column {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 8
        Row {
            width: parent.width
            height: 42
            spacing: 10
            Text {
                text: Qt.formatDate(root.now, "d")
                color: "#ff6961"
                font.family: "sans-serif"
                font.pixelSize: 36
                font.weight: Font.Light
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: Qt.formatDate(root.now, "dddd")
                    color: "#f5f5f7"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    text: Qt.formatDate(root.now, "MMMM yyyy")
                    color: "#b9b9bf"
                    font.pixelSize: 11
                }
            }
        }
        Item {
            width: parent.width
            height: 28
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.monthLabel
                color: "#f5f5f7"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Row {
                anchors.right: parent.right
                spacing: 3
                Repeater {
                    model: ["‹", "Today", "›"]
                    delegate: Rectangle {
                        required property int index
                        required property string modelData
                        width: index === 1 ? 50 : 28
                        height: 28
                        radius: 7
                        color: nav.containsMouse ? "#24ffffff" : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: "#e8e8ed"
                            font.pixelSize: parent.index === 1 ? 11 : 22
                        }
                        MouseArea {
                            id: nav
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (parent.index === 1)
                                    root.today();
                                else
                                    root.monthOffset += parent.index === 0 ? -1 : 1;
                            }
                        }
                    }
                }
            }
        }
        Row {
            width: parent.width
            height: 18
            Repeater {
                model: 7
                delegate: Text {
                    required property int index
                    width: (root.width - 36) / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().standaloneDayName(((root.firstWeekday + index + 6) % 7) + 1, Locale.ShortFormat).slice(0, 2)
                    color: "#9c9ca5"
                    font.pixelSize: 10
                }
            }
        }
        Grid {
            width: parent.width
            columns: 7
            Repeater {
                model: days
                delegate: Item {
                    id: cell
                    required property int day
                    required property int month
                    required property int year
                    required property bool inMonth
                    required property bool isToday
                    readonly property bool selected: root.selectedDate.getFullYear() === year && root.selectedDate.getMonth() === month && root.selectedDate.getDate() === day
                    width: (root.width - 36) / 7
                    height: 28
                    Rectangle {
                        anchors.centerIn: parent
                        width: 27
                        height: 27
                        radius: 14
                        color: cell.isToday ? "#ff6961" : cell.selected ? "#35ffffff" : dayMouse.containsMouse ? "#20ffffff" : "transparent"
                        border.width: cell.selected && !cell.isToday ? 1 : 0
                        border.color: "#80ffffff"
                        Text {
                            anchors.centerIn: parent
                            text: cell.day
                            color: cell.isToday ? "white" : cell.inMonth ? "#efeff4" : "#73737c"
                            font.pixelSize: 12
                            font.weight: cell.isToday ? Font.Bold : Font.Normal
                        }
                    }
                    MouseArea {
                        id: dayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedDate = new Date(cell.year, cell.month, cell.day);
                            var offset = (cell.year - root.now.getFullYear()) * 12 + cell.month - root.now.getMonth();
                            root.monthOffset = offset;
                            root.dateSelected(root.selectedDate);
                        }
                    }
                }
            }
        }
        Text {
            width: parent.width
            text: root.selectedLabel
            horizontalAlignment: Text.AlignHCenter
            color: "#b9b9bf"
            font.pixelSize: 11
        }
    }
}
