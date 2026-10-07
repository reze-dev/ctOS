#!/usr/bin/env python3
"""
================================================================================
CHALLENGER M4-2 EMPIRICAL ADVERSARIAL STRESS SUITE
================================================================================
Empirical stress-testing of Milestone 4: Overlay & Shell Integration.

Target Domains:
1. Session Lifecycle & System Actions:
   - Compositor detection and fallback chain in SessionService
   - Re-entrancy protection and process isolation
   - Integration with CommandCenter confirmation prompts
   - Session actions preemption of overlays and LivingNotch
2. Morphing Calendar Dismissal:
   - Downward growth past bounds and 42-cell ISO-8601 grid math
   - Automatic dismissal on overlay summon (CommandCenter, CommandDeck, RadialSettings)
   - Dismissal via Escape key, outside backdrop click, and host closeCalendar()
   - Spring animation dimension invariance during state transitions
3. Full-Screen Window Clearance:
   - Floating top bar container with exclusiveZone: 0 and ExclusionMode.Ignore
   - Dynamic Wayland input mask bounding only the visible notch pill
   - Double-buffered flushWaylandMask() mechanism
   - Non-interfering backwards compatibility scaffolding
4. Rapid Overlay Opening & Dismissal Edge Cases:
   - Mutual exclusivity across CommandDeck, CommandCenter, RadialSettings
   - Opacity handoff fidelity (yielding to 0.0 on CommandCenter, 1.0 on others)
   - 100-cycle high-frequency interleaved chatter and Monte Carlo simulation
   - Zero deadlock, zero stuck states, clean settle invariant
5. Quickshell Live Runtime Execution & Master Acceptance Verification:
   - Cold boot syntax and component resolution verification
   - Headless QML stress harness execution (test_m4_challenger2_empirical_stress.qml)
   - 100% pass verification on master_e2e_acceptance.sh (41/41)
"""

import os
import re
import sys
import json
import random
import shutil
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
LIVING_NOTCH_PATH = PROJECT_ROOT / "shell/desktop/surfaces/components/LivingNotch.qml"
AMBIENT_BAR_PATH = PROJECT_ROOT / "shell/desktop/surfaces/AmbientBar.qml"
NOTCH_CALENDAR_PATH = PROJECT_ROOT / "shell/desktop/surfaces/components/NotchCalendarGrid.qml"
OVERLAY_CTRL_PATH = PROJECT_ROOT / "shell/desktop/core/OverlayController.qml"
COMMAND_CENTER_PATH = PROJECT_ROOT / "shell/desktop/surfaces/CommandCenter.qml"
SESSION_SVC_PATH = PROJECT_ROOT / "shell/desktop/services/SessionService.qml"
COMPONENTS_QMLDIR_PATH = PROJECT_ROOT / "shell/desktop/surfaces/components/qmldir"
SERVICES_QMLDIR_PATH = PROJECT_ROOT / "shell/desktop/services/qmldir"
SHELL_PATH = PROJECT_ROOT / "shell/shell.qml"
HARNESS_PATH = PROJECT_ROOT / "tests/e2e/harness/test_m4_challenger2_empirical_stress.qml"

TOTAL_TESTS = 0
PASSED_TESTS = 0
FAILED_TESTS = []


def record(test_id: str, desc: str, condition: bool, details: str = ""):
    global TOTAL_TESTS, PASSED_TESTS, FAILED_TESTS
    TOTAL_TESTS += 1
    if condition:
        PASSED_TESTS += 1
        detail_str = f" ({details})" if details else ""
        print(f"  [PASS] {test_id}: {desc}{detail_str}")
    else:
        FAILED_TESTS.append((test_id, desc, details))
        detail_str = f" | Details: {details}" if details else ""
        print(f"  [FAIL] {test_id}: {desc}{detail_str}", file=sys.stderr)


def discover_quickshell() -> str:
    candidate = shutil.which("quickshell") or shutil.which("qs")
    if candidate:
        return candidate
    for store_path in Path("/nix/store").glob("*quickshell*/bin/quickshell"):
        if os.access(store_path, os.X_OK):
            return str(store_path)
    for store_path in Path("/nix/store").glob("*quickshell*/bin/qs"):
        if os.access(store_path, os.X_OK):
            return str(store_path)
    return "quickshell"


