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
        id: testHost
        anchors.fill: parent

        Loader {
            id: calendarLoader
            source: "file://" + (Quickshell.env("PROJECT_ROOT") || "/home/reze/Projects/ctOS") + "/shell/desktop/surfaces/components/NotchCalendarGrid.qml"
        }

        Loader {
            id: notchLoader
            source: "file://" + (Quickshell.env("PROJECT_ROOT") || "/home/reze/Projects/ctOS") + "/shell/desktop/surfaces/components/LivingNotch.qml"
        }
    }

    Timer {
        id: runner
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            console.log("================================================================");
            console.log("=== EMPIRICAL CHALLENGER: NOTCH CALENDAR DEEP ADVERSARIAL ======");
            console.log("================================================================");

            if (calendarLoader.status !== Loader.Ready || calendarLoader.item === null) {
                assertCondition("CHAL.LOAD.01", "NotchCalendarGrid loads successfully", false, "status=" + calendarLoader.status);
                Qt.quit();
                return;
            }

            var cal = calendarLoader.item;
            assertCondition("CHAL.LOAD.01", "NotchCalendarGrid loads successfully", true, "loaded");

            // -------------------------------------------------------------
            // Section 1: Exhaustive Gregorian & Leap Year Oracle Verification
            // -------------------------------------------------------------
            console.log("--- SECTION 1: Gregorian & Leap Year Mathematical Rigor ---");

            var sampleYears = [
                1600, 1700, 1800, 1900, 1904, 1996, 2000, 2004, 2020, 2024,
                2025, 2026, 2028, 2030, 2096, 2100, 2104, 2400
            ];

            var mathFailures = 0;
            var leapFailures = 0;
            var continuityFailures = 0;

            for (var y = 0; y < sampleYears.length; y++) {
                var year = sampleYears[y];
                var isLeap = (year % 4 === 0 && year % 100 !== 0) || (year % 400 === 0);

                for (var m = 0; m < 12; m++) {
                    var cells = cal.generateCalendarCells(year, m, 2026, 9, 1);
                    if (!cells || cells.length !== 42) {
                        mathFailures++;
                        continue;
                    }

                    // Check February days
                    if (m === 1) {
                        var febDays = cells.filter(c => c.isCurrentMonth).length;
                        var expectedDays = isLeap ? 29 : 28;
                        if (febDays !== expectedDays) {
                            leapFailures++;
                            console.error("Leap failure for year " + year + ": expected " + expectedDays + ", got " + febDays);
                        }
                    }

                    // Check day continuity: days must sequence 1..daysInMonth
                    var curDays = cells.filter(c => c.isCurrentMonth);
                    for (var d = 0; d < curDays.length; d++) {
                        if (curDays[d].day !== d + 1) {
                            continuityFailures++;
                            break;
                        }
                    }

                    // First day of current month position check
                    var firstDayDate = new Date(year, m, 1);
                    var expectedFirstIdx = (firstDayDate.getDay() + 6) % 7;
                    if (cells[expectedFirstIdx].day !== 1 || !cells[expectedFirstIdx].isCurrentMonth) {
                        mathFailures++;
                    }
                }
            }

            assertCondition("CHAL.MATH.01", "42-cell invariant hold across all 400-year cycle test years",
                mathFailures === 0, "mathFailures=" + mathFailures);

            assertCondition("CHAL.LEAP.01", "Gregorian leap year rules (4, 100, 400 rules) strictly satisfied",
                leapFailures === 0, "leapFailures=" + leapFailures);

            assertCondition("CHAL.CONT.01", "Day sequence monotonicity 1..daysInMonth hold across all months",
                continuityFailures === 0, "continuityFailures=" + continuityFailures);

            // -------------------------------------------------------------
            // Section 2: 'isToday' Strict Uniqueness and Isolation Oracles
            // -------------------------------------------------------------
            console.log("--- SECTION 2: isToday Strict Uniqueness & Isolation ---");

            var todayLeakCount = 0;
            // Test 1: For current month, varying todayDate from 1 to 31
            for (var testD = 1; testD <= 31; testD++) {
                var testCells = cal.generateCalendarCells(2026, 9, 2026, 9, testD); // Oct 2026 has 31 days
                var todayHits = testCells.filter(c => c.isToday);
                if (todayHits.length !== 1 || todayHits[0].day !== testD || !todayHits[0].isCurrentMonth) {
                    todayLeakCount++;
                }
            }

            // Test 2: For adjacent months, todayDate should NEVER match
            var prevMonthCells = cal.generateCalendarCells(2026, 8, 2026, 9, 1); // viewing Sept, today is Oct 1
            var prevTodayHits = prevMonthCells.filter(c => c.isToday);
            if (prevTodayHits.length !== 0) todayLeakCount++;

            var nextMonthCells = cal.generateCalendarCells(2026, 10, 2026, 9, 1); // viewing Nov, today is Oct 1
            var nextTodayHits = nextMonthCells.filter(c => c.isToday);
            if (nextTodayHits.length !== 0) todayLeakCount++;

            assertCondition("CHAL.TODAY.01", "isToday strictly unique (exactly 1 match for curMonth, 0 for otherMonth)",
                todayLeakCount === 0, "todayLeakCount=" + todayLeakCount);

            // -------------------------------------------------------------
            // Section 3: Navigation State Machine & Reactive Invariants
            // -------------------------------------------------------------
            console.log("--- SECTION 3: Navigation State Machine & Rollover ---");

            var origYear = cal.viewYear;
            var origMonth = cal.viewMonth;

            // 12 nextMonth() calls
            for (var n = 0; n < 12; n++) {
                cal.nextMonth();
            }
            assertCondition("CHAL.NAV.01", "12 nextMonth() calls increments viewYear by 1 and preserves viewMonth",
                cal.viewYear === origYear + 1 && cal.viewMonth === origMonth,
                "viewYear=" + cal.viewYear + ", viewMonth=" + cal.viewMonth);

            // 24 previousMonth() calls
            for (var p = 0; p < 24; p++) {
                cal.previousMonth();
            }
            assertCondition("CHAL.NAV.02", "24 previousMonth() calls decrements viewYear by 1 and preserves viewMonth",
                cal.viewYear === origYear - 1 && cal.viewMonth === origMonth,
                "viewYear=" + cal.viewYear + ", viewMonth=" + cal.viewMonth);

            // resetToToday() call
            cal.resetToToday();
            assertCondition("CHAL.NAV.03", "resetToToday() accurately restores viewYear and viewMonth",
                cal.viewYear === cal.todayYear && cal.viewMonth === cal.todayMonth,
                "viewYear=" + cal.viewYear + ", todayYear=" + cal.todayYear);

            // High cycle navigation stress (120 forward, 120 backward)
            for (var i = 0; i < 120; i++) cal.nextMonth();
            for (var j = 0; j < 120; j++) cal.previousMonth();
            assertCondition("CHAL.NAV.04", "120-month bidirectional burst navigation preserves origin",
                cal.viewYear === origYear && cal.viewMonth === origMonth,
                "viewYear=" + cal.viewYear + ", viewMonth=" + cal.viewMonth);

            // -------------------------------------------------------------
            // Section 4: Geometry, Integer Arithmetic & Coordinate Invariants
            // -------------------------------------------------------------
            console.log("--- SECTION 4: Geometry & Coordinate Invariants ---");

            var hasNaN = isNaN(cal.width) || isNaN(cal.height) || isNaN(cal.implicitWidth) || isNaN(cal.implicitHeight);
            assertCondition("CHAL.GEOM.01", "NotchCalendarGrid dimensions are finite numbers without NaN",
                !hasNaN && cal.width === 360 && cal.height === 250,
                "w=" + cal.width + ", h=" + cal.height);

            // Verify gridCells length matches live property
            assertCondition("CHAL.GEOM.02", "Live gridCells property contains exactly 42 items",
                cal.gridCells.length === 42,
                "gridCells.length=" + cal.gridCells.length);

            // -------------------------------------------------------------
            // Section 5: Signal Flow & LivingNotch Morphing Integration
            // -------------------------------------------------------------
            console.log("--- SECTION 5: LivingNotch Morphing Integration ---");

            var signalFired = false;
            var testHandler = function() {
                signalFired = true;
            };
            cal.closeRequested.connect(testHandler);
            cal.closeRequested();
            cal.closeRequested.disconnect(testHandler);

            assertCondition("CHAL.SIG.01", "closeRequested signal fires and triggers connected listeners",
                signalFired === true, "signalFired=" + signalFired);

            if (notchLoader.status === Loader.Ready && notchLoader.item !== null) {
                var notch = notchLoader.item;
                console.log(">>> LivingNotch is loaded. Testing notch-calendar state transitions...");

                // Initial state without hover
                notch._isHovered = false;
                var initCompact = notch.notchState === "compact";
                assertCondition("CHAL.MORPH.01", "LivingNotch initial state when unhovered is compact",
                    initCompact, "notchState=" + notch.notchState);

                // Open calendar
                notch.toggleCalendar();
                var inCalState = notch.notchState === "calendar";
                var calTargetW = notch.targetWidth === 360;
                var calTargetH = notch.targetHeight === 250;
                assertCondition("CHAL.MORPH.02", "toggleCalendar transitions notchState to 'calendar' with 360x250 target",
                    inCalState && calTargetW && calTargetH,
                    "state=" + notch.notchState + ", targetW=" + notch.targetWidth + ", targetH=" + notch.targetHeight);

                // Close calendar with _isHovered = false
                notch._isHovered = false;
                notch.closeCalendar();
                var backToCompact = notch.notchState === "compact";
                assertCondition("CHAL.MORPH.03", "closeCalendar transitions notchState back to 'compact' when unhovered",
                    backToCompact, "state=" + notch.notchState);

                // Open calendar from hovered state
                notch._isHovered = true;
                assertCondition("CHAL.MORPH.04", "Hovered state resolves to 'hover' when calendar closed",
                    notch.notchState === "hover", "notchState=" + notch.notchState);

                notch.toggleCalendar();
                assertCondition("CHAL.MORPH.05", "Opening calendar from hover state preempts hover to 'calendar'",
                    notch.notchState === "calendar", "notchState=" + notch.notchState);

                notch.closeCalendar();
                assertCondition("CHAL.MORPH.06", "Closing calendar returns to 'hover' if mouse remains inside notch bounds",
                    notch.notchState === "hover", "notchState=" + notch.notchState);
            } else {
                assertCondition("CHAL.MORPH.00", "LivingNotch loader status is ready", false, "notchLoader status=" + notchLoader.status);
            }

            console.log("================================================================");
            console.log("CHALLENGER RESULTS: Passed=" + passCount + ", Failed=" + failCount);
            if (failCount === 0) {
                console.log("=== PASS: ALL ADVERSARIAL CHALLENGER ASSERTIONS PASSED ===");
            } else {
                console.error("=== ASSERTION_FAILED: " + failCount + " challenger tests failed ===");
            }
            console.log("================================================================");

            Qt.quit();
        }
    }
}
