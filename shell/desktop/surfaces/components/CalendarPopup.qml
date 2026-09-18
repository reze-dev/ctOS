pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../widgets"

Rectangle {
    id: root

    // =========================================================================
    // Public Interface & Signals
    // =========================================================================

    signal closeRequested

    // =========================================================================
    // Geometry & Theme Styling
    // =========================================================================

    implicitWidth: 300
    width: 300
    implicitHeight: mainColumn.implicitHeight + Theme.paddingLarge * 2
    color: Theme.gray900
    radius: Theme.radiusSmall
    border.color: Theme.borderMuted
    border.width: Theme.borderWidth

    // Consume all clicks inside popup so backdrop does not dismiss
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        onClicked: mouse => mouse.accepted = true
    }

    // Cyberpunk Corner Brackets
    CornerBrackets {
        id: cornerBrackets
        bracketColor: Theme.acidGreen
        z: 10
    }

    // =========================================================================
    // Calendar State & Calculations
    // =========================================================================

    property int viewYear: (new Date()).getFullYear()
    property int viewMonth: (new Date()).getMonth()

    readonly property var monthNames: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]

    readonly property var dayHeaders: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    readonly property var gridCells: generateCalendarCells(root.viewYear, root.viewMonth)

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
        const now = new Date();
        viewYear = now.getFullYear();
        viewMonth = now.getMonth();
    }

    function generateCalendarCells(year: int, month: int): var {
        const cells = [];
        const today = new Date();
        const todayYear = today.getFullYear();
        const todayMonth = today.getMonth();
        const todayDate = today.getDate();

        const firstDay = new Date(year, month, 1);
        const firstDayIndex = (firstDay.getDay() + 6) % 7;

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

            const isToday = (cellYear === todayYear && cellMonth === todayMonth && dayNum === todayDate && isCurrentMonth);

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
    // Content Layout
    // =========================================================================

    ColumnLayout {
        id: mainColumn

        anchors.fill: parent
        anchors.margins: Theme.paddingLarge
        spacing: Theme.spacingMedium

        // Header: [<] Month Year [>] [x]
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            // Previous Month Button
            Rectangle {
                id: prevBtn

                Layout.preferredHeight: 24
                Layout.preferredWidth: 24
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
                }
            }

            // Month / Year Title (Click resets to today)
            Text {
                id: headerTitleText

                Layout.fillWidth: true
                color: Theme.textPrimary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightBold
                horizontalAlignment: Text.AlignHCenter
                text: root.monthNames[root.viewMonth] + " " + root.viewYear

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: root.resetToToday()
                }
            }

            // Next Month Button
            Rectangle {
                id: nextBtn

                Layout.preferredHeight: 24
                Layout.preferredWidth: 24
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
                }
            }

            // Close Button
            Rectangle {
                id: closeBtn

                Layout.preferredHeight: 24
                Layout.preferredWidth: 24
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
                }
            }
        }

        // Divider Line
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.divider
        }

        // Day of Week Header Row: MON TUE WED THU FRI SAT SUN
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

                    height: 20
                    width: (mainColumn.width - (7 - 1) * 4) / 7

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

        // 6x7 Grid of Day Numbers (42 cells)
        Grid {
            id: daysGrid

            Layout.fillWidth: true
            columnSpacing: 4
            columns: 7
            rowSpacing: 4
            rows: 6

            Repeater {
                model: root.gridCells

                delegate: Item {
                    id: cellItem

                    required property int index
                    required property var modelData

                    height: 28
                    width: (mainColumn.width - (7 - 1) * 4) / 7

                    Rectangle {
                        id: cellBg

                        anchors.fill: parent
                        border.color: cellItem.modelData.isToday ? Theme.accent : (cellMouse.containsMouse ? Theme.borderMuted : "transparent")
                        border.width: Theme.borderWidth
                        color: cellItem.modelData.isToday ? Theme.accent : (cellMouse.containsMouse ? Theme.surfaceHover : "transparent")
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
                        }
                    }
                }
            }
        }

        // Divider Line
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderWidth
            color: Theme.divider
        }

        // Footer: Today Date Status
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            Text {
                Layout.fillWidth: true
                color: Theme.textMuted
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
                text: "// " + Qt.formatDateTime(new Date(), "yyyy-MM-dd")
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
                    text: "[TODAY]"
                }

                MouseArea {
                    id: todayMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.resetToToday()
                }
            }
        }
    }
}
