import QtQuick
import Quickshell
import desktop.services
import desktop.core

Scope {
    id: root

    Item {
        id: container
        width: 360
        height: 800

        Loader {
            id: railLoader
            anchors.fill: parent
            source: "file:///home/reze/Projects/ctOS/shell/desktop/surfaces/SystemRail.qml"
        }
    }

    Timer {
        id: testTimer
        interval: 100
        running: true
        repeat: false

        onTriggered: {
            try {
                const railSurface = railLoader.item;
                // 1. Instantiation & Initial State
                if (!railSurface) {
                    console.error("ASSERTION_FAILED: SystemRail surface failed to instantiate from Loader (status=" + railLoader.status + ")");
                    Qt.quit();
                    return;
                }

                if (railSurface.width !== 360 || railSurface.implicitWidth !== 360) {
                    console.error("ASSERTION_FAILED: SystemRail root width must be 360");
                    Qt.quit();
                    return;
                }

                if (railSurface.selectedSsid !== "") {
                    console.error("ASSERTION_FAILED: selectedSsid should initially be empty");
                    Qt.quit();
                    return;
                }

                if (railSurface.confirmingForgetSsid !== "") {
                    console.error("ASSERTION_FAILED: confirmingForgetSsid should initially be empty");
                    Qt.quit();
                    return;
                }

                // 2. Navigation State Resets
                railSurface.selectedSsid = "KnownAP";
                railSurface.confirmingForgetSsid = "KnownAP";
                railSurface.navigateToWifi();

                if (railSurface.currentView !== "wifi") {
                    console.error("ASSERTION_FAILED: navigateToWifi failed to set currentView to wifi");
                    Qt.quit();
                    return;
                }
                if (railSurface.selectedSsid !== "" || railSurface.confirmingForgetSsid !== "") {
                    console.error("ASSERTION_FAILED: navigateToWifi must reset selectedSsid and confirmingForgetSsid");
                    Qt.quit();
                    return;
                }

                railSurface.selectedSsid = "ConnectedAP";
                railSurface.confirmingForgetSsid = "ConnectedAP";
                railSurface.navigateToMain();

                if (railSurface.currentView !== "main") {
                    console.error("ASSERTION_FAILED: navigateToMain failed to set currentView to main");
                    Qt.quit();
                    return;
                }
                if (railSurface.selectedSsid !== "" || railSurface.confirmingForgetSsid !== "") {
                    console.error("ASSERTION_FAILED: navigateToMain must reset selectedSsid and confirmingForgetSsid");
                    Qt.quit();
                    return;
                }

                // 3. Tiered Escape Unwinding
                railSurface.navigateToWifi();
                railSurface.selectedSsid = "CyberNet";
                railSurface.confirmingForgetSsid = "CyberNet";

                // Step A: Escape while confirming forget -> clears confirmingForgetSsid
                railSurface.handleEscape();
                if (railSurface.confirmingForgetSsid !== "") {
                    console.error("ASSERTION_FAILED: ESC should clear confirmingForgetSsid first");
                    Qt.quit();
                    return;
                }
                if (railSurface.selectedSsid !== "CyberNet") {
                    console.error("ASSERTION_FAILED: ESC while confirming forget must keep selectedSsid");
                    Qt.quit();
                    return;
                }

                // Step B: Escape while selected -> clears selectedSsid
                railSurface.handleEscape();
                if (railSurface.selectedSsid !== "") {
                    console.error("ASSERTION_FAILED: ESC should clear selectedSsid");
                    Qt.quit();
                    return;
                }
                if (railSurface.currentView !== "wifi") {
                    console.error("ASSERTION_FAILED: ESC while selected must keep currentView in wifi");
                    Qt.quit();
                    return;
                }

                // Step C: Escape in wifi view -> navigates to main
                railSurface.handleEscape();
                if (railSurface.currentView !== "main") {
                    console.error("ASSERTION_FAILED: ESC in wifi view should return to main");
                    Qt.quit();
                    return;
                }

                // 4. Overlay Closed Reset Hygiene
                OverlayController.openSystemRail();
                railSurface.navigateToWifi();
                railSurface.selectedSsid = "TestAP";
                railSurface.confirmingForgetSsid = "TestAP";
                OverlayController.close();

                if (railSurface.currentView !== "main" || railSurface.selectedSsid !== "" || railSurface.confirmingForgetSsid !== "") {
                    console.error("ASSERTION_FAILED: onOverlayClosed must reset currentView, selectedSsid, and confirmingForgetSsid");
                    Qt.quit();
                    return;
                }

                // 5. NetworkService Method Binding Verification
                if (typeof NetworkService.disconnectCurrentNetwork !== "function") {
                    console.error("ASSERTION_FAILED: NetworkService.disconnectCurrentNetwork is not a function");
                    Qt.quit();
                    return;
                }
                if (typeof NetworkService.forgetNetwork !== "function") {
                    console.error("ASSERTION_FAILED: NetworkService.forgetNetwork is not a function");
                    Qt.quit();
                    return;
                }
                if (typeof NetworkService.connectToNetwork !== "function") {
                    console.error("ASSERTION_FAILED: NetworkService.connectToNetwork is not a function");
                    Qt.quit();
                    return;
                }

                // Call without crash
                NetworkService.disconnectCurrentNetwork();
                NetworkService.forgetNetwork("NonExistentSSID");

                console.log("=== PASS: T6 WiFi Submenu Quickshell Headless Suite ===");
            } catch (err) {
                console.error("ASSERTION_FAILED: Unexpected error: " + err);
            }
            Qt.quit();
        }
    }
}
