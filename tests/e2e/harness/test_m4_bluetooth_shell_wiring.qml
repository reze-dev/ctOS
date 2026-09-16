pragma ComponentBehavior: Bound

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

    function assertCondition(idStr, desc, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
            results.push({ id: idStr, desc: desc, passed: true, details: details });
        } else {
            failCount++;
            console.error("[FAIL] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
            results.push({ id: idStr, desc: desc, passed: false, details: details });
        }
    }

    // =========================================================================
    // Shell State & Methods under Test (Mirroring shell.qml)
    // =========================================================================
    property bool calendarVisible: false
    property var calendarScreen: null

    property bool bluetoothVisible: false
    property var bluetoothScreen: null

    readonly property var mockScreenA: ({ name: "eDP-1", model: "Internal eDP" })
    readonly property var mockScreenB: ({ name: "DP-1", model: "External Display" })
    property var simulatedScreens: [mockScreenA, mockScreenB]

    function resolveTargetScreen(): var {
        if (!simulatedScreens || simulatedScreens.length === 0) {
            return null;
        }
        return simulatedScreens[0];
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
            testWindow.closeBluetooth();
            testWindow.calendarScreen = resolved;
            testWindow.calendarVisible = true;
        }
    }

    function closeCalendar(): void {
        testWindow.calendarVisible = false;
        testWindow.calendarScreen = null;
    }

    function toggleBluetooth(targetScreen): void {
        const resolved = (targetScreen !== null && targetScreen !== undefined)
            ? targetScreen
            : testWindow.resolveTargetScreen();

        if (testWindow.bluetoothVisible) {
            if (targetScreen === null || targetScreen === undefined || testWindow.bluetoothScreen === resolved) {
                testWindow.bluetoothVisible = false;
                testWindow.bluetoothScreen = null;
            } else {
                testWindow.bluetoothScreen = resolved;
            }
        } else {
            testWindow.closeCalendar();
            testWindow.bluetoothScreen = resolved;
            testWindow.bluetoothVisible = true;
        }
    }

    function closeBluetooth(): void {
        testWindow.bluetoothVisible = false;
        testWindow.bluetoothScreen = null;
    }

    function closeAllPopups(): void {
        testWindow.closeCalendar();
        testWindow.closeBluetooth();
    }

    function handleScreensChanged(): void {
        if (testWindow.calendarVisible) {
            const currentCal = testWindow.calendarScreen;
            if (!currentCal) {
                testWindow.closeCalendar();
            } else {
                let isAlive = false;
                for (let i = 0; i < testWindow.simulatedScreens.length; ++i) {
                    if (testWindow.simulatedScreens[i] && testWindow.simulatedScreens[i].name === currentCal.name) {
                        isAlive = true;
                        break;
                    }
                }
                if (!isAlive) {
                    testWindow.closeCalendar();
                }
            }
        }

        if (testWindow.bluetoothVisible) {
            const currentBt = testWindow.bluetoothScreen;
            if (!currentBt) {
                testWindow.closeBluetooth();
            } else {
                let isAlive = false;
                for (let i = 0; i < testWindow.simulatedScreens.length; ++i) {
                    if (testWindow.simulatedScreens[i] && testWindow.simulatedScreens[i].name === currentBt.name) {
                        isAlive = true;
                        break;
                    }
                }
                if (!isAlive) {
                    testWindow.closeBluetooth();
                }
            }
        }
    }

    // =========================================================================
    // Component Host Bindings
    // =========================================================================
    BluetoothPopup {
        id: btPopup
        anchors.centerIn: parent
        onCloseRequested: testWindow.closeBluetooth()
    }

    CalendarPopup {
        id: calPopup
        anchors.centerIn: parent
        visible: false
        onCloseRequested: testWindow.closeCalendar()
    }

    Timer {
        id: testRunner
        interval: 50
        running: true
        repeat: false

        onTriggered: {
            console.log("================================================================");
            console.log("=== SHELL WIRING & MULTI-MONITOR HARNESS: BLUETOOTH (M4) =======");
            console.log("================================================================");

            // =================================================================
            // 1. Initial State Invariants
            // =================================================================
            assertCondition("BT.WIRE.INIT.01", "Bluetooth initial visible is false",
                testWindow.bluetoothVisible === false && testWindow.bluetoothScreen === null,
                "visible=" + testWindow.bluetoothVisible);

            assertCondition("BT.WIRE.INIT.02", "Calendar initial visible is false",
                testWindow.calendarVisible === false && testWindow.calendarScreen === null,
                "visible=" + testWindow.calendarVisible);

            // =================================================================
            // 2. Multi-Monitor Screen Routing for Bluetooth
            // =================================================================
            testWindow.toggleBluetooth(testWindow.mockScreenA);
            assertCondition("BT.WIRE.ROUT.01", "toggleBluetooth opens popup on Screen A",
                testWindow.bluetoothVisible === true && testWindow.bluetoothScreen === testWindow.mockScreenA,
                "visible=" + testWindow.bluetoothVisible + ", screen=" + (testWindow.bluetoothScreen ? testWindow.bluetoothScreen.name : "null"));

            // Toggle again on same screen dismisses it
            testWindow.toggleBluetooth(testWindow.mockScreenA);
            assertCondition("BT.WIRE.ROUT.02", "toggleBluetooth again on Screen A closes popup",
                testWindow.bluetoothVisible === false && testWindow.bluetoothScreen === null,
                "visible=" + testWindow.bluetoothVisible);

            // Re-open on Screen A, then transfer to Screen B
            testWindow.toggleBluetooth(testWindow.mockScreenA);
            testWindow.toggleBluetooth(testWindow.mockScreenB);
            assertCondition("BT.WIRE.ROUT.03", "toggleBluetooth on Screen B transfers popup without closing",
                testWindow.bluetoothVisible === true && testWindow.bluetoothScreen === testWindow.mockScreenB,
                "visible=" + testWindow.bluetoothVisible + ", screen=" + (testWindow.bluetoothScreen ? testWindow.bluetoothScreen.name : "null"));

            // closeBluetooth method resets state
            testWindow.closeBluetooth();
            assertCondition("BT.WIRE.ROUT.04", "closeBluetooth resets visible and screen to null",
                testWindow.bluetoothVisible === false && testWindow.bluetoothScreen === null,
                "visible=" + testWindow.bluetoothVisible);

            // =================================================================
            // 3. IPC Endpoint Behavior (null target resolution)
            // =================================================================
            testWindow.toggleBluetooth(null);
            assertCondition("BT.WIRE.IPC.01", "IPC toggle with null target resolves default screen",
                testWindow.bluetoothVisible === true && testWindow.bluetoothScreen !== null && testWindow.bluetoothScreen.name === "eDP-1",
                "screen=" + (testWindow.bluetoothScreen ? testWindow.bluetoothScreen.name : "null"));

            testWindow.toggleBluetooth(null);
            assertCondition("BT.WIRE.IPC.02", "IPC toggle with null target closes popup if already open",
                testWindow.bluetoothVisible === false && testWindow.bluetoothScreen === null,
                "visible=" + testWindow.bluetoothVisible);

            // =================================================================
            // 4. Mutual Exclusivity between Bluetooth and Calendar Popups
            // =================================================================
            // Open Calendar first
            testWindow.toggleCalendar(testWindow.mockScreenA);
            assertCondition("BT.WIRE.MUTUAL.01", "Calendar popup is open on Screen A",
                testWindow.calendarVisible === true && testWindow.calendarScreen === testWindow.mockScreenA,
                "calendarVisible=" + testWindow.calendarVisible);

            // Opening Bluetooth must automatically close Calendar
            testWindow.toggleBluetooth(testWindow.mockScreenA);
            assertCondition("BT.WIRE.MUTUAL.02", "Opening Bluetooth automatically closes Calendar",
                testWindow.bluetoothVisible === true && testWindow.calendarVisible === false && testWindow.calendarScreen === null,
                "btVisible=" + testWindow.bluetoothVisible + ", calVisible=" + testWindow.calendarVisible);

            // Opening Calendar must automatically close Bluetooth
            testWindow.toggleCalendar(testWindow.mockScreenB);
            assertCondition("BT.WIRE.MUTUAL.03", "Opening Calendar automatically closes Bluetooth",
                testWindow.calendarVisible === true && testWindow.bluetoothVisible === false && testWindow.bluetoothScreen === null,
                "calVisible=" + testWindow.calendarVisible + ", btVisible=" + testWindow.bluetoothVisible);

            testWindow.closeCalendar();

            // =================================================================
            // 5. OverlayController Preemption (Command Deck / System Rail)
            // =================================================================
            testWindow.toggleBluetooth(testWindow.mockScreenA);
            assertCondition("BT.WIRE.PREEMPT.01", "Bluetooth popup is open prior to overlay trigger",
                testWindow.bluetoothVisible === true,
                "btVisible=" + testWindow.bluetoothVisible);

            // Simulate overlay opened
            testWindow.closeAllPopups();
            assertCondition("BT.WIRE.PREEMPT.02", "Overlay preemption closes both Bluetooth and Calendar popups",
                testWindow.bluetoothVisible === false && testWindow.calendarVisible === false,
                "btVisible=" + testWindow.bluetoothVisible + ", calVisible=" + testWindow.calendarVisible);

            // =================================================================
            // 6. Multi-Monitor Disconnect Cleanup
            // =================================================================
            // Open on external monitor Screen B
            testWindow.simulatedScreens = [testWindow.mockScreenA, testWindow.mockScreenB];
            testWindow.toggleBluetooth(testWindow.mockScreenB);
            assertCondition("BT.WIRE.DISC.01", "Bluetooth opened on external monitor Screen B",
                testWindow.bluetoothVisible === true && testWindow.bluetoothScreen === testWindow.mockScreenB,
                "screen=" + (testWindow.bluetoothScreen ? testWindow.bluetoothScreen.name : "null"));

            // External monitor unplugged
            testWindow.simulatedScreens = [testWindow.mockScreenA];
            testWindow.handleScreensChanged();
            assertCondition("BT.WIRE.DISC.02", "Monitor disconnect resets bluetoothVisible to false and screen to null",
                testWindow.bluetoothVisible === false && testWindow.bluetoothScreen === null,
                "visible=" + testWindow.bluetoothVisible + ", screen=" + testWindow.bluetoothScreen);

            // =================================================================
            // 7. Component Signal Wiring (closeRequested)
            // =================================================================
            testWindow.toggleBluetooth(testWindow.mockScreenA);
            assertCondition("BT.WIRE.SIG.01", "Bluetooth open before closeRequested",
                testWindow.bluetoothVisible === true,
                "visible=" + testWindow.bluetoothVisible);

            btPopup.closeRequested();
            assertCondition("BT.WIRE.SIG.02", "BluetoothPopup closeRequested invokes closeBluetooth",
                testWindow.bluetoothVisible === false && testWindow.bluetoothScreen === null,
                "visible=" + testWindow.bluetoothVisible);

            console.log("================================================================");
            console.log("RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: SHELL WIRING BLUETOOTH M4 HARNESS SUCCESSFUL ===");
            } else {
                console.error("=== FAIL: SHELL WIRING BLUETOOTH M4 HARNESS FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