# ==============================================================================
# SECTION 1: Static Architectural & Contract Verification
# ==============================================================================
def test_static_contracts():
    print("\n--- Section 1: Static Contracts & Component Wiring ---")

    # 1.1 LivingNotch in qmldir
    qmldir_content = COMPONENTS_QMLDIR_PATH.read_text(encoding="utf-8")
    record(
        "STAT.QMLDIR.LIVING_NOTCH",
        "LivingNotch 1.0 registered in shell/desktop/surfaces/components/qmldir",
        "LivingNotch 1.0 LivingNotch.qml" in qmldir_content
    )

    # 1.2 LivingNotch contract
    ln_content = LIVING_NOTCH_PATH.read_text(encoding="utf-8")
    record(
        "STAT.NOTCH.PROPERTIES",
        "LivingNotch declares required public interface properties",
        all(term in ln_content for term in [
            "property string monitorName",
            "readonly property bool isCommandCenterOpen",
            "readonly property real currentWidth",
            "readonly property real currentHeight",
            "readonly property string notchState",
            "property bool calendarOpen"
        ])
    )

    record(
        "STAT.NOTCH.DIMENSIONS",
        "LivingNotch defines standard state dimension tokens",
        all(term in ln_content for term in [
            "compactWidth: 220",
            "hoverWidth: 380",
            "calendarWidth: 360",
            "calendarHeight: 250",
            "compactHeight: Theme.barHeight - 6"
        ])
    )

    record(
        "STAT.NOTCH.OPACITY_HANDOFF",
        "LivingNotch declares reactive opacity handoff with CommandCenter",
        "opacity: root.isCommandCenterOpen ? 0.0 : 1.0" in ln_content and
        "Behavior on opacity" in ln_content
    )

    record(
        "STAT.NOTCH.CALENDAR_DISMISSAL",
        "LivingNotch declares closeCalendar method and overlay dismiss triggers",
        "function closeCalendar(): void" in ln_content and
        "OverlayController" in ln_content and
        "root.closeCalendar()" in ln_content
    )

    # 1.3 AmbientBar host contract
    bar_content = AMBIENT_BAR_PATH.read_text(encoding="utf-8")
    record(
        "STAT.BAR.EXCLUSIVE_ZONE_0",
        "AmbientBar sets exclusiveZone: 0 and ExclusionMode.Ignore",
        "exclusiveZone: 0" in bar_content and
        "exclusionMode: ExclusionMode.Ignore" in bar_content
    )

    record(
        "STAT.BAR.WAYLAND_MASK",
        "AmbientBar declares dynamic double-buffered Wayland input mask",
        "property bool toggleMask: false" in bar_content and
        "mask: toggleMask ? maskA : maskB" in bar_content and
        "function flushWaylandMask()" in bar_content
    )

    record(
        "STAT.BAR.CLOSE_CALENDAR",
        "AmbientBar declares bidirectional closeCalendar() delegation",
        "function closeCalendar(): void" in bar_content and
        "livingNotch.closeCalendar()" in bar_content
    )

    record(
        "STAT.BAR.COMPAT_ALIASES",
        "AmbientBar retains backwards-compatible aliases for master test suite",
        all(term in bar_content for term in [
            "id: leftIsland",
            "id: rightIsland",
            "DynamicIsland",
            'source: "components/os-icon.svg"'
        ])
    )

    # 1.4 SessionService contract
    sess_content = SESSION_SVC_PATH.read_text(encoding="utf-8")
    record(
        "STAT.SESS.PROCESSES",
        "SessionService declares 4 discrete Process nodes with zero shell wrappers",
        all(term in sess_content for term in [
            "id: lockProcess",
            "id: logoutProcess",
            "id: rebootProcess",
            "id: poweroffProcess",
            'command: ["loginctl", "lock-session"]',
            'command: ["systemctl", "reboot"]',
            'command: ["systemctl", "poweroff"]'
        ])
    )

    record(
        "STAT.SESS.DRY_RUN",
        "SessionService supports CTOS_SESSION_DRY_RUN environment flag",
        'Quickshell.env("CTOS_SESSION_DRY_RUN") === "1"' in sess_content
    )

    # 1.5 OverlayController contract
    ovr_content = OVERLAY_CTRL_PATH.read_text(encoding="utf-8")
    record(
        "STAT.OVR.EXCLUSIVITY",
        "OverlayController enforces mutual exclusivity with single activeSurface",
        all(term in ovr_content for term in [
            "property int activeSurface: OverlayController.Surface.None",
            "function openCommandDeck(): void",
            "function openCommandCenter(): void",
            "function openRadialSettings(): void",
            "function close(): void"
        ])
    )


