import QtQuick
import QtQuick.Layouts

// Month grid, Monday-first, with today accented. Arrows browse other months;
// clicking the header snaps back to today.
WCard {
    id: cal

    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()   // 0-based

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    title: "CALENDAR"

    function resetToToday() {
        today = new Date();
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
    }

    function shift(delta) {
        let m = viewMonth + delta;
        let y = viewYear;
        while (m < 0) {
            m += 12;
            y--;
        }
        while (m > 11) {
            m -= 12;
            y++;
        }
        viewMonth = m;
        viewYear = y;
    }

    // 42 cells (6 weeks) so the grid never changes height between months.
    readonly property var cells: {
        const first = new Date(viewYear, viewMonth, 1);
        // JS weeks start Sunday; shift so Monday is column 0.
        const lead = (first.getDay() + 6) % 7;
        const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate();
        const daysInPrev = new Date(viewYear, viewMonth, 0).getDate();

        const out = [];
        for (let i = 0; i < 42; i++) {
            const n = i - lead + 1;
            if (n < 1)
                out.push({
                    day: daysInPrev + n,
                    inMonth: false
                });
            else if (n > daysInMonth)
                out.push({
                    day: n - daysInMonth,
                    inMonth: false
                });
            else
                out.push({
                    day: n,
                    inMonth: true
                });
        }
        return out;
    }

    function isToday(cell) {
        return cell.inMonth && cell.day === today.getDate() && viewMonth === today.getMonth() && viewYear === today.getFullYear();
    }

    // -- month header ---------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: "󰅁"
            color: prevMa.containsMouse ? Theme.acc : Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fsMd

            MouseArea {
                id: prevMa
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: cal.shift(-1)
            }
        }

        Item {
            Layout.fillWidth: true

            Text {
                anchors.centerIn: parent
                text: cal.monthNames[cal.viewMonth] + " " + cal.viewYear
                color: homeMa.containsMouse ? Theme.acc : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fsSm
                font.weight: Font.DemiBold

                MouseArea {
                    id: homeMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cal.resetToToday()
                }
            }
        }

        Text {
            text: "󰅂"
            color: nextMa.containsMouse ? Theme.acc : Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fsMd

            MouseArea {
                id: nextMa
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: cal.shift(1)
            }
        }
    }

    // -- weekday header -------------------------------------------------------
    GridLayout {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: 2
        rowSpacing: 2

        Repeater {
            model: ["mo", "tu", "we", "th", "fr", "sa", "su"]

            Text {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: index >= 5 ? Theme.a(Theme.fgFaint, 0.9) : Theme.fgFaint
                font.family: Theme.font
                font.pixelSize: Theme.fsXs
            }
        }
    }

    // -- day grid -------------------------------------------------------------
    GridLayout {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: 2
        rowSpacing: 2

        Repeater {
            model: cal.cells

            Rectangle {
                id: dayCell
                required property var modelData

                readonly property bool today_: cal.isToday(modelData)

                Layout.fillWidth: true
                implicitHeight: 24
                radius: Theme.radiusSm
                color: today_ ? Theme.a(Theme.acc, 0.16) : "transparent"
                border.width: 1
                border.color: today_ ? Theme.a(Theme.acc, 0.5) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: dayCell.modelData.day
                    color: dayCell.today_ ? Theme.acc : (dayCell.modelData.inMonth ? Theme.fg : Theme.fgFaint)
                    font.family: Theme.font
                    font.pixelSize: Theme.fsSm
                    font.weight: dayCell.today_ ? Font.Bold : Font.Normal
                }
            }
        }
    }
}
