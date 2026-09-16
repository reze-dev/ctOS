pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.core
import desktop.surfaces.components

FloatingWindow {
    id: testWindow
    visible: true
    implicitWidth: 900
    implicitHeight: 700

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

    // =========================================================================
    // Mock Screens & Shell State
    // =========================================================================

    readonly property var mockScreen1: ({ name: "eDP-1", model: "Internal Laptop Display" })
    readonly property var mockScreen2: ({ name: "DP-1", model: "External 4K Monitor" })
    readonly property var mockScreen3: ({ name: "HDMI-A-1", model: "Secondary Display" })

    property var activeScreens: [mockScreen1, mockScreen2, mockScreen3]
    property var currentFocusedMonitor: mockScreen1

    property bool calendarVisible: false
    property var calendarScreen: null

    function resolveTargetScreen(): var {
        const screenList = activeScreens;
        if (!screenList || screenList.length === 0) {
            return null;
        }

        if (currentFocusedMonitor && currentFocusedMonitor.name) {
            const focusedName = currentFocusedMonitor.name;
            for (let i = 0; i < screenList.length; ++i) {
                const s = screenList[i];
                if (s && s.name === focusedName) {
                    return s;
                }
            }
        }

        for (let i = 0; i < screenList.length; ++i) {
            if (screenList[i]) {
                return screenList[i];
            }
        }
        return null;
    }

    function toggleCalendar(targetScreen): void {
        const resolved = (targetScreen !== null && targetScreen !== undefined) ? targetScreen : resolveTargetScreen();

        if (calendarVisible) {
            if (targetScreen === null || targetScreen === undefined || calendarScreen === resolved) {
                calendarVisible = false;
                calendarScreen = null;
            } else {
                calendarScreen = resolved;
            }
        } else {
            calendarScreen = resolved;
            calendarVisible = true;
        }
    }

    function closeCalendar(): void {
        calendarVisible = false;
        calendarScreen = null;
    }

    // Direct replication of shell.qml screensChanged logic
    function handleScreensChanged(): void {
        if (calendarVisible) {
            const currentCalScreen = calendarScreen;
            if (!currentCalScreen) {
                closeCalendar();
                return;
            }

            const screenList = activeScreens;
            let isCalAlive = false;
            for (let i = 0; i < screenList.length; ++i) {
                if (screenList[i] && screenList[i].name === currentCalScreen.name) {
                    isCalAlive = true;
                    break;
                }
            }

            if (!isCalAlive) {
                closeCalendar();
            }
        }
    }

    // Direct replication of shell.qml OverlayController connections
    Connections {
        target: OverlayController

        function onOverlayOpened(activeSurface: int): void {
            testWindow.closeCalendar();
        }
    }

    // Instantiate real components under test
    CalendarPopup {
        id: testPopup
        anchors.centerIn: parent
        onCloseRequested: testWindow.closeCalendar()
    }

    ClockWidget {
        id: testClock
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        onToggleCalendar: testWindow.toggleCalendar(testWindow.currentFocusedMonitor)
    }

    // Sequencer for empirical testing phases
    property int currentPhase: 0

    Timer {
        id: phaseTimer
        interval: 30
        running: true
        repeat: false
        onTriggered: runPhase()
    }

    function scheduleNext(delayMs, phaseNumber) {
        currentPhase = phaseNumber;
        phaseTimer.interval = delayMs;
        phaseTimer.restart();
    }

    function runPhase() {
        switch (currentPhase) {
            case 0:
                console.log("================================================================");
                console.log("=== EMPIRICAL CHALLENGER: MILSTONE 4 STRESS HARNESS ===========");
                console.log("================================================================");
                console.log("--- PHASE 1: Multi-Monitor Switching Cycle & State Integrity ---");

                // Reset initial state
                calendarVisible = false;
                calendarScreen = null;
                activeScreens = [mockScreen1, mockScreen2, mockScreen3];
                currentFocusedMonitor = mockScreen1;
                OverlayController.close();

                // 1. Initial State
                assertCondition("CHAL.M4.MM.01", "Calendar initial state is closed",
                    calendarVisible === false && calendarScreen === null,
                    "visible=" + calendarVisible + ", screen=" + calendarScreen);

                // 2. Click Clock on Screen 1
                toggleCalendar(mockScreen1);
                assertCondition("CHAL.M4.MM.02", "Clock click on Screen 1 opens calendar on Screen 1",
                    calendarVisible === true && calendarScreen === mockScreen1,
                    "visible=" + calendarVisible + ", screen=" + (calendarScreen ? calendarScreen.name : "null"));

                // 3. Click Clock on Screen 2 (switches screen without closing)
                toggleCalendar(mockScreen2);
                assertCondition("CHAL.M4.MM.03", "Clock click on Screen 2 shifts calendar to Screen 2",
                    calendarVisible === true && calendarScreen === mockScreen2,
                    "visible=" + calendarVisible + ", screen=" + (calendarScreen ? calendarScreen.name : "null"));

                // 4. Click Clock on Screen 1 again (switches back to Screen 1)
                toggleCalendar(mockScreen1);
                assertCondition("CHAL.M4.MM.04", "Clock click on Screen 1 shifts calendar back to Screen 1",
                    calendarVisible === true && calendarScreen === mockScreen1,
                    "visible=" + calendarVisible + ", screen=" + (calendarScreen ? calendarScreen.name : "null"));

                // 5. Click Clock on Screen 1 again (toggles OFF on same screen)
                toggleCalendar(mockScreen1);
                assertCondition("CHAL.M4.MM.05", "Second clock click on Screen 1 toggles calendar closed",
                    calendarVisible === false && calendarScreen === null,
                    "visible=" + calendarVisible + ", screen=" + calendarScreen);

                // 6. Rapid multi-monitor carousel: 1 -> 2 -> 3 -> 1 -> 3
                toggleCalendar(mockScreen1);
                toggleCalendar(mockScreen2);
                toggleCalendar(mockScreen3);
                toggleCalendar(mockScreen1);
                toggleCalendar(mockScreen3);
                assertCondition("CHAL.M4.MM.06", "Rapid multi-monitor switching lands on Screen 3",
                    calendarVisible === true && calendarScreen === mockScreen3,
                    "visible=" + calendarVisible + ", screen=" + (calendarScreen ? calendarScreen.name : "null"));

                closeCalendar();
                assertCondition("CHAL.M4.MM.07", "closeCalendar cleanly resets after carousel",
                    calendarVisible === false && calendarScreen === null,
                    "visible=" + calendarVisible);

                scheduleNext(20, 1);
                break;

            case 1:
                console.log("--- PHASE 2: IPC toggleCalendar() Stress & Concurrency ---");

                // Test 2.1: IPC while closed with focused monitor Screen 1
                currentFocusedMonitor = mockScreen1;
                toggleCalendar(null);
                assertCondition("CHAL.M4.IPC.01", "IPC toggle while closed opens on focused monitor Screen 1",
                    calendarVisible === true && calendarScreen === mockScreen1,
                    "visible=" + calendarVisible + ", screen=" + (calendarScreen ? calendarScreen.name : "null"));

                // Test 2.2: IPC while open on Screen 1 with focused monitor Screen 1 -> closes
                toggleCalendar(null);
                assertCondition("CHAL.M4.IPC.02", "IPC toggle while open on same screen closes calendar",
                    calendarVisible === false && calendarScreen === null,
                    "visible=" + calendarVisible + ", screen=" + calendarScreen);

                // Test 2.3: IPC while closed with focused monitor Screen 2
                currentFocusedMonitor = mockScreen2;
                toggleCalendar(null);
                assertCondition("CHAL.M4.IPC.03", "IPC toggle while closed opens on focused monitor Screen 2",
                    calendarVisible === true && calendarScreen === mockScreen2,
                    "visible=" + calendarVisible + ", screen=" + (calendarScreen ? calendarScreen.name : "null"));

                // Test 2.4: IPC while open on Screen 2 but focused monitor shifted to Screen 1 -> closes
                currentFocusedMonitor = mockScreen1;
                toggleCalendar(null);
                assertCondition("CHAL.M4.IPC.04", "IPC toggle with null target closes even if focus shifted",
                    calendarVisible === false && calendarScreen === null,
                    "visible=" + calendarVisible + ", screen=" + calendarScreen);

                // Test 2.5: IPC with no focused monitor (null) falls back to first screen in list
                currentFocusedMonitor = null;
                toggleCalendar(null);
                assertCondition("CHAL.M4.IPC.05", "IPC toggle with null focus falls back to screenList[0]",
                    calendarVisible === true && calendarScreen === mockScreen1,
                    "visible=" + calendarVisible + ", screen=" + (calendarScreen ? calendarScreen.name : "null"));
                closeCalendar();

                // Test 2.6: IPC with empty screen list handles gracefully
                activeScreens = [];
                currentFocusedMonitor = null;
                toggleCalendar(null);
                assertCondition("CHAL.M4.IPC.06", "IPC toggle with 0 active screens safely handles null",
                    calendarVisible === true && calendarScreen === null,
                    "visible=" + calendarVisible + ", screen=" + calendarScreen);
                closeCalendar();

                // Restore active screens
                activeScreens = [mockScreen1, mockScreen2, mockScreen3];
                currentFocusedMonitor = mockScreen1;

                // Test 2.7: Rapid burst concurrency stress (100 alternating IPC invocations)
                let burstErrors = 0;
                for (let i = 0; i < 100; ++i) {
                    toggleCalendar(null);
                    const expectedVisible = (i % 2 === 0);
                    if (calendarVisible !== expectedVisible) {
                        burstErrors++;
                    }
                }
                assertCondition("CHAL.M4.IPC.07", "100-cycle IPC burst maintains strict toggle invariance",
                    burstErrors === 0 && calendarVisible === false,
                    "burstErrors=" + burstErrors + ", finalVisible=" + calendarVisible);

                scheduleNext(20, 2);
                break;

            case 2:
                console.log("--- PHASE 3: Overlay Preemption (CommandDeck, SystemRail, EventLog) ---");

                // Test 3.1: CommandDeck Preemption
                toggleCalendar(mockScreen1);
                assertCondition("CHAL.M4.OVR.01", "Calendar opened prior to CommandDeck preemption",
                    calendarVisible === true, "visible=" + calendarVisible);

                OverlayController.openCommandDeck();
                assertCondition("CHAL.M4.OVR.02", "Opening CommandDeck immediately dismisses calendar",
                    calendarVisible === false && calendarScreen === null,
                    "calendarVisible=" + calendarVisible + ", activeSurface=" + OverlayController.activeSurface);
                OverlayController.close();

                // Test 3.2: SystemRail Preemption
                toggleCalendar(mockScreen2);
                assertCondition("CHAL.M4.OVR.03", "Calendar opened prior to SystemRail preemption",
                    calendarVisible === true, "visible=" + calendarVisible);

                OverlayController.openSystemRail();
                assertCondition("CHAL.M4.OVR.04", "Opening SystemRail immediately dismisses calendar",
                    calendarVisible === false && calendarScreen === null,
                    "calendarVisible=" + calendarVisible + ", activeSurface=" + OverlayController.activeSurface);
                OverlayController.close();

                // Test 3.3: EventLog Preemption
                toggleCalendar(mockScreen1);
                assertCondition("CHAL.M4.OVR.05", "Calendar opened prior to EventLog preemption",
                    calendarVisible === true, "visible=" + calendarVisible);

                OverlayController.openEventLog();
                assertCondition("CHAL.M4.OVR.06", "Opening EventLog immediately dismisses calendar",
                    calendarVisible === false && calendarScreen === null,
                    "calendarVisible=" + calendarVisible + ", activeSurface=" + OverlayController.activeSurface);
                OverlayController.close();

                // Test 3.4: Toggle CommandDeck Preemption
                toggleCalendar(mockScreen3);
                OverlayController.toggleCommandDeck();
                assertCondition("CHAL.M4.OVR.07", "Toggling CommandDeck on dismisses calendar",
                    calendarVisible === false && calendarScreen === null,
                    "calendarVisible=" + calendarVisible);
                OverlayController.close();

                // Test 3.5: SystemRail Submenu (WiFi) Preemption
                toggleCalendar(mockScreen1);
                OverlayController.openWifiSubmenu();
                assertCondition("CHAL.M4.OVR.08", "openWifiSubmenu() dismisses calendar",
                    calendarVisible === false && calendarScreen === null,
                    "calendarVisible=" + calendarVisible);
                OverlayController.close();

                scheduleNext(20, 3);
                break;

            case 3:
                console.log("--- PHASE 4: Screen Disconnect Handling (screensChanged) ---");

                // Setup 3 screens
                activeScreens = [mockScreen1, mockScreen2, mockScreen3];
                calendarVisible = false;
                calendarScreen = null;

                // Open calendar on Screen 2
                toggleCalendar(mockScreen2);
                assertCondition("CHAL.M4.DISC.01", "Calendar open on Screen 2",
                    calendarVisible === true && calendarScreen === mockScreen2,
                    "screen=" + (calendarScreen ? calendarScreen.name : "null"));

                // Disconnect Screen 1 (inactive monitor removed)
                activeScreens = [mockScreen2, mockScreen3];
                handleScreensChanged();
                assertCondition("CHAL.M4.DISC.02", "Disconnecting inactive Screen 1 keeps calendar open on Screen 2",
                    calendarVisible === true && calendarScreen === mockScreen2,
                    "visible=" + calendarVisible + ", screen=" + (calendarScreen ? calendarScreen.name : "null"));

                // Disconnect Screen 2 (active calendar monitor removed)
                activeScreens = [mockScreen3];
                handleScreensChanged();
                assertCondition("CHAL.M4.DISC.03", "Disconnecting active Screen 2 immediately dismisses calendar",
                    calendarVisible === false && calendarScreen === null,
                    "visible=" + calendarVisible + ", screen=" + calendarScreen);

                // Reconnect all screens
                activeScreens = [mockScreen1, mockScreen2, mockScreen3];
                handleScreensChanged();
                assertCondition("CHAL.M4.DISC.04", "Screen reconnection while closed does not spontaneously reopen",
                    calendarVisible === false && calendarScreen === null,
                    "visible=" + calendarVisible);

                // Open calendar on Screen 3, then remove all screens
                toggleCalendar(mockScreen3);
                activeScreens = [];
                handleScreensChanged();
                assertCondition("CHAL.M4.DISC.05", "Disconnecting all screens gracefully closes calendar",
                    calendarVisible === false && calendarScreen === null,
                    "visible=" + calendarVisible);

                // Restore screens
                activeScreens = [mockScreen1, mockScreen2, mockScreen3];

                scheduleNext(20, 4);
                break;

            case 4:
                console.log("--- PHASE 5: ClockWidget Signal Propagation & CalendarPopup Interactions ---");

                // Reset
                calendarVisible = false;
                calendarScreen = null;
                currentFocusedMonitor = mockScreen1;

                // Test 5.1: ClockWidget toggleCalendar signal fires and toggles calendar
                let clockFired = false;
                testClock.onToggleCalendar.connect(function() {
                    clockFired = true;
                });
                testClock.toggleCalendar();
                assertCondition("CHAL.M4.WIDGET.01", "ClockWidget toggleCalendar signal emission opens calendar",
                    clockFired === true && calendarVisible === true && calendarScreen === mockScreen1,
                    "clockFired=" + clockFired + ", visible=" + calendarVisible);

                // Test 5.2: CalendarPopup closeRequested signal fires and triggers closeCalendar
                testPopup.closeRequested();
                assertCondition("CHAL.M4.WIDGET.02", "CalendarPopup closeRequested signal dismisses calendar",
                    calendarVisible === false && calendarScreen === null,
                    "visible=" + calendarVisible);

                // Test 5.3: CalendarPopup interactive navigation integrity
                const initialYear = testPopup.viewYear;
                const initialMonth = testPopup.viewMonth;

                // Advance 12 months -> exactly 1 year later, same month
                for (let i = 0; i < 12; ++i) {
                    testPopup.nextMonth();
                }
                assertCondition("CHAL.M4.NAV.01", "Advancing 12 months increments viewYear by 1 with invariant month",
                    testPopup.viewYear === initialYear + 1 && testPopup.viewMonth === initialMonth,
                    "viewYear=" + testPopup.viewYear + ", viewMonth=" + testPopup.viewMonth);

                // Rewind 24 months -> exactly 1 year earlier than initial, same month
                for (let i = 0; i < 24; ++i) {
                    testPopup.previousMonth();
                }
                assertCondition("CHAL.M4.NAV.02", "Rewinding 24 months decrements viewYear by 1 with invariant month",
                    testPopup.viewYear === initialYear - 1 && testPopup.viewMonth === initialMonth,
                    "viewYear=" + testPopup.viewYear + ", viewMonth=" + testPopup.viewMonth);

                // Reset to today restores initial year and month
                testPopup.resetToToday();
                assertCondition("CHAL.M4.NAV.03", "resetToToday restores current year and month",
                    testPopup.viewYear === initialYear && testPopup.viewMonth === initialMonth,
                    "viewYear=" + testPopup.viewYear + ", viewMonth=" + testPopup.viewMonth);

                // Test 5.4: Grid invariance under year boundary
                // View December 2026
                testPopup.viewYear = 2026;
                testPopup.viewMonth = 11;
                assertCondition("CHAL.M4.NAV.04", "Dec 2026 grid contains exactly 42 cells",
                    testPopup.gridCells.length === 42, "length=" + testPopup.gridCells.length);

                testPopup.nextMonth(); // Jan 2027
                assertCondition("CHAL.M4.NAV.05", "nextMonth rolls to Jan 2027 with 42 cells",
                    testPopup.viewYear === 2027 && testPopup.viewMonth === 0 && testPopup.gridCells.length === 42,
                    "viewYear=" + testPopup.viewYear + ", viewMonth=" + testPopup.viewMonth + ", cells=" + testPopup.gridCells.length);

                testPopup.previousMonth(); // Dec 2026
                assertCondition("CHAL.M4.NAV.06", "previousMonth rolls back to Dec 2026",
                    testPopup.viewYear === 2026 && testPopup.viewMonth === 11,
                    "viewYear=" + testPopup.viewYear + ", viewMonth=" + testPopup.viewMonth);

                testPopup.resetToToday();

                console.log("================================================================");
                console.log("RESULTS: Passed=" + passCount + ", Failed=" + failCount);
                if (failCount === 0) {
                    console.log("=== PASS: CHALLENGER EMPIRICAL STRESS HARNESS SUCCESSFUL ===");
                } else {
                    console.error("=== ASSERTION_FAILED: " + failCount + " challenger tests failed ===");
                }
                console.log("================================================================");

                Qt.quit();
                break;
        }
    }
}
