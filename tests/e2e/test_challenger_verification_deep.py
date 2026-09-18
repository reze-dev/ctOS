#!/usr/bin/env python3
"""
Deep Empirical Adversarial Verification Harness by Challenger 1
Validating R1, R2, R3, R4 with mock isolation, permutation matrices,
UI destruction survival tests, and zero-polling compliance checks.
"""

import os
import re
import sys
import json
import shutil
import tempfile
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
SESSION_SVC_PATH = PROJECT_ROOT / "shell/desktop/services/SessionService.qml"
COMPOSITOR_SVC_PATH = PROJECT_ROOT / "shell/desktop/services/CompositorService.qml"
SYSTEM_RAIL_PATH = PROJECT_ROOT / "shell/desktop/surfaces/SystemRail.qml"
ACTION_REG_PATH = PROJECT_ROOT / "shell/desktop/core/ActionRegistry.qml"
WORKSPACES_WIDGET_PATH = PROJECT_ROOT / "shell/desktop/surfaces/components/WorkspacesWidget.qml"
INSPECTOR_PATH = PROJECT_ROOT / "tests/e2e/harness/qml_inspector.py"

passed_count = 0
failed_count = 0
failures = []

def assert_test(name: str, condition: bool, details: str = ""):
    global passed_count, failed_count, failures
    if condition:
        passed_count += 1
        print(f"  [PASS] {name}{f' - {details}' if details else ''}")
    else:
        failed_count += 1
        failures.append((name, details))
        print(f"  [FAIL] {name} - Details: {details}", file=sys.stderr)

def get_quickshell_binary():
    candidate = shutil.which("quickshell") or shutil.which("qs")
    if candidate:
        return candidate
    for p in Path("/nix/store").glob("*quickshell*/bin/quickshell"):
        if os.access(p, os.X_OK):
            return str(p)
    return None

def create_mock_bin_dir():
    d = tempfile.mkdtemp(prefix="ctos_challenger_mock_")
    log_file = os.path.join(d, "invocations.log")
    for b in ["loginctl", "hyprctl", "niri", "systemctl", "hyprlock"]:
        p = os.path.join(d, b)
        with open(p, "w") as f:
            f.write(f'#!/bin/sh\necho "{b} $@" >> "{log_file}"\nexit 0\n')
        os.chmod(p, 0o755)
    return d, log_file

def run_qml_probe(qs_bin: str, mock_dir: str, env_overrides: dict, qml_code: str, timeout: int = 10):
    with tempfile.NamedTemporaryFile("w", suffix=".qml", delete=False) as f:
        qml_path = f.name
        f.write(qml_code)
    try:
        env = os.environ.copy()
        env["PATH"] = f"{mock_dir}:{env.get('PATH', '')}"
        env["QML_IMPORT_PATH"] = str(PROJECT_ROOT / "shell")
        env["PROJECT_ROOT"] = str(PROJECT_ROOT)
        for k, v in env_overrides.items():
            if v is None:
                env.pop(k, None)
            else:
                env[k] = v
        
        proc = subprocess.run([qs_bin, "-p", qml_path], env=env, capture_output=True, text=True, timeout=timeout)
        return proc.returncode, proc.stdout + proc.stderr
    finally:
        if os.path.exists(qml_path):
            os.remove(qml_path)

