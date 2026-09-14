import QtQuick
import QtQuick.Layouts
import Quickshell
import desktop.services
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

    DynamicIsland {
        id: island
        anchors.centerIn: parent
    }

    property int testPhase: 0
    property real phaseStartTime: 0

    Timer {
        id: sequencer
        interval: 100
        repeat: false
        running: true
        onTriggered: runPhase()
    }

    function runPhase() {
        testPhase++;

        if (testPhase === 1) {
            console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER: TIMER BURST & RESET VERIFICATION ===");
            console.log("================================================================");

            // Phase 1: Fire initial notification
            phaseStartTime = Date.now();
            island.showNotification("BurstStart", "Message 1", 1);
            assertCondition("BURST.P1.EXPANDED", "Initial notification expanded island",
                island.isExpanded === true,
                "isExpanded=" + island.isExpanded);

            // Wait 2000ms (halfway through 4000ms timer), then send notification 2
            sequencer.interval = 2000;
            sequencer.restart();
        }
        else if (testPhase === 2) {
            const elapsed1 = Date.now() - phaseStartTime;
            console.log("Phase 2 reached at elapsed=" + elapsed1 + "ms");

            // Island should still be expanded
            assertCondition("BURST.P2.STILL_EXPANDED", "Island still expanded at 2s",
                island.isExpanded === true,
                "isExpanded=" + island.isExpanded + ", elapsed=" + elapsed1 + "ms");

            // Now send second notification — this MUST restart the 4000ms timer
            island.showNotification("BurstSecond", "Message 2 (Reset Timer)", 1);
            phaseStartTime = Date.now();

            // Wait 3000ms (total from first notif = 5000ms).
            // If timer did NOT reset, it would have collapsed at 4000ms (1000ms ago)!
            sequencer.interval = 3000;
            sequencer.restart();
        }
        else if (testPhase === 3) {
            const elapsed2 = Date.now() - phaseStartTime;
            console.log("Phase 3 reached at elapsed=" + elapsed2 + "ms from reset");

            // Island MUST still be expanded because timer was reset and 3000ms < 4000ms!
            assertCondition("BURST.P3.RESET_SURVIVED_ORIGINAL_TIMEOUT",
                "Timer successfully restarted: Island remained expanded past original 4s deadline",
                island.isExpanded === true,
                "isExpanded=" + island.isExpanded + ", elapsed=" + elapsed2 + "ms");

            // Now wait another 1500ms (total 4500ms after reset). It MUST have collapsed!
            sequencer.interval = 1500;
            sequencer.restart();
        }
        else if (testPhase === 4) {
            const totalElapsedSinceReset = Date.now() - phaseStartTime;
            console.log("Phase 4 reached at elapsed=" + totalElapsedSinceReset + "ms from reset");

            // Island MUST have collapsed
            assertCondition("BURST.P4.COLLAPSED_AFTER_FULL_TIMEOUT",
                "Island auto-collapsed to compact state after full 4000ms timeout",
                island.isExpanded === false,
                "isExpanded=" + island.isExpanded + ", elapsed=" + totalElapsedSinceReset + "ms");

            // Phase 5: Fast rapid-fire burst test (20 notifications in 100ms)
            for (let i = 1; i <= 20; ++i) {
                island.showNotification("Rapid_" + i, "Payload " + i, (i % 3));
            }

            assertCondition("BURST.P5.RAPID_BURST_INGESTION",
                "Rapid fire of 20 notifications processed without hanging",
                island.isExpanded === true && island.latestAppName === "Rapid_20",
                "isExpanded=" + island.isExpanded + ", latestApp=" + island.latestAppName);

            // Print summary
            console.log("================================================================");
            console.log("RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: TIMER RESET & BURST STRESS FULLY VERIFIED ===");
            } else {
                console.error("=== FAIL: TIMER RESET & BURST STRESS FAILED ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