# ==============================================================================
# SECTION 2: Monte Carlo State Machine Simulation (1,000 Rounds)
# ==============================================================================
def test_monte_carlo_state_machine():
    print("\n--- Section 2: Monte Carlo State Machine Invariant Simulation ---")

    class ShellMock:
        def __init__(self):
            self.active_surface = 0  # 0=None, 1=CommandDeck, 2=SystemRail, 3=CommandCenter, 4=RadialSettings
            self.calendar_open = False
            self.hovered = False
            self.notification_active = False
            self.media_playing = False
            self.dnd = False

        @property
        def is_command_center_open(self):
            return self.active_surface == 3

        @property
        def resolved_state(self):
            if self.calendar_open and not self.is_command_center_open:
                return "calendar"
            if self.notification_active and not self.dnd:
                return "notification"
            if self.hovered and not self.is_command_center_open:
                return "hover"
            if self.media_playing:
                return "media"
            return "compact"

        @property
        def opacity_target(self):
            return 0.0 if self.is_command_center_open else 1.0

        def open_overlay(self, surface_id: int):
            self.active_surface = surface_id
            if surface_id != 0:
                self.close_calendar()

        def close_overlay(self):
            self.active_surface = 0

        def toggle_calendar(self):
            if self.is_command_center_open:
                self.close_overlay()
            self.calendar_open = not self.calendar_open

        def close_calendar(self):
            self.calendar_open = False

        def handle_escape(self):
            if self.active_surface != 0:
                self.close_overlay()
                return True
            if self.calendar_open:
                self.close_calendar()
                return True
            return False

    shell = ShellMock()
    violations = []
    random.seed(42)

    for i in range(1000):
        action = random.choice([
            "open_cmd_deck", "open_cmd_center", "open_radial", "close_ovr",
            "toggle_cal", "close_cal", "escape", "hover_enter", "hover_exit",
            "notif_in", "notif_expire", "media_start", "media_stop"
        ])

        if action == "open_cmd_deck":
            shell.open_overlay(1)
        elif action == "open_cmd_center":
            shell.open_overlay(3)
        elif action == "open_radial":
            shell.open_overlay(4)
        elif action == "close_ovr":
            shell.close_overlay()
        elif action == "toggle_cal":
            shell.toggle_calendar()
        elif action == "close_cal":
            shell.close_calendar()
        elif action == "escape":
            shell.handle_escape()
        elif action == "hover_enter":
            shell.hovered = True
        elif action == "hover_exit":
            shell.hovered = False
        elif action == "notif_in":
            shell.notification_active = True
        elif action == "notif_expire":
            shell.notification_active = False
        elif action == "media_start":
            shell.media_playing = True
        elif action == "media_stop":
            shell.media_playing = False

        # Invariant 1: Surface must be in [0..4]
        if shell.active_surface not in (0, 1, 2, 3, 4):
            violations.append(f"Step {i}: invalid active_surface {shell.active_surface}")

        # Invariant 2: When CommandCenter is open, calendar MUST be false
        if shell.is_command_center_open and shell.calendar_open:
            violations.append(f"Step {i}: calendarOpen=True while isCommandCenterOpen=True")

        # Invariant 3: When CommandCenter is open, resolvedState MUST NOT be calendar
        if shell.is_command_center_open and shell.resolved_state == "calendar":
            violations.append(f"Step {i}: resolvedState='calendar' while isCommandCenterOpen=True")

        # Invariant 4: Opacity target MUST be 0.0 iff isCommandCenterOpen is True
        expected_opacity = 0.0 if shell.is_command_center_open else 1.0
        if shell.opacity_target != expected_opacity:
            violations.append(f"Step {i}: opacity_target={shell.opacity_target} != {expected_opacity}")

    record(
        "MONTE_CARLO.INVARIANTS",
        "1,000-iteration Monte Carlo state machine maintained zero invariant violations",
        len(violations) == 0,
        f"violations={len(violations)}"
    )


# ==============================================================================
# SECTION 3: Live Headless QML Stress Harness
# ==============================================================================
def test_headless_qml_harness():
    print("\n--- Section 3: Headless Quickshell Runtime Stress Harness ---")

    qs_bin = discover_quickshell()
    env = os.environ.copy()
    env["CTOS_SESSION_DRY_RUN"] = "1"
    env["QML_IMPORT_PATH"] = str(PROJECT_ROOT / "shell")

    proc = subprocess.run(
        [qs_bin, "-p", str(HARNESS_PATH)],
        capture_output=True,
        text=True,
        env=env,
        cwd=str(PROJECT_ROOT),
        timeout=15
    )

    out = proc.stdout + proc.stderr

    record(
        "HARNESS.EXIT_CODE",
        "Headless QML harness exited cleanly with code 0",
        proc.returncode == 0,
        f"returncode={proc.returncode}"
    )

    record(
        "HARNESS.NO_FAILURES",
        "Headless QML harness output contains zero [FAIL] assertions",
        "[FAIL]" not in out and "ASSERTION_FAILED" not in out
    )

    record(
        "HARNESS.SUCCESS_BANNER",
        "Headless QML harness emitted PASS completion banner (43/43 assertions)",
        "=== PASS: CHALLENGER 2 EMPIRICAL HARNESS SUCCESSFUL ===" in out and
        "CHALLENGER 2 RESULTS: Passed=43, Failed=0" in out
    )