def main():
    global passed_count, failed_count
    print("=" * 80)
    print("  CHALLENGER 1: DEEP EMPIRICAL ADVERSARIAL VERIFICATION SUITE")
    print("=" * 80)

    qs_bin = get_quickshell_binary()
    assert_test("ENV.QUICKSHELL_AVAILABLE", qs_bin is not None, f"binary={qs_bin}")
    if not qs_bin:
        print("FATAL: Quickshell binary not available!")
        sys.exit(1)

    mock_dir, log_file = create_mock_bin_dir()

    try:
        # ----------------------------------------------------------------------
        # TEST 1: Compositor Matrix Verification (SessionService + CompositorService)
        # ----------------------------------------------------------------------
        print("\n--- TEST 1: Compositor Detection & Matrix Routing ---")
        matrix = [
            {
                "id": "NIRI_EXPLICIT",
                "env": {"XDG_CURRENT_DESKTOP": "niri", "NIRI_SOCKET": None, "HYPRLAND_INSTANCE_SIGNATURE": None},
                "exp_is_niri": True, "exp_is_hypr": False, "exp_comp": "niri",
                "exp_logout": ["niri", "msg", "action", "quit", "-s"]
            },
            {
                "id": "HYPRLAND_EXPLICIT",
                "env": {"XDG_CURRENT_DESKTOP": "hyprland", "NIRI_SOCKET": None, "HYPRLAND_INSTANCE_SIGNATURE": None},
                "exp_is_niri": False, "exp_is_hypr": True, "exp_comp": "hyprland",
                "exp_logout": ["hyprctl", "dispatch", "exit"]
            },
            {
                "id": "NIRI_SOCKET_FALLBACK",
                "env": {"XDG_CURRENT_DESKTOP": "", "NIRI_SOCKET": "/run/user/1000/niri.sock", "HYPRLAND_INSTANCE_SIGNATURE": None},
                "exp_is_niri": True, "exp_is_hypr": False, "exp_comp": "niri",
                "exp_logout": ["niri", "msg", "action", "quit", "-s"]
            },
            {
                "id": "HYPRLAND_SIG_FALLBACK",
                "env": {"XDG_CURRENT_DESKTOP": "", "NIRI_SOCKET": None, "HYPRLAND_INSTANCE_SIGNATURE": "fake_sig"},
                "exp_is_niri": False, "exp_is_hypr": True, "exp_comp": "hyprland",
                "exp_logout": ["hyprctl", "dispatch", "exit"]
            },
            {
                "id": "UNKNOWN_COMPOSITOR",
                "env": {"XDG_CURRENT_DESKTOP": "sway", "NIRI_SOCKET": None, "HYPRLAND_INSTANCE_SIGNATURE": None},
                "exp_is_niri": False, "exp_is_hypr": False, "exp_comp": "unknown",
                "exp_logout": ["hyprctl", "dispatch", "exit"]
            },
            {
                "id": "COLON_DESKTOP_LIST",
                "env": {"XDG_CURRENT_DESKTOP": "GNOME:niri", "NIRI_SOCKET": None, "HYPRLAND_INSTANCE_SIGNATURE": None},
                "exp_is_niri": True, "exp_is_hypr": False, "exp_comp": "niri",
                "exp_logout": ["niri", "msg", "action", "quit", "-s"]
            }
        ]

        probe_qml = """
import QtQuick
import Quickshell
import desktop.services

Scope {
    Timer {
        interval: 20
        running: true
        onTriggered: {
            const res = {
                session: {
                    isNiri: SessionService.isNiri,
                    isHyprland: SessionService.isHyprland,
                    compositorName: SessionService.compositorName,
                    logoutCommand: SessionService.logoutCommand
                },
                compositor: {
                    isNiri: CompositorService.isNiri,
                    isHyprland: CompositorService.isHyprland,
                    available: CompositorService.available,
                    wsCount: CompositorService.workspaces ? CompositorService.workspaces.length : 0,
                    focusedWs: CompositorService.focusedWorkspaceId
                }
            };
            console.log("PROBE_JSON: " + JSON.stringify(res));
            Qt.quit();
        }
    }
}
"""
        for item in matrix:
            rc, out = run_qml_probe(qs_bin, mock_dir, item["env"], probe_qml)
            json_line = next((l for l in out.splitlines() if "PROBE_JSON:" in l), None)
            assert_test(f"MATRIX.{item['id']}.RC", rc == 0, f"rc={rc}")
            assert_test(f"MATRIX.{item['id']}.OUTPUT", json_line is not None, "Parsed JSON output")
            if json_line:
                data = json.loads(json_line.split("PROBE_JSON:")[1].strip())
                s = data["session"]
                c = data["compositor"]
                assert_test(f"MATRIX.{item['id']}.IS_NIRI", s["isNiri"] == item["exp_is_niri"], f"got={s['isNiri']}")
                assert_test(f"MATRIX.{item['id']}.IS_HYPR", s["isHyprland"] == item["exp_is_hypr"], f"got={s['isHyprland']}")
                assert_test(f"MATRIX.{item['id']}.COMP_NAME", s["compositorName"] == item["exp_comp"], f"got={s['compositorName']}")
                assert_test(f"MATRIX.{item['id']}.LOGOUT_CMD", s["logoutCommand"] == item["exp_logout"], f"got={s['logoutCommand']}")
                assert_test(f"MATRIX.{item['id']}.COMPOSITOR_WS_COUNT", c["wsCount"] == 5, f"wsCount={c['wsCount']}")

        # ----------------------------------------------------------------------
        # TEST 2: Niri Workspace Switching & Boundary Rejection
        # ----------------------------------------------------------------------
        print("\n--- TEST 2: Niri Workspace Switching & Boundary Rejection ---")
        ws_probe_qml = """
import QtQuick
import Quickshell
import desktop.services

Scope {
    id: root
    property var events: []

    Connections {
        target: CompositorService
        function onWorkspaceChanged(id) {
            root.events.push(id);
        }
    }

    Timer {
        interval: 30
        running: true
        onTriggered: {
            const initialFocus = CompositorService.focusedWorkspaceId;
            CompositorService.switchToWorkspace(4);
            const focusAfter4 = CompositorService.focusedWorkspaceId;
            const wsListAfter4 = CompositorService.workspaces;
            const ws4Obj = wsListAfter4 ? wsListAfter4[3] : null;
            const ws4Active = ws4Obj ? ws4Obj.active : null;
            const ws4Focused = ws4Obj ? ws4Obj.focused : null;

            // Boundaries
            CompositorService.switchToWorkspace(0);
            CompositorService.switchToWorkspace(-3);
            CompositorService.switchToWorkspace(NaN);
            const focusAfterBad = CompositorService.focusedWorkspaceId;

            // Switch to 2
            CompositorService.switchToWorkspace(2);
            const focusAfter2 = CompositorService.focusedWorkspaceId;

            console.log("WS_JSON: " + JSON.stringify({
                initialFocus: initialFocus,
                focusAfter4: focusAfter4,
                ws4Active: ws4Active,
                ws4Focused: ws4Focused,
                focusAfterBad: focusAfterBad,
                focusAfter2: focusAfter2,
                events: root.events
            }));
            Qt.quit();
        }
    }
}
"""
        rc, out = run_qml_probe(qs_bin, mock_dir, {"XDG_CURRENT_DESKTOP": "niri"}, ws_probe_qml)
        json_line = next((l for l in out.splitlines() if "WS_JSON:" in l), None)
        assert_test("WS_SWITCH.RC", rc == 0, f"rc={rc}")
        assert_test("WS_SWITCH.JSON", json_line is not None)
        if json_line:
            d = json.loads(json_line.split("WS_JSON:")[1].strip())
            assert_test("WS_SWITCH.INIT", d["initialFocus"] == 1, f"init={d['initialFocus']}")
            assert_test("WS_SWITCH.TO_4", d["focusAfter4"] == 4, f"after4={d['focusAfter4']}")
            assert_test("WS_SWITCH.WS4_ACTIVE", d["ws4Active"] is True and d["ws4Focused"] is True, f"active={d['ws4Active']}, focused={d['ws4Focused']}")
            assert_test("WS_SWITCH.REJECT_BAD", d["focusAfterBad"] == 4, f"afterBad={d['focusAfterBad']}")
            assert_test("WS_SWITCH.TO_2", d["focusAfter2"] == 2, f"after2={d['focusAfter2']}")
            assert_test("WS_SWITCH.EVENTS", d["events"] == [4, 2], f"events={d['events']}")

        # ----------------------------------------------------------------------
        # TEST 3: UI Destruction Survival under Rapid Asynchronous Close
        # ----------------------------------------------------------------------
        print("\n--- TEST 3: UI Destruction Survival ---")
        ui_destroy_qml = """
import QtQuick
import Quickshell
import desktop.services
import desktop.surfaces

Scope {
    id: root

    property var finishedActions: []
    property int currentTest: 0

    Connections {
        target: SessionService
        function onSessionActionFinished(action, exitCode) {
            root.finishedActions.push({ action: action, exitCode: exitCode });
        }
    }

    Loader {
        id: railLoader
        source: "file://" + (Quickshell.env("PROJECT_ROOT") || "/home/reze/Projects/ctOS") + "/shell/desktop/surfaces/SystemRail.qml"
        active: false
    }

    Timer {
        id: stepTimer
        interval: 80
        repeat: true
        running: true
        onTriggered: {
            switch (root.currentTest) {
            case 0:
                // Mount SystemRail
                railLoader.active = true;
                root.currentTest = 1;
                break;
            case 1:
                if (railLoader.item) {
                    // Trigger reboot and immediately destroy SystemRail in the very next statement!
                    railLoader.item.confirmationAction = "reboot";
                    railLoader.item.executeConfirmation();
                    railLoader.active = false;
                    root.currentTest = 2;
                }
                break;
            case 2:
                // Verify loader item is destroyed
                if (railLoader.item === null) {
                    // Wait for completion
                    if (root.finishedActions.some(function(x) { return x.action === "reboot"; })) {
                        console.log("SURVIVAL_STEP: reboot survived UI destruction");
                        root.currentTest = 3;
                    }
                }
                break;
            case 3:
                // Mount SystemRail for poweroff
                railLoader.active = true;
                root.currentTest = 4;
                break;
            case 4:
                if (railLoader.item) {
                    railLoader.item.confirmationAction = "poweroff";
                    railLoader.item.executeConfirmation();
                    railLoader.active = false;
                    root.currentTest = 5;
                }
                break;
            case 5:
                if (railLoader.item === null) {
                    if (root.finishedActions.some(function(x) { return x.action === "poweroff"; })) {
                        console.log("SURVIVAL_STEP: poweroff survived UI destruction");
                        root.currentTest = 6;
                    }
                }
                break;
            case 6:
                // Mount SystemRail for logout
                railLoader.active = true;
                root.currentTest = 7;
                break;
            case 7:
                if (railLoader.item) {
                    railLoader.item.confirmationAction = "logout";
                    railLoader.item.executeConfirmation();
                    railLoader.active = false;
                    root.currentTest = 8;
                }
                break;
            case 8:
                if (railLoader.item === null) {
                    if (root.finishedActions.some(function(x) { return x.action === "logout"; })) {
                        console.log("SURVIVAL_STEP: logout survived UI destruction");
                        root.currentTest = 9;
                    }
                }
                break;
            case 9:
                // Direct lock through SystemRail with immediate close
                railLoader.active = true;
                root.currentTest = 10;
                break;
            case 10:
                if (railLoader.item) {
                    SessionService.lock();
                    railLoader.active = false;
                    root.currentTest = 11;
                }
                break;
            case 11:
                if (railLoader.item === null) {
                    if (root.finishedActions.some(function(x) { return x.action === "lock"; })) {
                        console.log("SURVIVAL_STEP: lock survived UI destruction");
                        root.currentTest = 12;
                    }
                }
                break;
            case 12:
                console.log("SURVIVAL_SUMMARY: " + JSON.stringify(root.finishedActions));
                Qt.quit();
                break;
            }
        }
    }
}
"""
        rc, out = run_qml_probe(qs_bin, mock_dir, {"XDG_CURRENT_DESKTOP": "niri"}, ui_destroy_qml, timeout=15)
        assert_test("UI_SURVIVAL.RC", rc == 0, f"rc={rc}")
        assert_test("UI_SURVIVAL.REBOOT_LOG", "reboot survived UI destruction" in out)
        assert_test("UI_SURVIVAL.POWEROFF_LOG", "poweroff survived UI destruction" in out)
        assert_test("UI_SURVIVAL.LOGOUT_LOG", "logout survived UI destruction" in out)
        assert_test("UI_SURVIVAL.LOCK_LOG", "lock survived UI destruction" in out)

        # ----------------------------------------------------------------------
        # TEST 4: Zero Polling Architecture Audit
        # ----------------------------------------------------------------------
        print("\n--- TEST 4: Zero Polling Compliance ---")
        # Milestone targeted services must have zero timers and zero loops
        for target_svc in [SESSION_SVC_PATH, COMPOSITOR_SVC_PATH]:
            content = target_svc.read_text(encoding="utf-8")
            code_only = re.sub(r'//.*', '', content)
            code_only = re.sub(r'/\*.*?\*/', '', code_only, flags=re.DOTALL)

            has_timer = bool(re.search(r'\bTimer\s*\{', code_only))
            assert_test(f"ZERO_POLL.NO_TIMER.{target_svc.stem}", not has_timer, f"{target_svc.name} has no Timer")

            has_set_interval = bool(re.search(r'setInterval|setTimeout', code_only))
            assert_test(f"ZERO_POLL.NO_SETINTERVAL.{target_svc.stem}", not has_set_interval, f"{target_svc.name} has no setInterval")

            # Must have no running: true in Process nodes
            has_running_true = bool(re.search(r'Process\s*\{[^}]*running\s*:\s*true', code_only, re.DOTALL))
            assert_test(f"ZERO_POLL.NO_STATIC_RUNNING.{target_svc.stem}", not has_running_true, f"{target_svc.name} has no running: true")

        # Global qml_inspector check-polling across shell/desktop
        proc = subprocess.run([sys.executable, str(INSPECTOR_PATH), "check-polling", str(PROJECT_ROOT / "shell/desktop")],
                              capture_output=True, text=True)
        assert_test("GLOBAL_INSPECTOR.ZERO_POLLING", proc.returncode == 0, proc.stdout.strip())

        # Global qml_inspector check-greeter across shell/desktop
        proc = subprocess.run([sys.executable, str(INSPECTOR_PATH), "check-greeter", str(PROJECT_ROOT / "shell/desktop")],
                              capture_output=True, text=True)
        assert_test("GLOBAL_INSPECTOR.GREETER_ISOLATION", proc.returncode == 0, proc.stdout.strip())

        # ----------------------------------------------------------------------
        # TEST 5: Mock Command Execution Log Audit
        # ----------------------------------------------------------------------
        print("\n--- TEST 5: Command Allowlist & Execution Isolation Log ---")
        if os.path.exists(log_file):
            invocations = [l.strip() for l in open(log_file).readlines() if l.strip()]
            print(f"  Total intercepted mock commands: {len(invocations)}")
            for inv in invocations:
                print(f"    - Intercepted: {inv}")
                bin_name = inv.split()[0]
                assert_test(f"INTERCEPT_SAFE.{bin_name}", bin_name in ["loginctl", "hyprctl", "niri", "systemctl", "hyprlock"])
            assert_test("INTERCEPT_NIRI_QUIT_FLAG_S", any("niri msg action quit -s" in inv for inv in invocations), "Recorded niri msg action quit -s")
        else:
            assert_test("INTERCEPT_LOG_EXISTS", False, "Mock invocations log was not created")

    finally:
        if os.path.exists(mock_dir):
            shutil.rmtree(mock_dir, ignore_errors=True)

    print("\n" + "=" * 80)
    print(f"CHALLENGER SUMMARY: Total: {passed_count + failed_count} | Passed: {passed_count} | Failed: {failed_count}")
    print("=" * 80)

    if failed_count > 0:
        print("\nFAILURES:")
        for f, d in failures:
            print(f"  - {f}: {d}")
        sys.exit(1)
    else:
        print("\nALL CHALLENGER DEEP TESTS PASSED (100% EMPIRICAL APPROVAL)\n")
        sys.exit(0)

if __name__ == "__main__":
    main()
