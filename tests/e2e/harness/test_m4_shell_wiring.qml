import QtQuick
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

    // Mock shell state & logic under test
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

    // Mock screens
    readonly property var mockScreenA: ({ name: "eDP-1", model: "Laptop" })
    readonly property var mockScreenB: ({ name: "DP-1", model: "External" })

    // Instantiate CalendarPopup inside test
    CalendarPopup {
        id: popup
        anchors.centerIn: parent
        onCloseRequested: testWindow.closeCalendar()
    }

    Timer {
        id: testRunner
        interval: 50
        running: true
        repeat: false
        onTriggered: {
            console.log("================================================================");
            console.log("=== SHELL WIRING & MULTI-MONITOR HARNESS (MILESTONE 4) =========");
            console.log("================================================================");

            // Initial state
            assertCondition("T3.M4.01", "Calendar initial visible is false",
                testWindow.calendarVisible === false && testWindow.calendarScreen === null,
                "visible=" + testWindow.calendarVisible);

            // Toggle on Screen A
            testWindow.toggleCalendar(testWindow.mockScreenA);
            assertCondition("T3.M4.02", "Toggle opens calendar on Screen A",
                testWindow.calendarVisible === true && testWindow.calendarScreen === testWindow.mockScreenA,
                "visible=" + testWindow.calendarVisible + ", screen=" + (testWindow.calendarScreen ? testWindow.calendarScreen.name : "null"));

            // Toggle again on Screen A closes it
            testWindow.toggleCalendar(testWindow.mockScreenA);
            assertCondition("T3.M4.03", "Toggle again on Screen A closes calendar",
                testWindow.calendarVisible === false && testWindow.calendarScreen === null,
                "visible=" + testWindow.calendarVisible + ", screen=" + testWindow.calendarScreen);

            // Re-open on Screen A
            testWindow.toggleCalendar(testWindow.mockScreenA);

            // Click Clock on Screen B switches screen without closing
            testWindow.toggleCalendar(testWindow.mockScreenB);
            assertCondition("T3.M4.04", "Toggle on Screen B transfers calendar to Screen B",
                testWindow.calendarVisible === true && testWindow.calendarScreen === testWindow.mockScreenB,
                "visible=" + testWindow.calendarVisible + ", screen=" + (testWindow.calendarScreen ? testWindow.calendarScreen.name : "null"));

            // Close via closeCalendar()
            testWindow.closeCalendar();
            assertCondition("T3.M4.05", "closeCalendar resets state",
                testWindow.calendarVisible === false && testWindow.calendarScreen === null,
                "visible=" + testWindow.calendarVisible);

            // IPC toggle (null target) uses resolveTargetScreen
            testWindow.toggleCalendar(null);
            assertCondition("T3.M4.06", "IPC toggle with null target resolves default screen",
                testWindow.calendarVisible === true && testWindow.calendarScreen !== null && testWindow.calendarScreen.name === "DP-1",
                "screen=" + (testWindow.calendarScreen ? testWindow.calendarScreen.name : "null"));

            // IPC toggle again closes
            testWindow.toggleCalendar(null);
            assertCondition("T3.M4.07", "IPC toggle again closes calendar",
                testWindow.calendarVisible === false,
                "visible=" + testWindow.calendarVisible);

            // Close requested from CalendarPopup calls closeCalendar
            testWindow.toggleCalendar(testWindow.mockScreenA);
            popup.closeRequested();
            assertCondition("T3.M4.08", "CalendarPopup closeRequested dismisses calendar",
                testWindow.calendarVisible === false,
                "visible=" + testWindow.calendarVisible);

            console.log("================================================================");
            console.log("RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: SHELL WIRING M4 VERIFICATION SUCCESSFUL ===");
            } else {
                console.error("=== ASSERTION_FAILED: " + failCount + " tests failed ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
