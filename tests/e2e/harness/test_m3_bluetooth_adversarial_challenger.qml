pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
import desktop.core
import desktop.surfaces
import desktop.surfaces.components

FloatingWindow {
    id: testWindow
    visible: true
    implicitWidth: 1000
    implicitHeight: 800

    property int passCount: 0
    property int failCount: 0

    function assertCondition(idStr, desc, condition, details) {
        if (condition) {
            passCount++;
            console.log("[PASS] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
        } else {
            failCount++;
            console.error("[FAIL] " + idStr + ": " + desc + (details ? " (" + details + ")" : ""));
        }
    }

    // =========================================================================
    // Component Rigs
    // =========================================================================
    property int popupCloseRequestedCount: 0

    BluetoothPopup {
        id: testPopup
        onCloseRequested: {
            testWindow.popupCloseRequestedCount++;
        }
    }

    AmbientBar {
        id: testAmbientBar
        visible: false
    }

    // =========================================================================
    // Shell Simulation State & Logic Under Adversarial Stress
    // =========================================================================
    property bool calendarVisible: false
    property var calendarScreen: null

    property bool bluetoothVisible: false
    property var bluetoothScreen: null

    readonly property var mockScreenA: ({ name: "eDP-1", model: "Internal Laptop" })
    readonly property var mockScreenB: ({ name: "DP-1", model: "External Display" })
    readonly property var mockScreenC: ({ name: "HDMI-A-1", model: "Conference TV" })

    property var simulatedScreens: [mockScreenA, mockScreenB]
    property var simulatedFocusedMonitor: ({ name: "eDP-1" })

    function resolveTargetScreen(): var {
        const screenList = testWindow.simulatedScreens;
        if (!screenList || screenList.length === 0) {
            return null;
        }

        if (testWindow.simulatedFocusedMonitor && testWindow.simulatedFocusedMonitor.name) {
            const focusedName = testWindow.simulatedFocusedMonitor.name;
            for (let i = 0; i < screenList.length; ++i) {
                const s = screenList[i];
                if (s && s.name === focusedName) {
                    return s;
                }
            }
        }

        return screenList[0] || null;
    }

    function toggleCalendar(targetScreen): void {
        const resolved = (targetScreen !== null && targetScreen !== undefined) ? targetScreen : testWindow.resolveTargetScreen();

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
        const resolved = (targetScreen !== null && targetScreen !== undefined) ? targetScreen : testWindow.resolveTargetScreen();

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

    function simulateScreensChanged(): void {
        if (testWindow.calendarVisible) {
            const currentCalScreen = testWindow.calendarScreen;
            if (!currentCalScreen) {
                testWindow.closeCalendar();
            } else {
                const screenList = testWindow.simulatedScreens;
                let isCalAlive = false;
                for (let i = 0; i < screenList.length; ++i) {
                    if (screenList[i] && screenList[i].name === currentCalScreen.name) {
                        isCalAlive = true;
                        break;
                    }
                }
                if (!isCalAlive) {
                    testWindow.closeCalendar();
                }
            }
        }

        if (testWindow.bluetoothVisible) {
            const currentBtScreen = testWindow.bluetoothScreen;
            if (!currentBtScreen) {
                testWindow.closeBluetooth();
                return;
            }

            const screenList = testWindow.simulatedScreens;
            let isBtAlive = false;
            for (let i = 0; i < screenList.length; ++i) {
                if (screenList[i] && screenList[i].name === currentBtScreen.name) {
                    isBtAlive = true;
                    break;
                }
            }

            if (!isBtAlive) {
                testWindow.closeBluetooth();
            }
        }
    }

    Timer {
        id: testRunner
        interval: 100
        running: true
        repeat: false

        onTriggered: {
            console.log("================================================================");
            console.log("=== ADVERSARIAL CHALLENGER 2: MILESTONE 3 STRESS HARNESS ===");
            console.log("================================================================");

            // =================================================================
            // TEST SUITE 1: Click Propagation & Isolation (MouseArea preventStealing)
            // =================================================================
            console.log("--- TEST SUITE 1: Click Propagation & Isolation ---");

            // Inspect BluetoothPopup root MouseArea
            let rootMouseArea = null;
            for (let i = 0; i < testPopup.children.length; ++i) {
                let child = testPopup.children[i];
                if (child && child.toString().indexOf("QQuickMouseArea") !== -1 && child.preventStealing !== undefined) {
                    rootMouseArea = child;
                    break;
                }
            }

            assertCondition("ADV.CLICK.01", "BluetoothPopup contains root MouseArea with preventStealing=true",
                rootMouseArea !== null && rootMouseArea.preventStealing === true,
                "rootMouseArea=" + rootMouseArea + ", preventStealing=" + (rootMouseArea ? rootMouseArea.preventStealing : "null"));

            assertCondition("ADV.CLICK.02", "BluetoothPopup root MouseArea fills parent",
                rootMouseArea !== null && rootMouseArea.width === testPopup.width && rootMouseArea.height === testPopup.height,
                "width=" + (rootMouseArea ? rootMouseArea.width : 0) + ", height=" + (rootMouseArea ? rootMouseArea.height : 0));

            assertCondition("ADV.CLICK.03", "BluetoothPopup root MouseArea has hoverEnabled=true",
                rootMouseArea !== null && rootMouseArea.hoverEnabled === true,
                "hoverEnabled=" + (rootMouseArea ? rootMouseArea.hoverEnabled : "null"));

            // Locate mainColumn and headerRow controls
            let mainColumn = null;
            for (let i = 0; i < testPopup.children.length; ++i) {
                let child = testPopup.children[i];
                if (child && child.toString().indexOf("QQuickColumnLayout") !== -1) {
                    mainColumn = child;
                    break;
                }
            }
            assertCondition("ADV.CLICK.04", "BluetoothPopup mainColumn located",
                mainColumn !== null, "mainColumn=" + mainColumn);

            let headerRow = mainColumn ? mainColumn.children[0] : null;
            assertCondition("ADV.CLICK.05", "Header RowLayout located",
                headerRow !== null, "headerRow=" + headerRow);

            function findMouseArea(parentItem) {
                if (!parentItem || !parentItem.children) return null;
                for (let i = 0; i < parentItem.children.length; ++i) {
                    let child = parentItem.children[i];
                    if (child && child.toString().indexOf("QQuickMouseArea") !== -1) {
                        return child;
                    }
                }
                return null;
            }

            let powerBtn = null;
            let scanBtn = null;
            let closeBtn = null;
            if (headerRow) {
                for (let c = 0; c < headerRow.children.length; ++c) {
                    let item = headerRow.children[c];
                    if (item && item.toString().indexOf("QQuickRectangle") !== -1) {
                        if (!powerBtn) powerBtn = item;
                        else if (!scanBtn) scanBtn = item;
                        else if (!closeBtn) closeBtn = item;
                    }
                }
            }

            assertCondition("ADV.CLICK.06", "Header contains powerBtn, scanBtn, closeBtn",
                powerBtn !== null && scanBtn !== null && closeBtn !== null,
                "powerBtn=" + powerBtn + ", scanBtn=" + scanBtn + ", closeBtn=" + closeBtn);

            let powerMouse = findMouseArea(powerBtn);
            let scanMouse = findMouseArea(scanBtn);
            let closeMouse = findMouseArea(closeBtn);

            assertCondition("ADV.CLICK.07", "Header buttons define interactive MouseAreas",
                powerMouse !== null && scanMouse !== null && closeMouse !== null,
                "powerMouse=" + powerMouse + ", scanMouse=" + scanMouse + ", closeMouse=" + closeMouse);

            assertCondition("ADV.CLICK.08", "Header buttons use PointingHandCursor",
                powerMouse && scanMouse && closeMouse &&
                powerMouse.cursorShape === Qt.PointingHandCursor && scanMouse.cursorShape === Qt.PointingHandCursor && closeMouse.cursorShape === Qt.PointingHandCursor,
                "powerCursor=" + (powerMouse ? powerMouse.cursorShape : "null") + ", scanCursor=" + (scanMouse ? scanMouse.cursorShape : "null") + ", closeCursor=" + (closeMouse ? closeMouse.cursorShape : "null"));

            // Test closeRequested signal trigger via close button MouseArea
            testWindow.popupCloseRequestedCount = 0;
            if (closeMouse) {
                closeMouse.clicked(null);
            }
            assertCondition("ADV.CLICK.09", "Clicking [x] close button triggers closeRequested signal",
                testWindow.popupCloseRequestedCount === 1,
                "popupCloseRequestedCount=" + testWindow.popupCloseRequestedCount);

            // Repeat to ensure clean signal dispatch without accumulation
            if (closeMouse) {
                closeMouse.clicked(null);
            }
            assertCondition("ADV.CLICK.10", "Subsequent [x] click increments closeRequested count",
                testWindow.popupCloseRequestedCount === 2,
                "popupCloseRequestedCount=" + testWindow.popupCloseRequestedCount);

            // =================================================================
            // TEST SUITE 2: AmbientBar Left-Click vs Right-Click
            // =================================================================
            console.log("--- TEST SUITE 2: AmbientBar Left vs Right Click ---");

            let rightSections = testAmbientBar.contentItem.children[2];
            let btSection = rightSections.children[3];
            let btMouseArea = btSection.children[1];

            assertCondition("ADV.BAR.01", "bluetoothSection contains bluetoothMouseArea",
                btMouseArea !== null && btMouseArea !== undefined,
                "btMouseArea=" + btMouseArea);

            assertCondition("ADV.BAR.02", "bluetoothMouseArea accepts LeftButton and RightButton",
                (btMouseArea.acceptedButtons & Qt.LeftButton) !== 0 && (btMouseArea.acceptedButtons & Qt.RightButton) !== 0,
                "acceptedButtons=" + btMouseArea.acceptedButtons);

            assertCondition("ADV.BAR.03", "bluetoothMouseArea has cursorShape PointingHandCursor and hoverEnabled",
                btMouseArea.cursorShape === Qt.PointingHandCursor && btMouseArea.hoverEnabled === true,
                "cursorShape=" + btMouseArea.cursorShape + ", hoverEnabled=" + btMouseArea.hoverEnabled);

            // Verify AmbientBar declares signal toggleBluetooth
            let barSignalFired = false;
            let conn = testAmbientBar.toggleBluetooth.connect(function() {
                barSignalFired = true;
            });
            testAmbientBar.toggleBluetooth();
            assertCondition("ADV.BAR.04", "AmbientBar declares callable toggleBluetooth signal",
                barSignalFired === true,
                "barSignalFired=" + barSignalFired);

            // Verify visibility coupling to BluetoothService.available
            BluetoothService._parseShowOutput("No default controller available\n");
            assertCondition("ADV.BAR.05", "bluetoothSection visibility hides when BluetoothService.available is false",
                btSection.visible === false,
                "visible=" + btSection.visible);

            BluetoothService._parseShowOutput("Controller AA:BB:CC:DD:EE:FF Host\n\tPowered: yes\n");
            assertCondition("ADV.BAR.06", "bluetoothSection visibility restores when BluetoothService.available is true",
                btSection.visible === true,
                "visible=" + btSection.visible);

            // =================================================================
            // TEST SUITE 3: Rapid toggleBluetooth Calls & Stress Invariants
            // =================================================================
            console.log("--- TEST SUITE 3: Rapid toggleBluetooth Stress ---");

            // Reset state
            testWindow.closeAllPopups();
            assertCondition("ADV.RAPID.01", "Initial popups state is closed",
                testWindow.bluetoothVisible === false && testWindow.calendarVisible === false,
                "btVis=" + testWindow.bluetoothVisible + ", calVis=" + testWindow.calendarVisible);

            // 100 rapid sequential toggles on Screen A
            for (let i = 0; i < 100; ++i) {
                testWindow.toggleBluetooth(testWindow.mockScreenA);
            }
            assertCondition("ADV.RAPID.02", "100 sequential toggles on Screen A leaves bluetooth closed (even count)",
                testWindow.bluetoothVisible === false && testWindow.bluetoothScreen === null,
                "visible=" + testWindow.bluetoothVisible + ", screen=" + testWindow.bluetoothScreen);

            // 101st toggle opens it
            testWindow.toggleBluetooth(testWindow.mockScreenA);
            assertCondition("ADV.RAPID.03", "101st toggle opens bluetooth on Screen A",
                testWindow.bluetoothVisible === true && testWindow.bluetoothScreen === testWindow.mockScreenA,
                "visible=" + testWindow.bluetoothVisible + ", screen=" + (testWindow.bluetoothScreen ? testWindow.bluetoothScreen.name : "null"));

            // Rapid alternating screens: Screen A -> Screen B -> Screen C
            testWindow.toggleBluetooth(testWindow.mockScreenB);
            assertCondition("ADV.RAPID.04", "Switching to Screen B while open transfers screen to Screen B",
                testWindow.bluetoothVisible === true && testWindow.bluetoothScreen === testWindow.mockScreenB,
                "visible=" + testWindow.bluetoothVisible + ", screen=" + (testWindow.bluetoothScreen ? testWindow.bluetoothScreen.name : "null"));

            testWindow.toggleBluetooth(testWindow.mockScreenC);
            assertCondition("ADV.RAPID.05", "Switching to Screen C while open transfers screen to Screen C",
                testWindow.bluetoothVisible === true && testWindow.bluetoothScreen === testWindow.mockScreenC,
                "visible=" + testWindow.bluetoothVisible + ", screen=" + (testWindow.bluetoothScreen ? testWindow.bluetoothScreen.name : "null"));

            // Toggling again on same screen (Screen C) closes it
            testWindow.toggleBluetooth(testWindow.mockScreenC);
            assertCondition("ADV.RAPID.06", "Toggling on same screen (Screen C) closes bluetooth",
                testWindow.bluetoothVisible === false && testWindow.bluetoothScreen === null,
                "visible=" + testWindow.bluetoothVisible + ", screen=" + testWindow.bluetoothScreen);

            // Mutual Preemption stress: 50 interleaved toggles of calendar and bluetooth
            let mutualExclusivityBroken = false;
            for (let i = 0; i < 50; ++i) {
                if (i % 2 === 0) {
                    testWindow.toggleBluetooth(testWindow.mockScreenA);
                } else {
                    testWindow.toggleCalendar(testWindow.mockScreenA);
                }
                if (testWindow.bluetoothVisible && testWindow.calendarVisible) {
                    mutualExclusivityBroken = true;
                    break;
                }
            }
            assertCondition("ADV.RAPID.07", "Mutual exclusivity holds under 50 rapid interleaved toggles",
                mutualExclusivityBroken === false,
                "mutualExclusivityBroken=" + mutualExclusivityBroken);

            // Reset
            testWindow.closeAllPopups();
            assertCondition("ADV.RAPID.08", "closeAllPopups dismisses both calendar and bluetooth",
                testWindow.bluetoothVisible === false && testWindow.calendarVisible === false,
                "btVis=" + testWindow.bluetoothVisible + ", calVis=" + testWindow.calendarVisible);

            // =================================================================
            // TEST SUITE 4: IPC Handler & Multi-Screen Hotplug (screensChanged)
            // =================================================================
            console.log("--- TEST SUITE 4: IPC & screensChanged Hotplug ---");

            // IPC toggle with null target screen resolves default screen
            testWindow.simulatedScreens = [testWindow.mockScreenA, testWindow.mockScreenB];
            testWindow.simulatedFocusedMonitor = testWindow.mockScreenB;

            testWindow.toggleBluetooth(null);
            assertCondition("ADV.IPC.01", "IPC toggle with null target resolves focused monitor (Screen B)",
                testWindow.bluetoothVisible === true && testWindow.bluetoothScreen === testWindow.mockScreenB,
                "screen=" + (testWindow.bluetoothScreen ? testWindow.bluetoothScreen.name : "null"));

            // IPC toggle again with null closes it
            testWindow.toggleBluetooth(null);
            assertCondition("ADV.IPC.02", "IPC toggle again with null closes bluetooth",
                testWindow.bluetoothVisible === false && testWindow.bluetoothScreen === null,
                "visible=" + testWindow.bluetoothVisible);

            // Hotplug Screen Disconnection Test:
            // 1. Open bluetooth on Screen A
            testWindow.toggleBluetooth(testWindow.mockScreenA);
            assertCondition("ADV.HOTPLUG.01", "Bluetooth opened on Screen A",
                testWindow.bluetoothVisible === true && testWindow.bluetoothScreen === testWindow.mockScreenA,
                "screen=" + (testWindow.bluetoothScreen ? testWindow.bluetoothScreen.name : "null"));

            // 2. Unrelated screen disconnected (Screen B removed; Screen A remains)
            testWindow.simulatedScreens = [testWindow.mockScreenA];
            testWindow.simulateScreensChanged();
            assertCondition("ADV.HOTPLUG.02", "Unrelated screen disconnect leaves bluetooth open on Screen A",
                testWindow.bluetoothVisible === true && testWindow.bluetoothScreen === testWindow.mockScreenA,
                "visible=" + testWindow.bluetoothVisible + ", screen=" + (testWindow.bluetoothScreen ? testWindow.bluetoothScreen.name : "null"));

            // 3. Screen A disconnected (Screen C added; Screen A removed)
            testWindow.simulatedScreens = [testWindow.mockScreenC];
            testWindow.simulateScreensChanged();
            assertCondition("ADV.HOTPLUG.03", "Hosting screen disconnect dismisses bluetooth popup",
                testWindow.bluetoothVisible === false && testWindow.bluetoothScreen === null,
                "visible=" + testWindow.bluetoothVisible + ", screen=" + testWindow.bluetoothScreen);

            // 4. All screens disconnected (empty screen array)
            testWindow.toggleBluetooth(testWindow.mockScreenC);
            testWindow.simulatedScreens = [];
            testWindow.simulateScreensChanged();
            assertCondition("ADV.HOTPLUG.04", "Empty screens array gracefully dismisses bluetooth without crash",
                testWindow.bluetoothVisible === false && testWindow.bluetoothScreen === null,
                "visible=" + testWindow.bluetoothVisible);

            // 5. screensChanged while bluetooth already closed
            testWindow.simulateScreensChanged();
            assertCondition("ADV.HOTPLUG.05", "screensChanged when already closed is a clean no-op",
                testWindow.bluetoothVisible === false && testWindow.bluetoothScreen === null,
                "visible=" + testWindow.bluetoothVisible);

            // Restore live state
            BluetoothService.refresh();

            // =================================================================
            // Summary
            // =================================================================
            console.log("================================================================");
            console.log("CHALLENGER 2 ADVERSARIAL RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: ALL ADVERSARIAL STRESS CHALLENGES PASSED CLEANLY ===");
            } else {
                console.error("=== FAIL: ADVERSARIAL STRESS CHALLENGES FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
