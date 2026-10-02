pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../services"

Rectangle {
    id: root

    // =========================================================================
    // Public Interface & Signals
    // =========================================================================

    signal closeRequested

    // =========================================================================
    // Geometry & Container Properties
    // =========================================================================

    implicitWidth: 360
    implicitHeight: 250
    width: 360
    height: 250
    color: "transparent"
    radius: Theme.radiusMedium

    // Consume clicks on blank/padding areas so underlying LivingNotch/scrim isn't clicked
    MouseArea {
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        preventStealing: true

        onClicked: mouse => {
            mouse.accepted = true;
        }
        onWheel: wheel => {
            const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            AudioService.stepVolume(delta);
        }
    }

    // Keyboard dismissal support
    focus: true
    Keys.onEscapePressed: event => {
        event.accepted = true;
        root.closeRequested();
    }

    // =========================================================================
    // Calendar State & ISO-8601 42-Cell Calculations
    // =========================================================================

    SystemClock {
        id: systemClock
        // Plural form, not Qt's documented "MinutePrecision": the documented
        // names resolve to undefined on this Qt. See CalendarPopup.qml.
        precision: SystemClock.Minutes
    }

    property int todayYear: systemClock.date.getFullYear()
    property int todayMonth: systemClock.date.getMonth()
    property int todayDate: systemClock.date.getDate()

    property int viewYear: todayYear
    property int viewMonth: todayMonth

    readonly property var monthNames: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]

    readonly property var dayHeaders: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    readonly property var gridCells: generateCalendarCells(root.viewYear, root.viewMonth, root.todayYear, root.todayMonth, root.todayDate)

    Component.onCompleted: resetToToday()

    onVisibleChanged: {
        if (visible) {
            resetToToday();
        }
    }

    function previousMonth(): void {
        if (viewMonth === 0) {
            viewYear--;
            viewMonth = 11;
        } else {
            viewMonth--;
        }
    }

    function nextMonth(): void {
        if (viewMonth === 11) {
            viewYear++;
            viewMonth = 0;
        } else {
            viewMonth++;
        }
    }

    function resetToToday(): void {
        viewYear = Qt.binding(function () {
            return todayYear;
        });
        viewMonth = Qt.binding(function () {
            return todayMonth;
        });
    }

    function generateCalendarCells(year: int, month: int, tYear: int, tMonth: int, tDate: int): var {
        const cells = [];

        const firstDay = new Date(year, month, 1);
        const firstDayIndex = (firstDay.getDay() + 6) % 7; // Monday = 0 .. Sunday = 6

        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const daysInPrevMonth = new Date(year, month, 0).getDate();

        for (let i = 0; i < 42; ++i) {
            let dayNum;
            let isCurrentMonth = false;
            let cellYear = year;
            let cellMonth = month;

            if (i < firstDayIndex) {
                dayNum = daysInPrevMonth - firstDayIndex + 1 + i;
                cellMonth = month === 0 ? 11 : month - 1;
                cellYear = month === 0 ? year - 1 : year;
            } else if (i < firstDayIndex + daysInMonth) {
                dayNum = i - firstDayIndex + 1;
                isCurrentMonth = true;
            } else {
                dayNum = i - (firstDayIndex + daysInMonth) + 1;
                cellMonth = month === 11 ? 0 : month + 1;
                cellYear = month === 11 ? year + 1 : year;
            }

            const isToday = (cellYear === tYear && cellMonth === tMonth && dayNum === tDate && isCurrentMonth);

            cells.push({
                day: dayNum,
                isCurrentMonth: isCurrentMonth,
                isToday: isToday,
                year: cellYear,
                month: cellMonth
            });
        }
        return cells;
    }

    // =========================================================================
    // Visual Layout Hierarchy
    // =========================================================================

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: Theme.spacingSmall

        // ---------------------------------------------------------------------
        // 1. Header Row: [<] Month Year [>] [x]
        // ---------------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            spacing: Theme.spacingSmall

            // Previous Month Button [<]
            Rectangle {
                id: prevBtn
                Layout.preferredHeight: 22
                Layout.preferredWidth: 22
                border.color: prevMouse.containsMouse ? Theme.accent : Theme.borderMuted
                border.width: Theme.borderWidth
                color: prevMouse.containsMouse ? Theme.surfaceHover : "transparent"
                radius: Theme.radiusSmall

                Text {
                    anchors.centerIn: parent
                    color: prevMouse.containsMouse ? Theme.accent : Theme.textPrimary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightBold
                    text: "<"
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.previousMonth()
                    onWheel: wheel => {
                        const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                        AudioService.stepVolume(delta);
                    }
                }
            }

            // Month / Year Title (Click resets to today)
            Text {
                id: headerTitleText
                Layout.fillWidth: true
                color: titleMouse.containsMouse ? Theme.accent : Theme.textPrimary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightBold
                horizontalAlignment: Text.AlignHCenter
                text: root.monthNames[root.viewMonth] + " " + root.viewYear

                MouseArea {
                    id: titleMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.resetToToday()
                    onWheel: wheel => {
                        const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                        AudioService.stepVolume(delta);
                    }
                }
            }

            // Next Month Button [>]
            Rectangle {
                id: nextBtn
                Layout.preferredHeight: 22
                Layout.preferredWidth: 22
                border.color: nextMouse.containsMouse ? Theme.accent : Theme.borderMuted
                border.width: Theme.borderWidth
                color: nextMouse.containsMouse ? Theme.surfaceHover : "transparent"
                radius: Theme.radiusSmall

                Text {
                    anchors.centerIn: parent
                    color: nextMouse.containsMouse ? Theme.accent : Theme.textPrimary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightBold
                    text: ">"
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.nextMonth()
                    onWheel: wheel => {
                        const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                        AudioService.stepVolume(delta);
                    }
                }
            }

            // Close Button [x]
            Rectangle {
                id: closeBtn
                Layout.preferredHeight: 22
                Layout.preferredWidth: 22
                border.color: closeMouse.containsMouse ? Theme.destructive : Theme.borderMuted
                border.width: Theme.borderWidth
                color: closeMouse.containsMouse ? Theme.surfaceHover : "transparent"
                radius: Theme.radiusSmall

                Text {
                    anchors.centerIn: parent
                    color: closeMouse.containsMouse ? Theme.destructive : Theme.textSecondary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightBold
                    text: "x"
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.closeRequested()
                    onWheel: wheel => {
                        const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                        AudioService.stepVolume(delta);
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 2. Divider Line
        // ---------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.divider
        }

        // ---------------------------------------------------------------------
        // 3. Day of Week Header Row: MON TUE WED THU FRI SAT SUN
        // ---------------------------------------------------------------------
        Grid {
            id: headerGrid
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 4

            Repeater {
                model: root.dayHeaders

                delegate: Item {
                    id: headerItem
                    required property string modelData

                    height: 16
                    width: 44

                    Text {
                        anchors.centerIn: parent
                        color: Theme.textSecondary
                        font.family: Theme.fontFamilyMonospace
                        font.pixelSize: Theme.fontSizeCaption
                        font.weight: Theme.fontWeightDemiBold
                        text: headerItem.modelData
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 4. 42-Cell Days Grid (6 rows x 7 columns)
        // ---------------------------------------------------------------------
        Grid {
            id: daysGrid
            Layout.fillWidth: true
            columns: 7
            rows: 6
            columnSpacing: 4
            rowSpacing: 2

            Repeater {
                model: root.gridCells

                delegate: Item {
                    id: cellItem
                    required property int index
                    required property var modelData

                    height: 24
                    width: 44

                    Rectangle {
                        id: cellBg
                        anchors.fill: parent
                        border.color: cellItem.modelData.isToday ? Theme.acidGreen : (cellMouse.containsMouse ? Theme.borderMuted : "transparent")
                        border.width: Theme.borderWidth
                        color: cellItem.modelData.isToday ? Theme.acidGreen : (cellMouse.containsMouse ? Theme.surfaceHover : "transparent")
                        radius: Theme.radiusSmall

                        Text {
                            anchors.centerIn: parent
                            color: cellItem.modelData.isToday ? Theme.gray900 : (cellItem.modelData.isCurrentMonth ? Theme.textPrimary : Theme.textMuted)
                            font.family: Theme.fontFamilyMonospace
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: cellItem.modelData.isToday ? Theme.fontWeightBold : Theme.fontWeightNormal
                            text: cellItem.modelData.day.toString()
                        }

                        MouseArea {
                            id: cellMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onWheel: wheel => {
                                const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                AudioService.stepVolume(delta);
                            }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 5. Divider Line
        // ---------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.divider
        }

        // ---------------------------------------------------------------------
        // 6. Footer Row: Timestamp '// YYYY-MM-DD' and [TODAY] Button
        // ---------------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            spacing: Theme.spacingSmall

            Text {
                Layout.fillWidth: true
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                text: "// " + Qt.formatDateTime(systemClock.date, "yyyy-MM-dd")
            }

            Rectangle {
                id: todayBtn
                Layout.preferredHeight: 18
                Layout.preferredWidth: todayLabel.implicitWidth + Theme.paddingSmall * 2
                border.color: todayMouse.containsMouse ? Theme.accent : Theme.borderMuted
                border.width: Theme.borderWidth
                color: todayMouse.containsMouse ? Theme.surfaceHover : "transparent"
                radius: Theme.radiusSmall

                Text {
                    id: todayLabel
                    anchors.centerIn: parent
                    color: todayMouse.containsMouse ? Theme.accent : Theme.textSecondary
                    font.family: Theme.fontFamilyMonospace
                    font.pixelSize: Theme.fontSizeCaption
                    font.weight: Theme.fontWeightDemiBold
                    text: "[TODAY]"
                }

                MouseArea {
                    id: todayMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.resetToToday()
                    onWheel: wheel => {
                        const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                        AudioService.stepVolume(delta);
                    }
                }
            }
        }
    }
}