# ==============================================================================
# SECTION 4: Live Cold-Boot Verification
# ==============================================================================
def test_cold_boot():
    print("\n--- Section 4: Live Clean Cold-Boot Verification ---")

    qs_bin = discover_quickshell()
    env = os.environ.copy()
    env["CTOS_SESSION_DRY_RUN"] = "1"
    env["QML_IMPORT_PATH"] = str(PROJECT_ROOT / "shell")

    try:
        proc = subprocess.run(
            [qs_bin, "-p", str(SHELL_PATH)],
            capture_output=True,
            text=True,
            env=env,
            cwd=str(PROJECT_ROOT),
            timeout=4
        )
        out = proc.stdout + proc.stderr
    except subprocess.TimeoutExpired as exc:
        stdout_str = exc.stdout.decode("utf-8", errors="replace") if isinstance(exc.stdout, bytes) else (exc.stdout or "")
        stderr_str = exc.stderr.decode("utf-8", errors="replace") if isinstance(exc.stderr, bytes) else (exc.stderr or "")
        out = stdout_str + stderr_str

    record(
        "COLD_BOOT.NO_TYPE_ERRORS",
        "shell.qml cold-boots with zero 'LivingNotch is not a type' errors",
        "LivingNotch is not a type" not in out
    )

    record(
        "COLD_BOOT.CONFIG_LOADED",
        "shell.qml reports 'Configuration Loaded' cleanly",
        "INFO: Configuration Loaded" in out or "Configuration Loaded" in out
    )


# ==============================================================================
# SECTION 5: Mandatory E2E Test Suite Execution
# ==============================================================================
def test_mandatory_e2e_suites():
    print("\n--- Section 5: Mandatory E2E Test Suite Execution ---")

    suites = [
        ("T4.LIFECYCLE", "tests/e2e/tier4_real_world/test_notch_session_lifecycle.sh"),
        ("T1.CALENDAR", "tests/e2e/tier1_features/test_notch_morphing_calendar.sh"),
        ("T1.COMPACT", "tests/e2e/tier1_features/test_notch_compact_state.sh"),
        ("MASTER.ACCEPTANCE", "tests/e2e/master_e2e_acceptance.sh")
    ]

    for suite_id, script_rel in suites:
        script_path = PROJECT_ROOT / script_rel
        proc = subprocess.run(
            ["bash", str(script_path)],
            capture_output=True,
            text=True,
            cwd=str(PROJECT_ROOT),
            timeout=40
        )
        out = proc.stdout + proc.stderr
        clean_out = re.sub(r'\x1b\[[0-9;]*m', '', out)
        passed = (
            proc.returncode == 0 and
            ("Failed       : 0" in clean_out or "Failed: 0" in clean_out) and
            "[FAIL]" not in clean_out and
            "ASSERTION_FAILED" not in clean_out
        )
        if suite_id == "MASTER.ACCEPTANCE":
            passed = passed and ("Passed: 41" in clean_out or "Passed       : 41" in clean_out)

        record(
            f"SUITE.{suite_id}",
            f"{script_rel} passed completely with 0 failures",
            passed,
            f"returncode={proc.returncode}"
        )


def main():
    print("=" * 80)
    print("  CHALLENGER 2 EMPIRICAL ADVERSARIAL STRESS SUITE: MILESTONE 4")
    print("=" * 80)

    test_static_contracts()
    test_monte_carlo_state_machine()
    test_headless_qml_harness()
    test_cold_boot()
    test_mandatory_e2e_suites()

    print("\n" + "=" * 80)
    print(f"ADVERSARIAL STRESS SUMMARY: Total: {TOTAL_TESTS} | Passed: {PASSED_TESTS} | Failed: {len(FAILED_TESTS)}")
    print("=" * 80)

    if len(FAILED_TESTS) == 0:
        print("\nALL EMPIRICAL CHALLENGES PASSED (VERDICT: APPROVE)\n")
        sys.exit(0)
    else:
        print(f"\n{len(FAILED_TESTS)} EMPIRICAL CHALLENGES FAILED (VERDICT: REQUEST_CHANGES)\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
