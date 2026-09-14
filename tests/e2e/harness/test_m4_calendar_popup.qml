import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.core
import desktop.surfaces.components

FloatingWindow {
    id: testWindow
    visible: true
    implicitWidth: 800
    implicitHeight: 600

    property var results: []
    property int passCount: 0
    property int failCount: 0

    function assertCondition(id, name, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + id + ": " + name + " (" + details + ")");
            results.push({ id: id, name: name, passed: true, details: details });
        } else {
            failCount++;
            console.error("[FAIL] " + id + ": " + name + " (" + details + ")");
            results.push({ id: id, name: name, passed: false, details: details });
        }
    }

    Item {
        id: testContainer
        anchors.fill: parent

        CalendarPopup {
            id: testCalendar
            anchors.centerIn: parent
        }

        ClockWidget {
            id: testClock
            anchors.top: parent.top
            anchors.right: parent.right
        }
    }

    Timer {
        id: testRunner
        interval: 50
        running: true
        repeat: false
        onTriggered: {
            console.log("================================================================");
            console.log("=== EMPIRICAL RUNTIME VERIFICATION HARNESS (MILESTONE 4) ======");
            console.log("================================================================");

            // -------------------------------------------------------------
            // 1. CalendarPopup Geometry & Theming
            // -------------------------------------------------------------
            assertCondition("T1.M4.01", "CalendarPopup instantiated successfully",
                testCalendar !== null,
                "testCalendar object exists");

            assertCondition("T1.M4.02", "CalendarPopup width is 300",
                testCalendar.width === 300 && testCalendar.implicitWidth === 300,
                "width=" + testCalendar.width + ", implicitWidth=" + testCalendar.implicitWidth);

            assertCondition("T1.M4.03", "CalendarPopup color is Theme.gray900",
                testCalendar.color === Theme.gray900,
                "color=" + testCalendar.color);

            assertCondition("T1.M4.04", "CalendarPopup border is Theme.borderMuted",
                testCalendar.border.color === Theme.borderMuted,
                "border.color=" + testCalendar.border.color);

            assertCondition("T1.M4.05", "CalendarPopup radius is Theme.radiusSmall",
                testCalendar.radius === Theme.radiusSmall,
                "radius=" + testCalendar.radius);

            // -------------------------------------------------------------
            // 2. Day of Week Headers
            // -------------------------------------------------------------
            const expectedHeaders = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
            let headersMatch = (testCalendar.dayHeaders.length === 7);
            for (let h = 0; h < 7; ++h) {
                if (testCalendar.dayHeaders[h] !== expectedHeaders[h]) {
                    headersMatch = false;
                    break;
                }
            }
            assertCondition("T1.M4.06", "Day headers start with Monday (ISO-8601)",
                headersMatch,
                "headers=" + JSON.stringify(testCalendar.dayHeaders));

            // -------------------------------------------------------------
            // 3. 42-Cell Grid Invariant & Current Month Generation
            // -------------------------------------------------------------
            const now = new Date();
            const currentYear = now.getFullYear();
            const currentMonth = now.getMonth();
            const currentDate = now.getDate();

            assertCondition("T1.M4.07", "CalendarPopup initial year matches system",
                testCalendar.viewYear === currentYear,
                "viewYear=" + testCalendar.viewYear + " expected=" + currentYear);

            assertCondition("T1.M4.08", "CalendarPopup initial month matches system",
                testCalendar.viewMonth === currentMonth,
                "viewMonth=" + testCalendar.viewMonth + " expected=" + currentMonth);

            assertCondition("T1.M4.09", "Grid contains strictly 42 cells",
                testCalendar.gridCells.length === 42,
                "gridCells.length=" + testCalendar.gridCells.length);

            // Verify today cell highlighting
            let todayFoundCount = 0;
            let todayCellIndex = -1;
            let currentMonthDaysCount = 0;
            for (let c = 0; c < testCalendar.gridCells.length; ++c) {
                const cell = testCalendar.gridCells[c];
                if (cell.isCurrentMonth) {
                    currentMonthDaysCount++;
                }
                if (cell.isToday) {
                    todayFoundCount++;
                    todayCellIndex = c;
                }
            }

            const daysInCurrentMonth = new Date(currentYear, currentMonth + 1, 0).getDate();
            assertCondition("T1.M4.10", "Current month days count matches days in month",
                currentMonthDaysCount === daysInCurrentMonth,
                "currentMonthDaysCount=" + currentMonthDaysCount + " expected=" + daysInCurrentMonth);

            assertCondition("T1.M4.11", "Exactly one cell flagged as today",
                todayFoundCount === 1,
                "todayFoundCount=" + todayFoundCount + " at index=" + todayCellIndex);

            const todayCell = testCalendar.gridCells[todayCellIndex];
            assertCondition("T1.M4.12", "Today cell day matches current date",
                todayCell && todayCell.day === currentDate && todayCell.isCurrentMonth === true,
                "cellDay=" + (todayCell ? todayCell.day : "null") + " expected=" + currentDate);

            // -------------------------------------------------------------
            // 4. Month Navigation (Forward, Backward, Boundary Roll-Over)
            // -------------------------------------------------------------
            testCalendar.nextMonth();
            const nextExpectedMonth = (currentMonth === 11) ? 0 : currentMonth + 1;
            const nextExpectedYear = (currentMonth === 11) ? currentYear + 1 : currentYear;

            assertCondition("T1.M4.13", "nextMonth advances month correctly",
                testCalendar.viewMonth === nextExpectedMonth && testCalendar.viewYear === nextExpectedYear,
                "viewMonth=" + testCalendar.viewMonth + ", viewYear=" + testCalendar.viewYear);

            // Today should not be highlighted in a navigated month
            let navigatedTodayCount = 0;
            for (let c = 0; c < testCalendar.gridCells.length; ++c) {
                if (testCalendar.gridCells[c].isToday) {
                    navigatedTodayCount++;
                }
            }
            assertCondition("T1.M4.14", "Today is NOT highlighted when viewing another month",
                navigatedTodayCount === 0,
                "navigatedTodayCount=" + navigatedTodayCount);

            testCalendar.previousMonth();
            assertCondition("T1.M4.15", "previousMonth returns to original month",
                testCalendar.viewMonth === currentMonth && testCalendar.viewYear === currentYear,
                "viewMonth=" + testCalendar.viewMonth + ", viewYear=" + testCalendar.viewYear);

            // Test Year Boundary Roll-Over
            testCalendar.viewYear = 2026;
            testCalendar.viewMonth = 0; // January 2026
            testCalendar.previousMonth();
            assertCondition("T1.M4.16", "January to December rollover decrements year",
                testCalendar.viewMonth === 11 && testCalendar.viewYear === 2025,
                "viewMonth=" + testCalendar.viewMonth + ", viewYear=" + testCalendar.viewYear);

            testCalendar.nextMonth();
            assertCondition("T1.M4.17", "December to January rollover increments year",
                testCalendar.viewMonth === 0 && testCalendar.viewYear === 2026,
                "viewMonth=" + testCalendar.viewMonth + ", viewYear=" + testCalendar.viewYear);

            // Test resetToToday
            testCalendar.resetToToday();
            assertCondition("T1.M4.18", "resetToToday restores current month and year",
                testCalendar.viewMonth === currentMonth && testCalendar.viewYear === currentYear,
                "viewMonth=" + testCalendar.viewMonth + ", viewYear=" + testCalendar.viewYear);

            // -------------------------------------------------------------
            // 5. Leap Year & Mathematical Edge Cases
            // -------------------------------------------------------------
            // Leap year 2028: Feb must have 29 days
            const leapCells = testCalendar.generateCalendarCells(2028, 1);
            let leapFebDays = 0;
            for (let i = 0; i < leapCells.length; ++i) {
                if (leapCells[i].isCurrentMonth) leapFebDays++;
            }
            assertCondition("T2.M4.01", "Leap year Feb 2028 has 29 current month days",
                leapFebDays === 29 && leapCells.length === 42,
                "leapFebDays=" + leapFebDays + ", totalCells=" + leapCells.length);

            // Non-leap year 2026: Feb must have 28 days
            const nonLeapCells = testCalendar.generateCalendarCells(2026, 1);
            let nonLeapFebDays = 0;
            for (let i = 0; i < nonLeapCells.length; ++i) {
                if (nonLeapCells[i].isCurrentMonth) nonLeapFebDays++;
            }
            assertCondition("T2.M4.02", "Non-leap year Feb 2026 has 28 current month days",
                nonLeapFebDays === 28 && nonLeapCells.length === 42,
                "nonLeapFebDays=" + nonLeapFebDays + ", totalCells=" + nonLeapCells.length);

            // Century leap year 2000 (divisible by 400): Feb has 29 days
            const century2000Cells = testCalendar.generateCalendarCells(2000, 1);
            let feb2000Days = 0;
            for (let i = 0; i < century2000Cells.length; ++i) {
                if (century2000Cells[i].isCurrentMonth) feb2000Days++;
            }
            assertCondition("T2.M4.03", "Century leap year Feb 2000 has 29 days",
                feb2000Days === 29 && century2000Cells.length === 42,
                "feb2000Days=" + feb2000Days);

            // Century non-leap year 2100 (divisible by 100, not 400): Feb has 28 days
            const century2100Cells = testCalendar.generateCalendarCells(2100, 1);
            let feb2100Days = 0;
            for (let i = 0; i < century2100Cells.length; ++i) {
                if (century2100Cells[i].isCurrentMonth) feb2100Days++;
            }
            assertCondition("T2.M4.04", "Century non-leap year Feb 2100 has 28 days",
                feb2100Days === 28 && century2100Cells.length === 42,
                "feb2100Days=" + feb2100Days);

            // Month starting on Monday (June 2026): 0 trailing days
            const june2026Cells = testCalendar.generateCalendarCells(2026, 5);
            assertCondition("T2.M4.05", "Month starting on Monday (June 2026) has cell 0 as June 1",
                june2026Cells[0].day === 1 && june2026Cells[0].isCurrentMonth === true,
                "cell0Day=" + june2026Cells[0].day + ", isCur=" + june2026Cells[0].isCurrentMonth);

            // Month starting on Sunday (Feb 2026): 6 trailing days, cell 6 is Feb 1
            const feb2026Cells = testCalendar.generateCalendarCells(2026, 1);
            assertCondition("T2.M4.06", "Month starting on Sunday (Feb 2026) has 6 trailing days, cell 6 is Feb 1",
                feb2026Cells[5].isCurrentMonth === false && feb2026Cells[6].day === 1 && feb2026Cells[6].isCurrentMonth === true,
                "cell5Cur=" + feb2026Cells[5].isCurrentMonth + ", cell6Day=" + feb2026Cells[6].day);

            // Trailing day today immunity
            // If viewing Sep 2026, cell 0 is Aug 31 (trailing). It must NEVER have isToday true.
            const sep2026Cells = testCalendar.generateCalendarCells(2026, 8);
            assertCondition("T2.M4.07", "Trailing cell 0 (Aug 31) in Sep 2026 has isToday false",
                sep2026Cells[0].day === 31 && sep2026Cells[0].isCurrentMonth === false && sep2026Cells[0].isToday === false,
                "day=" + sep2026Cells[0].day + ", isCurrentMonth=" + sep2026Cells[0].isCurrentMonth + ", isToday=" + sep2026Cells[0].isToday);

            // -------------------------------------------------------------
            // 6. ClockWidget Signal & CloseRequested Signal
            // -------------------------------------------------------------
            let clockSignalFired = false;
            testClock.toggleCalendar.connect(function() {
                clockSignalFired = true;
            });
            testClock.toggleCalendar();
            assertCondition("T1.M4.19", "ClockWidget emits toggleCalendar signal",
                clockSignalFired === true,
                "clockSignalFired=" + clockSignalFired);

            let closeRequestedFired = false;
            testCalendar.closeRequested.connect(function() {
                closeRequestedFired = true;
            });
            testCalendar.closeRequested();
            assertCondition("T1.M4.20", "CalendarPopup emits closeRequested signal",
                closeRequestedFired === true,
                "closeRequestedFired=" + closeRequestedFired);

            console.log("================================================================");
            console.log("RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: EMPIRICAL RUNTIME M4 VERIFICATION SUCCESSFUL ===");
            } else {
                console.error("=== ASSERTION_FAILED: " + failCount + " tests failed ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
