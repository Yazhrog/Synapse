import QtQuick
import qs.src.theme
// TaskCalendar — TaskDatePicker's month view: ‹ month year ›, the weekday
// initials and a 6-week day grid (today ringed, the picked day filled).
// `days` is the 42-cell grid ({ n, cur }) the picker builds for the month.
Column {
    id: cal
    property int year:  0
    property int month: 0
    property int day:   0      // 0 = no day picked
    property var days:  []
    signal monthStepped(int delta)
    signal dayPicked(int day)

    readonly property var _monthNames: [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]
    readonly property var _dowNames: ["Su","Mo","Tu","We","Th","Fr","Sa"]

    spacing: 8

    // ── Month nav ──────────────────────────────────────────────────────
    Item {
        width: parent.width; height: 22
        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "‹"; font.pixelSize: 17
            color: pmH.hovered ? Qt.rgba(1,1,1,0.85) : Qt.rgba(1,1,1,0.30)
            Behavior on color { ColorAnimation { duration: 80 } }
            HoverHandler { id: pmH; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                onClicked: cal.monthStepped(-1)
            }
        }
        Text {
            anchors.centerIn: parent
            text:  cal._monthNames[cal.month].substring(0,3) + "  " + cal.year
            color: Theme.color.text; font.pixelSize: 11; font.weight: Font.DemiBold
        }
        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: "›"; font.pixelSize: 17
            color: nmH.hovered ? Qt.rgba(1,1,1,0.85) : Qt.rgba(1,1,1,0.30)
            Behavior on color { ColorAnimation { duration: 80 } }
            HoverHandler { id: nmH; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                onClicked: cal.monthStepped(1)
            }
        }
    }

    // ── Day-of-week headers ────────────────────────────────────────────
    Item {
        width: parent.width; height: 14
        Row {
            anchors.fill: parent
            Repeater {
                model: cal._dowNames
                delegate: Text {
                    width: Math.floor(parent.parent.width / 7)
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData; font.pixelSize: 8; font.weight: Font.Bold
                    color: Qt.rgba(1,1,1,0.18)
                }
            }
        }
    }

    // ── Day grid ──────────────────────────────────────────────────────
    Grid {
        id: dayGrid
        width: parent.width; columns: 7; rows: 6
        readonly property real cW: width / 7
        readonly property real cH: 24

        Repeater {
            model: cal.days
            delegate: Item {
                required property var modelData
                required property int index
                width: dayGrid.cW; height: dayGrid.cH

                readonly property bool isSel: modelData.cur && modelData.n === cal.day
                readonly property bool isNow: {
                    var n = new Date()
                    return modelData.cur &&
                           modelData.n   === n.getDate() &&
                           cal.month === n.getMonth() &&
                           cal.year  === n.getFullYear()
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(dayGrid.cW, dayGrid.cH) - 2; height: width; radius: width / 2
                    color: isSel
                        ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.82)
                        : isNow ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.12)
                                : dayH.hovered && modelData.cur ? Qt.rgba(1,1,1,0.08) : "transparent"
                    border.color: isNow && !isSel ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.35) : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 80 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.n
                        font.pixelSize: 9; font.weight: isSel ? Font.Bold : Font.Normal
                        color: isSel ? Theme.color.background
                            : modelData.cur ? Qt.rgba(1,1,1,0.78) : Qt.rgba(1,1,1,0.14)
                    }
                }
                HoverHandler { id: dayH; enabled: modelData.cur; cursorShape: Qt.PointingHandCursor }
                TapHandler  { enabled: modelData.cur; onTapped: cal.dayPicked(modelData.n) }
            }
        }
    }
}
