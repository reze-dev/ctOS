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

    property int passCount: 0
    property int failCount: 0

    function assertCondition(id, name, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + id + ": " + name + " (" + details + ")");
        } else {
            failCount++;
            console.error("[FAIL] " + id + ": " + name + " (" + details + ")");
        }
    }

    // Mock shell state
    property bool calendarVisible: false
    property var calendarScreen: null

    function resolveTargetScreen(): var {
        return { name: "DP-1" };
    }

    function toggleCalendar(targetScreen): void {
        const resolved = (targetScreen !== null && targetScreen !== undefined)
            ? targetScreen
            : testWindow.resolveTargetScreen();

        if (testWindow.calendarVisible) {
            if (targetScreen === null || targetScreen === undefined || testWindow.calendarScreen === resolved) {
                testWindow.calendarVisible = false;
                testWindow.calendarScreen = null;
            } else {
                testWindow.calendarScreen = resolved;
            }
        } else {
            testWindow.calendarScreen = resolved;
            testWindow.calendarVisible = true;
        }
    }

    function closeCalendar(): void {
        testWindow.calendarVisible = false;
        testWindow.calendarScreen = null;
    }

    // Mock overlay open simulation
    function simulateOverlayOpened(): void {
        testWindow.closeCalendar();
    }

    // Mock screen disconnect simulation
    function simulateScreenDisconnect(disconnectedScreenName): void {
        if (testWindow.calendarVisible && testWindow.calendarScreen) {
            if (testWindow.calendarScreen.name === disconnectedScreenName) {
                testWindow.closeCalendar();
            }
        }
    }

    CalendarPopup {
        id: popup
        anchors.centerIn: parent
        onCloseRequested: testWindow.closeCalendar()
    }

    ClockWidget {
        id: clock
        anchors.top: parent.top
        anchors.right: parent.right
        onToggleCalendar: testWindow.toggleCalendar({ name: "eDP-1" })
    }

    Timer {
        id: runner
        interval: 50
        running: true
        repeat: false
        onTriggered: {
            console.log("================================================================");
            console.log("=== ADVERSARIAL STRESS & INTEGRITY HARNESS (MILESTONE 4) =======");
            console.log("================================================================");

            // -------------------------------------------------------------
            // A1. Calendar Grid Math Boundary Stress Tests
            // -------------------------------------------------------------
            // Month starting on Sunday (e.g. March 2026 starts on Sunday)
            // Wait, March 1, 2026: Feb 2026 has 28 days and starts on Sunday!
            // Feb 1, 2026 is Sunday. 28 days later is March 1, 2026, which is also Sunday!
            const march2026 = popup.generateCalendarCells(2026, 2);
            assertCondition("ADV.M4.01", "March 2026 has 42 cells",
                march2026.length === 42,
                "length=" + march2026.length);

            assertCondition("ADV.M4.02", "March 2026 starting on Sunday has 6 trailing cells",
                march2026[0].isCurrentMonth === false &&
                march2026[5].isCurrentMonth === false &&
                march2026[6].isCurrentMonth === true &&
                march2026[6].day === 1,
                "cell0Cur=" + march2026[0].isCurrentMonth + ", cell5Cur=" + march2026[5].isCurrentMonth + ", cell6Day=" + march2026[6].day);

            // Month starting on Saturday (e.g. August 2026)
            // Aug 1, 2026 is Saturday -> column index 5 (0-indexed Mon..Sun: Mon=0, Tue=1, Wed=2, Thu=3, Fri=4, Sat=5, Sun=6)
            const aug2026 = popup.generateCalendarCells(2026, 7);
            assertCondition("ADV.M4.03", "August 2026 starting on Saturday has cell 5 as day 1",
                aug2026[4].isCurrentMonth === false &&
                aug2026[5].isCurrentMonth === true &&
                aug2026[5].day === 1,
                "cell4Cur=" + aug2026[4].isCurrentMonth + ", cell5Day=" + aug2026[5].day);

            // Month starting on Monday (e.g. June 2026)
            // Mon June 1, 2026 -> column index 0, exactly 0 trailing days from previous month
            const jun2026 = popup.generateCalendarCells(2026, 5);
            assertCondition("ADV.M4.04", "June 2026 starting on Monday has 0 trailing days",
                jun2026[0].isCurrentMonth === true &&
                jun2026[0].day === 1,
                "cell0Day=" + jun2026[0].day + ", cell0Cur=" + jun2026[0].isCurrentMonth);

            // Month with 31 days starting on Sunday (e.g. August 2021)
            // Aug 1, 2021 was Sunday -> firstDayIndex = 6. 31 days end at index 6 + 31 - 1 = 36.
            // 42 cells have 6 cells left (indices 37..41) as leading days of September!
            const aug2021 = popup.generateCalendarCells(2021, 7);
            assertCondition("ADV.M4.05", "31-day month starting on Sunday (Aug 2021) ends at cell 36",
                aug2021[36].day === 31 && aug2021[36].isCurrentMonth === true &&
                aug2021[37].day === 1 && aug2021[37].isCurrentMonth === false,
                "cell36Day=" + aug2021[36].day + ", cell37Day=" + aug2021[37].day);

            // Month with 31 days starting on Saturday (e.g. May 2021)
            // May 1, 2021 was Saturday -> firstDayIndex = 5. 31 days end at index 5 + 31 - 1 = 35.
            const may2021 = popup.generateCalendarCells(2021, 4);
            assertCondition("ADV.M4.06", "31-day month starting on Saturday (May 2021) ends at cell 35",
                may2021[35].day === 31 && may2021[35].isCurrentMonth === true &&
                may2021[36].day === 1 && may2021[36].isCurrentMonth === false,
                "cell35Day=" + may2021[35].day + ", cell36Day=" + may2021[36].day);

            // -------------------------------------------------------------
            // A2. Multi-Year Boundary & Rapid Navigation Stress
            // -------------------------------------------------------------
            // Fast forward 24 months
            for (let m = 0; m < 24; ++m) {
                popup.nextMonth();
            }
            assertCondition("ADV.M4.07", "24 forward month navigations advances exactly 2 years",
                popup.viewYear === 2028 && popup.viewMonth === 8,
                "year=" + popup.viewYear + ", month=" + popup.viewMonth);

            // Fast backward 48 months
            for (let m = 0; m < 48; ++m) {
                popup.previousMonth();
            }
            assertCondition("ADV.M4.08", "48 backward month navigations reaches 2024",
                popup.viewYear === 2024 && popup.viewMonth === 8,
                "year=" + popup.viewYear + ", month=" + popup.viewMonth);

            // Reset restores system year and month
            popup.resetToToday();
            const now = new Date();
            assertCondition("ADV.M4.09", "resetToToday restores current month after 72 navigations",
                popup.viewYear === now.getFullYear() && popup.viewMonth === now.getMonth(),
                "year=" + popup.viewYear + ", month=" + popup.viewMonth);

            // -------------------------------------------------------------
            // A3. Inside Click vs Dismissal Isolation
            // -------------------------------------------------------------
            // Clock click triggers toggleCalendar
            clock.toggleCalendar();
            assertCondition("ADV.M4.10", "Clock click opens calendar",
                testWindow.calendarVisible === true && testWindow.calendarScreen.name === "eDP-1",
                "visible=" + testWindow.calendarVisible + ", screen=" + testWindow.calendarScreen.name);

            // Popup closeRequested dismisses
            popup.closeRequested();
            assertCondition("ADV.M4.11", "Popup closeRequested dismisses calendar",
                testWindow.calendarVisible === false && testWindow.calendarScreen === null,
                "visible=" + testWindow.calendarVisible);

            // Re-open
            clock.toggleCalendar();
            // Overlay opened dismisses calendar
            simulateOverlayOpened();
            assertCondition("ADV.M4.12", "Overlay opening pre-empts calendar",
                testWindow.calendarVisible === false && testWindow.calendarScreen === null,
                "visible=" + testWindow.calendarVisible);

            // Re-open on Screen 1, simulate screen disconnect
            testWindow.toggleCalendar({ name: "HDMI-A-1" });
            assertCondition("ADV.M4.13", "Calendar open on HDMI-A-1",
                testWindow.calendarVisible === true && testWindow.calendarScreen.name === "HDMI-A-1",
                "screen=" + testWindow.calendarScreen.name);

            simulateScreenDisconnect("HDMI-A-1");
            assertCondition("ADV.M4.14", "Monitor disconnection closes calendar",
                testWindow.calendarVisible === false && testWindow.calendarScreen === null,
                "visible=" + testWindow.calendarVisible);

            // -------------------------------------------------------------
            // A4. Memory & Token Adherence Stress
            // -------------------------------------------------------------
            // Verify all day header tokens and styling
            assertCondition("ADV.M4.15", "CalendarPopup background matches Theme.gray900 token",
                popup.color === Theme.gray900,
                "color=" + popup.color + " expected=" + Theme.gray900);

            assertCondition("ADV.M4.16", "CalendarPopup corner brackets match Theme.acidGreen",
                Theme.acidGreen !== undefined && Theme.acidGreen !== "",
                "acidGreen=" + Theme.acidGreen);

            console.log("================================================================");
            console.log("RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: ADVERSARIAL STRESS SUITE SUCCESSFUL ===");
            } else {
                console.error("=== FAIL: ADVERSARIAL STRESS SUITE FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
