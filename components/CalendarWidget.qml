// Month calendar for Notification Center.
pragma ComponentBehavior: Bound
import QtQuick
import "../theme"

Rectangle {
    id: root
    property bool compact: false
    readonly property int inset: compact ? 14 : 18
    implicitWidth: 364
    implicitHeight: content.implicitHeight + 2 * inset
    radius: 20
    color: Qt.tint(Theme.islandBg, Theme.notifRowBg)
    border.color: Theme.islandBorder
    border.width: 1

    property date now: new Date()
    property date selectedDate: new Date()
    property int monthOffset: 0
    readonly property int firstWeekday: Qt.locale().firstDayOfWeek % 7
    readonly property date viewMonth: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)
    readonly property string monthLabel: Qt.formatDate(viewMonth, "MMMM yyyy")
    readonly property bool canReturnToToday: monthOffset !== 0 || selectedDate.toDateString() !== now.toDateString()
    readonly property bool selectionInView: selectedDate.getFullYear() === viewMonth.getFullYear()
        && selectedDate.getMonth() === viewMonth.getMonth()
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
    onViewMonthChanged: rebuild()
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
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.inset }
        spacing: root.compact ? 6 : 8

        Item {
            width: content.width
            height: root.compact ? 36 : 42

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(root.selectedDate, "d")
                    color: Theme.islandAccent
                    font.family: Glass.font
                    font.pixelSize: root.compact ? 28 : 34
                    font.weight: Font.Light
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: Qt.formatDate(root.selectedDate, "dddd")
                        color: Theme.islandText
                        font.family: Glass.font
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    Text {
                        visible: !root.selectionInView
                        text: Qt.formatDate(root.selectedDate, "MMMM yyyy")
                        color: Theme.islandDim
                        font.family: Glass.font
                        font.pixelSize: 11
                    }
                }
            }
            CalendarButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.canReturnToToday
                pill: true
                text: "Today"
                onClicked: root.today()
            }
        }
        Rectangle {
            width: content.width
            height: 1
            color: Theme.islandHover
        }
        Item {
            width: Math.min(content.width, 196)
            height: 28
            anchors.horizontalCenter: parent.horizontalCenter

            CalendarButton {
                id: previousMonth
                anchors.left: parent.left
                text: "‹"
                Accessible.name: "Previous month"
                onClicked: root.monthOffset--
            }
            Text {
                anchors { left: previousMonth.right; right: nextMonth.left; verticalCenter: parent.verticalCenter }
                text: root.monthLabel
                color: Theme.islandText
                font.family: Glass.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
            CalendarButton {
                id: nextMonth
                anchors.right: parent.right
                text: "›"
                Accessible.name: "Next month"
                onClicked: root.monthOffset++
            }
        }
        Row {
            width: parent.width
            height: 18
            Repeater {
                model: 7
                delegate: Text {
                    required property int index
                    width: content.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().standaloneDayName(((root.firstWeekday + index + 6) % 7) + 1, Locale.ShortFormat).slice(0, 2)
                    color: Theme.islandDim
                    font.family: Glass.font
                    font.pixelSize: 11
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
                    width: content.width / 7
                    height: root.compact ? 26 : 30
                    Rectangle {
                        anchors.centerIn: parent
                        width: root.compact ? 23 : 27
                        height: root.compact ? 23 : 27
                        radius: 14
                        color: cell.isToday ? Theme.islandAccent : cell.selected ? Theme.islandHover : dayMouse.containsMouse ? Theme.islandHover : "transparent"
                        border.width: cell.selected && !cell.isToday ? 1 : 0
                        border.color: Theme.islandBorder
                        Text {
                            anchors.centerIn: parent
                            text: cell.day
                            color: cell.isToday ? Theme.islandTodayText : cell.inMonth ? Theme.islandText : Qt.rgba(Theme.islandDim.r, Theme.islandDim.g, Theme.islandDim.b, 0.45)
                            font.family: Glass.font
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
    }
}
