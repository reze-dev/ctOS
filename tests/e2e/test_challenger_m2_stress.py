#!/usr/bin/env python3
"""
EMPIRICAL CHALLENGER TEST SUITE: Milestone 2 (Compositor Detection & Logout Fix)
================================================================================
Target: SessionService.qml & System Integration
Role: Critic / Specialist (Challenger 1)

CRITICAL SAFETY MANDATE:
All execution paths are strictly intercepted by mock binaries in an isolated
temporary directory. Live compositor termination commands (niri msg action quit,
hyprctl dispatch exit) MUST NEVER execute against the active session.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
SESSION_SERVICE_PATH = PROJECT_ROOT / "shell/desktop/services/SessionService.qml"
NIRI_NIX_PATH = PROJECT_ROOT / "modules/features/desktop/niri.nix"
PACKAGE_NIX_PATH = PROJECT_ROOT / "shell/nix/package.nix"
HOME_MANAGER_NIX_PATH = PROJECT_ROOT / "shell/nix/home-manager.nix"

passed_tests = 0
failed_tests = []
total_tests = 0


def record(test_id: str, description: str, condition: bool, details: str = ""):
    global passed_tests, total_tests, failed_tests
    total_tests += 1
    if condition:
        passed_tests += 1
        print(f"  [PASS] {test_id}: {description}" + (f" ({details})" if details else ""))
    else:
        failed_tests.append((test_id, description, details))
        print(f"  [FAIL] {test_id}: {description}" + (f" ({details})" if details else ""))


def discover_quickshell():
    nix_store = Path("/nix/store")
    if nix_store.exists():
        matches = sorted(nix_store.glob("*quickshell*/bin/quickshell"))
        if matches:
            return str(matches[-1])
    which_qs = shutil.which("quickshell")
    if which_qs:
        return which_qs
    which_qs_short = shutil.which("qs")
    if which_qs_short:
        return which_qs_short
    return None


def create_mock_environment():
    """
    Creates an isolated mock directory containing smart mock executables for
    niri, hyprctl, loginctl, systemctl, and hyprlock.
    Logs every invocation with full arguments to cmds.log.
    Returns (temp_dir, log_file_path).
    """
    mock_dir = tempfile.mkdtemp(prefix="ctos_m2_challenger_")
    log_file = os.path.join(mock_dir, "cmds.log")

    bins = ["niri", "hyprctl", "loginctl", "systemctl", "hyprlock"]
    for b in bins:
        fpath = os.path.join(mock_dir, b)
        with open(fpath, "w") as f:
            f.write("#!/bin/sh\n"
                    f"echo \"{b}\" \"$*\" >> \"{log_file}\"\n"
                    f"case \"{b}\" in\n"
                    "  niri) exit ${MOCK_NIRI_EXIT:-0} ;;\n"
                    "  hyprctl) exit ${MOCK_HYPRCTL_EXIT:-0} ;;\n"
                    "  loginctl) exit ${MOCK_LOGINCTL_EXIT:-0} ;;\n"
                    "  systemctl) exit ${MOCK_SYSTEMCTL_EXIT:-0} ;;\n"
                    "  *) exit 0 ;;\n"
                    "esac\n")
        os.chmod(fpath, 0o755)

    return mock_dir, log_file


# ==============================================================================
# Phase 1: Nix Packaging & Autostart Integration Inspection
# ==============================================================================
def test_nix_integration():
    print("\n--- Phase 1: Nix Packaging & Autostart Configuration ---")

    # 1. Inspect niri.nix for NIRI_SOCKET export
    niri_content = NIRI_NIX_PATH.read_text(encoding="utf-8")
    record("NIX.NIRI.EXISTS", "modules/features/desktop/niri.nix exists", NIRI_NIX_PATH.exists())

    dbus_has_niri_socket = bool(re.search(r'dbus-update-activation-environment.*?NIRI_SOCKET', niri_content, re.DOTALL))
    record("NIX.NIRI.DBUS_SOCKET", "dbus-update-activation-environment exports NIRI_SOCKET",
           dbus_has_niri_socket, "Found NIRI_SOCKET in dbus-update-activation-environment")

    systemd_has_niri_socket = bool(re.search(r'systemctl\s+--user\s+import-environment.*?NIRI_SOCKET', niri_content, re.DOTALL))
    record("NIX.NIRI.SYSTEMD_SOCKET", "systemctl --user import-environment exports NIRI_SOCKET",
           systemd_has_niri_socket, "Found NIRI_SOCKET in systemctl import-environment")

    # 2. Inspect package.nix for socket discovery
    pkg_content = PACKAGE_NIX_PATH.read_text(encoding="utf-8")
    record("NIX.PACKAGE.EXISTS", "shell/nix/package.nix exists", PACKAGE_NIX_PATH.exists())

    has_socket_loop = "niri.*.sock" in pkg_content
    record("NIX.PACKAGE.SOCKET_DISCOVERY", "ctos-shell wrapper searches for niri.*.sock",
           has_socket_loop, "Discovered runtime socket scan logic")

    has_desktop_fallback = "XDG_CURRENT_DESKTOP=niri" in pkg_content
    record("NIX.PACKAGE.DESKTOP_EXPORT", "ctos-shell wrapper sets XDG_CURRENT_DESKTOP=niri when socket discovered",
           has_desktop_fallback, "Export XDG_CURRENT_DESKTOP=niri present")

    # 3. Inspect home-manager.nix for ctos-shell invocation
    hm_content = HOME_MANAGER_NIX_PATH.read_text(encoding="utf-8")
    record("NIX.HM.EXISTS", "shell/nix/home-manager.nix exists", HOME_MANAGER_NIX_PATH.exists())

    has_ctos_shell_exec = "${ctosPackage}/bin/ctos-shell" in hm_content
    record("NIX.HM.EXEC_WRAPPER", "systemd service ExecStart invokes ctos-shell wrapper",
           has_ctos_shell_exec, "ctos.service launches ctos-shell")


# ==============================================================================
# Phase 2: Compositor Environment Variable Permutations & Case Sensitivity
# ==============================================================================
def test_environment_permutations(qs_bin: str, mock_dir: str):
    print("\n--- Phase 2: Compositor Environment Variable Permutations ---")

    permutations = [
        # (id, description, env_vars, exp_is_niri, exp_is_hypr, exp_comp, exp_logout_cmd)
        ("PERM.01.NIRI_STD", "Standard Niri desktop (XDG_CURRENT_DESKTOP=niri)",
         {"XDG_CURRENT_DESKTOP": "niri", "NIRI_SOCKET": "", "HYPRLAND_INSTANCE_SIGNATURE": ""},
         True, False, "niri", ["niri", "msg", "action", "quit", "-s"]),

        ("PERM.02.NIRI_UPPER", "Uppercase Niri desktop (XDG_CURRENT_DESKTOP=NIRI)",
         {"XDG_CURRENT_DESKTOP": "NIRI", "NIRI_SOCKET": "", "HYPRLAND_INSTANCE_SIGNATURE": ""},
         True, False, "niri", ["niri", "msg", "action", "quit", "-s"]),

        ("PERM.03.NIRI_SOCKET_ONLY", "NIRI_SOCKET set with missing XDG_CURRENT_DESKTOP",
         {"XDG_CURRENT_DESKTOP": "", "NIRI_SOCKET": "/run/user/1000/niri.sock", "HYPRLAND_INSTANCE_SIGNATURE": ""},
         True, False, "niri", ["niri", "msg", "action", "quit", "-s"]),

        ("PERM.04.NIRI_COLON_LIST", "Niri in colon list (XDG_CURRENT_DESKTOP=GNOME:niri)",
         {"XDG_CURRENT_DESKTOP": "GNOME:niri", "NIRI_SOCKET": "", "HYPRLAND_INSTANCE_SIGNATURE": ""},
         True, False, "niri", ["niri", "msg", "action", "quit", "-s"]),

        ("PERM.05.HYPR_STD", "Standard Hyprland desktop (XDG_CURRENT_DESKTOP=hyprland)",
         {"XDG_CURRENT_DESKTOP": "hyprland", "NIRI_SOCKET": "", "HYPRLAND_INSTANCE_SIGNATURE": ""},
         False, True, "hyprland", ["hyprctl", "dispatch", "exit"]),

        ("PERM.06.HYPR_PASCAL", "PascalCase Hyprland desktop (XDG_CURRENT_DESKTOP=Hyprland)",
         {"XDG_CURRENT_DESKTOP": "Hyprland", "NIRI_SOCKET": "", "HYPRLAND_INSTANCE_SIGNATURE": ""},
         False, True, "hyprland", ["hyprctl", "dispatch", "exit"]),

        ("PERM.07.HYPR_SIG_ONLY", "HYPRLAND_INSTANCE_SIGNATURE set with empty desktop",
         {"XDG_CURRENT_DESKTOP": "", "NIRI_SOCKET": "", "HYPRLAND_INSTANCE_SIGNATURE": "inst_123"},
         False, True, "hyprland", ["hyprctl", "dispatch", "exit"]),

        ("PERM.08.HYPR_COLON_LIST", "Hyprland in colon list (XDG_CURRENT_DESKTOP=wlroots:Hyprland)",
         {"XDG_CURRENT_DESKTOP": "wlroots:Hyprland", "NIRI_SOCKET": "", "HYPRLAND_INSTANCE_SIGNATURE": ""},
         False, True, "hyprland", ["hyprctl", "dispatch", "exit"]),

        ("PERM.09.UNKNOWN_SWAY", "Unknown desktop (XDG_CURRENT_DESKTOP=sway)",
         {"XDG_CURRENT_DESKTOP": "sway", "NIRI_SOCKET": "", "HYPRLAND_INSTANCE_SIGNATURE": ""},
         False, False, "unknown", ["hyprctl", "dispatch", "exit"]),

        ("PERM.10.UNKNOWN_EMPTY", "Completely empty environment",
         {"XDG_CURRENT_DESKTOP": "", "NIRI_SOCKET": "", "HYPRLAND_INSTANCE_SIGNATURE": ""},
         False, False, "unknown", ["hyprctl", "dispatch", "exit"]),

        ("PERM.11.UNKNOWN_GENERIC", "Unrelated desktop (XDG_CURRENT_DESKTOP=kde-plasma)",
         {"XDG_CURRENT_DESKTOP": "kde-plasma", "NIRI_SOCKET": "", "HYPRLAND_INSTANCE_SIGNATURE": ""},
         False, False, "unknown", ["hyprctl", "dispatch", "exit"]),
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
                currentDesktop: SessionService.currentDesktop,
                isNiri: SessionService.isNiri,
                isHyprland: SessionService.isHyprland,
                compositorName: SessionService.compositorName,
                logoutCommand: SessionService.logoutCommand
            };
            console.log("PROBE_RESULT: " + JSON.stringify(res));
            Qt.quit();
        }
    }
}
"""

    with tempfile.NamedTemporaryFile("w", suffix=".qml", delete=False) as f:
        qml_path = f.name
        f.write(probe_qml)

    try:
        for perm_id, desc, env_vars, exp_niri, exp_hypr, exp_comp, exp_logout in permutations:
            env = os.environ.copy()
            env["PATH"] = f"{mock_dir}:{env.get('PATH', '')}"
            env["QML_IMPORT_PATH"] = str(PROJECT_ROOT / "shell")
            for k in ["NIRI_SOCKET", "HYPRLAND_INSTANCE_SIGNATURE", "XDG_CURRENT_DESKTOP"]:
                env.pop(k, None)
            for k, v in env_vars.items():
                if v != "":
                    env[k] = v

            proc = subprocess.run([qs_bin, "-p", qml_path], env=env, capture_output=True, text=True, timeout=10)
            out = proc.stdout + proc.stderr
            match = re.search(r'PROBE_RESULT:\s*(\{.*?\})', out)
            record(f"{perm_id}.PARSED", f"{desc} probe parsed JSON", bool(match), f"rc={proc.returncode}")
            if match:
                res = json.loads(match.group(1))
                record(f"{perm_id}.IS_NIRI", f"{desc} isNiri match", res["isNiri"] == exp_niri, f"got={res['isNiri']}")
                record(f"{perm_id}.IS_HYPR", f"{desc} isHyprland match", res["isHyprland"] == exp_hypr, f"got={res['isHyprland']}")
                record(f"{perm_id}.COMP_NAME", f"{desc} compositorName match", res["compositorName"] == exp_comp, f"got={res['compositorName']}")
                record(f"{perm_id}.LOGOUT_CMD", f"{desc} logoutCommand match", res["logoutCommand"] == exp_logout, f"got={res['logoutCommand']}")
    finally:
        if os.path.exists(qml_path):
            os.remove(qml_path)


# ==============================================================================
# Phase 3: Runtime Fallback Execution Transitions (Stage 1 -> Stage 2 -> Stage 3)
# ==============================================================================
def test_fallback_execution_transitions(qs_bin: str, mock_dir: str, log_file: str):
    print("\n--- Phase 3: Runtime Fallback Transitions when Commands Fail ---")

    fallback_harness_qml = """
import QtQuick
import Quickshell
import desktop.services

Scope {
    id: root
    property var triggeredList: []
    property var finishedList: []

    Connections {
        target: SessionService
        function onSessionActionTriggered(action) {
            console.log("QML_TRIGGERED: " + action);
            root.triggeredList.push(action);
        }
        function onSessionActionFinished(action, code) {
            console.log("QML_FINISHED: action=" + action + " code=" + code);
            root.finishedList.push({ action: action, code: code });
        }
    }

    Timer {
        id: triggerTimer
        interval: 30
        running: true
        onTriggered: {
            SessionService.logout();
        }
    }

    Timer {
        id: watchdogTimer
        interval: 60
        repeat: true
        running: true
        property int ticks: 0

        onTriggered: {
            ticks++;
            if (root.finishedList.length > 0 || ticks > 50) {
                const report = {
                    ticks: ticks,
                    triggered: root.triggeredList,
                    finished: root.finishedList,
                    fallbackStage: SessionService.fallbackStage,
                    isLoggingOut: SessionService.isLoggingOut,
                    isBusy: SessionService.isBusy,
                    logoutCommand: SessionService.logoutCommand
                };
                console.log("HARNESS_REPORT: " + JSON.stringify(report));
                Qt.quit();
            }
        }
    }
}
"""
    with tempfile.NamedTemporaryFile("w", suffix=".qml", delete=False) as f:
        harness_path = f.name
        f.write(fallback_harness_qml)

    try:
        # ----------------------------------------------------------------------
        # Case A: Unknown Desktop -> Stage 1 Niri succeeds (exit 0)
        # Expected: Only niri executed; hyprctl and loginctl must NOT run.
        # ----------------------------------------------------------------------
        if os.path.exists(log_file):
            os.remove(log_file)
        env = os.environ.copy()
        env["PATH"] = f"{mock_dir}:{env.get('PATH', '')}"
        env["QML_IMPORT_PATH"] = str(PROJECT_ROOT / "shell")
        env.pop("NIRI_SOCKET", None)
        env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
        env["XDG_CURRENT_DESKTOP"] = ""
        env["MOCK_NIRI_EXIT"] = "0"
        env["MOCK_HYPRCTL_EXIT"] = "0"
        env["MOCK_LOGINCTL_EXIT"] = "0"

        proc = subprocess.run([qs_bin, "-p", harness_path], env=env, capture_output=True, text=True, timeout=10)
        invocations = [l.strip() for l in open(log_file).readlines() if l.strip()] if os.path.exists(log_file) else []
        match_line = next((l for l in (proc.stdout + proc.stderr).splitlines() if "HARNESS_REPORT:" in l), None)
        record("FALLBACK.CASE_A.REPORT", "Case A (Stage 1 exit 0) generated report", match_line is not None)
        if match_line:
            rep = json.loads(match_line.split("HARNESS_REPORT:")[1].strip())
            record("FALLBACK.CASE_A.FINISH_CODE", "Case A emitted sessionActionFinished with code 0",
                   len(rep["finished"]) == 1 and rep["finished"][0]["code"] == 0, f"finished={rep['finished']}")
            record("FALLBACK.CASE_A.STAGE_RESET", "Case A fallbackStage reset to 0", rep["fallbackStage"] == 0)
            record("FALLBACK.CASE_A.NOT_BUSY", "Case A isLoggingOut is false", not rep["isLoggingOut"] and not rep["isBusy"])

        record("FALLBACK.CASE_A.INV_COUNT", "Case A executed exactly 1 command (Stage 1 only)",
               len(invocations) == 1, f"count={len(invocations)}: {invocations}")
        if len(invocations) >= 1:
            record("FALLBACK.CASE_A.NIRI_CMD", "Case A executed 'niri msg action quit -s'",
                   invocations[0] == "niri msg action quit -s", f"got={invocations[0]}")

        # ----------------------------------------------------------------------
        # Case B: Unknown Desktop -> Stage 1 Niri fails (exit 1), Stage 2 Hyprctl succeeds (exit 0)
        # Expected: niri executed, then hyprctl executed; loginctl must NOT run.
        # ----------------------------------------------------------------------
        if os.path.exists(log_file):
            os.remove(log_file)
        env["MOCK_NIRI_EXIT"] = "1"
        env["MOCK_HYPRCTL_EXIT"] = "0"
        env["MOCK_LOGINCTL_EXIT"] = "0"

        proc = subprocess.run([qs_bin, "-p", harness_path], env=env, capture_output=True, text=True, timeout=10)
        invocations = [l.strip() for l in open(log_file).readlines() if l.strip()] if os.path.exists(log_file) else []
        match_line = next((l for l in (proc.stdout + proc.stderr).splitlines() if "HARNESS_REPORT:" in l), None)
        record("FALLBACK.CASE_B.REPORT", "Case B (Stage 1 fail -> Stage 2 success) generated report", match_line is not None)
        if match_line:
            rep = json.loads(match_line.split("HARNESS_REPORT:")[1].strip())
            record("FALLBACK.CASE_B.FINISH_CODE", "Case B finished with code 0",
                   len(rep["finished"]) == 1 and rep["finished"][0]["code"] == 0, f"finished={rep['finished']}")
            record("FALLBACK.CASE_B.STAGE_RESET", "Case B fallbackStage reset to 0", rep["fallbackStage"] == 0)

        record("FALLBACK.CASE_B.INV_COUNT", "Case B executed exactly 2 commands (Stage 1 -> Stage 2)",
               len(invocations) == 2, f"count={len(invocations)}: {invocations}")
        if len(invocations) == 2:
            record("FALLBACK.CASE_B.SEQ_1", "Case B step 1 is 'niri msg action quit -s'",
                   invocations[0] == "niri msg action quit -s", f"got={invocations[0]}")
            record("FALLBACK.CASE_B.SEQ_2", "Case B step 2 is 'hyprctl dispatch exit'",
                   invocations[1] == "hyprctl dispatch exit", f"got={invocations[1]}")

        # ----------------------------------------------------------------------
        # Case C: Unknown Desktop -> Stage 1 fail, Stage 2 fail, Stage 3 Loginctl succeeds (exit 0)
        # Expected: niri -> hyprctl -> loginctl in sequence; finished code 0.
        # ----------------------------------------------------------------------
        if os.path.exists(log_file):
            os.remove(log_file)
        env["MOCK_NIRI_EXIT"] = "1"
        env["MOCK_HYPRCTL_EXIT"] = "1"
        env["MOCK_LOGINCTL_EXIT"] = "0"

        proc = subprocess.run([qs_bin, "-p", harness_path], env=env, capture_output=True, text=True, timeout=10)
        invocations = [l.strip() for l in open(log_file).readlines() if l.strip()] if os.path.exists(log_file) else []
        match_line = next((l for l in (proc.stdout + proc.stderr).splitlines() if "HARNESS_REPORT:" in l), None)
        record("FALLBACK.CASE_C.REPORT", "Case C (Stage 1 fail -> Stage 2 fail -> Stage 3 success) generated report", match_line is not None)
        if match_line:
            rep = json.loads(match_line.split("HARNESS_REPORT:")[1].strip())
            record("FALLBACK.CASE_C.FINISH_CODE", "Case C finished with code 0",
                   len(rep["finished"]) == 1 and rep["finished"][0]["code"] == 0, f"finished={rep['finished']}")
            record("FALLBACK.CASE_C.TRIGGER_COUNT", "Case C triggered signal fired exactly once",
                   len(rep["triggered"]) == 1 and rep["triggered"][0] == "logout", f"triggered={rep['triggered']}")
            record("FALLBACK.CASE_C.STAGE_RESET", "Case C fallbackStage reset to 0", rep["fallbackStage"] == 0)

        record("FALLBACK.CASE_C.INV_COUNT", "Case C executed exactly 3 commands in chain",
               len(invocations) == 3, f"count={len(invocations)}: {invocations}")
        if len(invocations) == 3:
            record("FALLBACK.CASE_C.SEQ_1", "Case C step 1: niri msg action quit -s",
                   invocations[0] == "niri msg action quit -s", f"got={invocations[0]}")
            record("FALLBACK.CASE_C.SEQ_2", "Case C step 2: hyprctl dispatch exit",
                   invocations[1] == "hyprctl dispatch exit", f"got={invocations[1]}")
            record("FALLBACK.CASE_C.SEQ_3", "Case C step 3: loginctl terminate-session",
                   invocations[2].startswith("loginctl terminate-session"), f"got={invocations[2]}")

        # ----------------------------------------------------------------------
        # Case D: Unknown Desktop -> All 3 fail (loginctl returns exit code 7)
        # Expected: niri -> hyprctl -> loginctl; finished code 7; fallbackStage reset to 0.
        # ----------------------------------------------------------------------
        if os.path.exists(log_file):
            os.remove(log_file)
        env["MOCK_NIRI_EXIT"] = "1"
        env["MOCK_HYPRCTL_EXIT"] = "1"
        env["MOCK_LOGINCTL_EXIT"] = "7"

        proc = subprocess.run([qs_bin, "-p", harness_path], env=env, capture_output=True, text=True, timeout=10)
        invocations = [l.strip() for l in open(log_file).readlines() if l.strip()] if os.path.exists(log_file) else []
        match_line = next((l for l in (proc.stdout + proc.stderr).splitlines() if "HARNESS_REPORT:" in l), None)
        record("FALLBACK.CASE_D.REPORT", "Case D (All 3 fail) generated report", match_line is not None)
        if match_line:
            rep = json.loads(match_line.split("HARNESS_REPORT:")[1].strip())
            record("FALLBACK.CASE_D.FINISH_CODE", "Case D finished with code 7 (propagating final error)",
                   len(rep["finished"]) == 1 and rep["finished"][0]["code"] == 7, f"finished={rep['finished']}")
            record("FALLBACK.CASE_D.STAGE_RESET", "Case D fallbackStage safely resets to 0 despite failure",
                   rep["fallbackStage"] == 0, f"fallbackStage={rep['fallbackStage']}")
            record("FALLBACK.CASE_D.CLEAN_IDLE", "Case D isLoggingOut and isBusy safely reset to false",
                   not rep["isLoggingOut"] and not rep["isBusy"])

        record("FALLBACK.CASE_D.INV_COUNT", "Case D executed all 3 fallback commands",
               len(invocations) == 3, f"count={len(invocations)}: {invocations}")

    finally:
        if os.path.exists(harness_path):
            os.remove(harness_path)


# ==============================================================================
# Phase 4: Intercept Command Verification on Known Compositors (Niri & Hyprland)
# ==============================================================================
def test_known_compositor_interception(qs_bin: str, mock_dir: str, log_file: str):
    print("\n--- Phase 4: Command Interception & Strict Isolation on Known Compositors ---")

    test_qml = """
import QtQuick
import Quickshell
import desktop.services

Scope {
    id: root
    property var finished: []

    Connections {
        target: SessionService
        function onSessionActionFinished(action, code) {
            root.finished.push({ action: action, code: code });
        }
    }

    Timer {
        interval: 30
        running: true
        onTriggered: {
            SessionService.logout();
        }
    }

    Timer {
        interval: 60
        repeat: true
        running: true
        property int ticks: 0
        onTriggered: {
            ticks++;
            if (root.finished.length > 0 || ticks > 30) {
                console.log("INTERCEPT_REPORT: " + JSON.stringify({
                    ticks: ticks,
                    finished: root.finished,
                    isBusy: SessionService.isBusy
                }));
                Qt.quit();
            }
        }
    }
}
"""
    with tempfile.NamedTemporaryFile("w", suffix=".qml", delete=False) as f:
        harness_path = f.name
        f.write(test_qml)

    try:
        # 1. NIRI Session
        if os.path.exists(log_file):
            os.remove(log_file)
        env = os.environ.copy()
        env["PATH"] = f"{mock_dir}:{env.get('PATH', '')}"
        env["QML_IMPORT_PATH"] = str(PROJECT_ROOT / "shell")
        env["XDG_CURRENT_DESKTOP"] = "niri"
        env["NIRI_SOCKET"] = "/run/user/1000/niri.sock"
        env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
        env["MOCK_NIRI_EXIT"] = "0"

        proc = subprocess.run([qs_bin, "-p", harness_path], env=env, capture_output=True, text=True, timeout=10)
        invocations = [l.strip() for l in open(log_file).readlines() if l.strip()] if os.path.exists(log_file) else []
        record("KNOWN.NIRI.EXEC_COUNT", "Niri logout executes exactly 1 command", len(invocations) == 1, f"invs={invocations}")
        if len(invocations) >= 1:
            record("KNOWN.NIRI.EXACT_CMD", "Niri command is exactly 'niri msg action quit -s'",
                   invocations[0] == "niri msg action quit -s", f"got={invocations[0]}")
            record("KNOWN.NIRI.NO_HYPRCTL", "hyprctl was NOT executed under Niri",
                   not any("hyprctl" in inv for inv in invocations))
            record("KNOWN.NIRI.NO_LOGINCTL", "loginctl was NOT executed under Niri",
                   not any("loginctl" in inv for inv in invocations))

        # 2. HYPRLAND Session
        if os.path.exists(log_file):
            os.remove(log_file)
        env = os.environ.copy()
        env["PATH"] = f"{mock_dir}:{env.get('PATH', '')}"
        env["QML_IMPORT_PATH"] = str(PROJECT_ROOT / "shell")
        env["XDG_CURRENT_DESKTOP"] = "hyprland"
        env["HYPRLAND_INSTANCE_SIGNATURE"] = "instance_xyz"
        env.pop("NIRI_SOCKET", None)
        env["MOCK_HYPRCTL_EXIT"] = "0"

        proc = subprocess.run([qs_bin, "-p", harness_path], env=env, capture_output=True, text=True, timeout=10)
        invocations = [l.strip() for l in open(log_file).readlines() if l.strip()] if os.path.exists(log_file) else []
        record("KNOWN.HYPR.EXEC_COUNT", "Hyprland logout executes exactly 1 command", len(invocations) == 1, f"invs={invocations}")
        if len(invocations) >= 1:
            record("KNOWN.HYPR.EXACT_CMD", "Hyprland command is exactly 'hyprctl dispatch exit'",
                   invocations[0] == "hyprctl dispatch exit", f"got={invocations[0]}")
            record("KNOWN.HYPR.NO_NIRI", "niri was NOT executed under Hyprland",
                   not any("niri" in inv for inv in invocations))
            record("KNOWN.HYPR.NO_LOGINCTL", "loginctl was NOT executed under Hyprland",
                   not any("loginctl" in inv for inv in invocations))

    finally:
        if os.path.exists(harness_path):
            os.remove(harness_path)


# ==============================================================================
# Phase 5: Re-entrancy, Rapid Multiple Invocations & Action Guards
# ==============================================================================
def test_reentrancy_and_guards(qs_bin: str, mock_dir: str, log_file: str):
    print("\n--- Phase 5: Re-entrancy, Rapid Multi-Click & Guard Stress ---")

    stress_qml = """
import QtQuick
import Quickshell
import desktop.services

Scope {
    id: root
    property var triggered: []
    property var finished: []

    Connections {
        target: SessionService
        function onSessionActionTriggered(action) {
            root.triggered.push(action);
        }
        function onSessionActionFinished(action, code) {
            root.finished.push({ action: action, code: code });
        }
    }

    Timer {
        interval: 30
        running: true
        onTriggered: {
            // Rapidly spam logout 5 times back to back!
            SessionService.logout();
            SessionService.logout();
            SessionService.logout();
            SessionService.logout();
            SessionService.logout();
        }
    }

    Timer {
        interval: 60
        repeat: true
        running: true
        property int ticks: 0
        onTriggered: {
            ticks++;
            if (root.finished.length > 0 || ticks > 30) {
                console.log("RAPID_REPORT: " + JSON.stringify({
                    ticks: ticks,
                    triggeredCount: root.triggered.length,
                    finishedCount: root.finished.length,
                    isBusy: SessionService.isBusy
                }));
                Qt.quit();
            }
        }
    }
}
"""
    with tempfile.NamedTemporaryFile("w", suffix=".qml", delete=False) as f:
        harness_path = f.name
        f.write(stress_qml)

    try:
        if os.path.exists(log_file):
            os.remove(log_file)
        env = os.environ.copy()
        env["PATH"] = f"{mock_dir}:{env.get('PATH', '')}"
        env["QML_IMPORT_PATH"] = str(PROJECT_ROOT / "shell")
        env["XDG_CURRENT_DESKTOP"] = "niri"
        env["MOCK_NIRI_EXIT"] = "0"

        proc = subprocess.run([qs_bin, "-p", harness_path], env=env, capture_output=True, text=True, timeout=10)
        invocations = [l.strip() for l in open(log_file).readlines() if l.strip()] if os.path.exists(log_file) else []
        match_line = next((l for l in (proc.stdout + proc.stderr).splitlines() if "RAPID_REPORT:" in l), None)
        record("GUARD.RAPID.REPORT", "Rapid spam test parsed report", match_line is not None)
        if match_line:
            rep = json.loads(match_line.split("RAPID_REPORT:")[1].strip())
            # Even though triggered signal fires on each function call, process guard !logoutProcess.running
            # prevents spawning multiple processes simultaneously!
            record("GUARD.RAPID.SINGLE_EXEC", "Only 1 mock process was spawned despite 5 rapid clicks",
                   len(invocations) == 1, f"commandCount={len(invocations)}")
            record("GUARD.RAPID.CLEAN_FINISH", "Finished exactly once cleanly",
                   rep["finishedCount"] == 1, f"finishedCount={rep['finishedCount']}")
            record("GUARD.RAPID.IDLE", "System returned to idle (isBusy=false)",
                   rep["isBusy"] is False)

    finally:
        if os.path.exists(harness_path):
            os.remove(harness_path)


# ==============================================================================
# Phase 6: Subprocess Argument Array Safety & Shell Wrapper Invariance
# ==============================================================================
def test_ast_and_shell_safety():
    print("\n--- Phase 6: AST Invariants & Subshell Absence ---")

    code = SESSION_SERVICE_PATH.read_text(encoding="utf-8")
    clean_code = re.sub(r'//.*', '', code)
    clean_code = re.sub(r'/\*.*?\*/', '', clean_code, flags=re.DOTALL)

    # 1. Zero Timers
    has_timer = bool(re.search(r'\bTimer\s*\{', clean_code))
    record("AST.NO_TIMER", "Zero Timer components in SessionService.qml", not has_timer)

    # 2. Zero execDetached
    has_exec_detached = "execDetached" in clean_code
    record("AST.NO_EXEC_DETACHED", "Zero execDetached invocations", not has_exec_detached)

    # 3. Zero shell subshell wrappers (sh -c, bash -c)
    has_shell_subshell = bool(re.search(r'["\'](sh|bash|zsh)["\']\s*,\s*["\']-c["\']', clean_code))
    record("AST.NO_SHELL_SUBSHELL", "Zero sh/bash subshell invocations", not has_shell_subshell)

    # 4. Exactly 4 declarative Process nodes
    process_matches = list(re.finditer(r'Process\s*\{([^}]+)\}', clean_code))
    record("AST.PROCESS_COUNT", "Exactly 4 declarative Process nodes", len(process_matches) == 4, f"count={len(process_matches)}")

    # 5. Process nodes do not have static running: true
    has_static_running = bool(re.search(r'Process\s*\{[^}]*running\s*:\s*true', clean_code, re.DOTALL))
    record("AST.NO_STATIC_RUNNING", "Zero static running: true initializers in Process nodes", not has_static_running)

    # 6. Verify discrete arrays in Process commands
    # Check that logoutCommand is discrete array
    record("AST.LOGOUT_CMD_ARRAY", "logoutCommand defines discrete array with '-s' for Niri",
           '["niri", "msg", "action", "quit", "-s"]' in clean_code)
    record("AST.LOGOUT_CMD_HYPR", "logoutCommand defines discrete array for Hyprland",
           '["hyprctl", "dispatch", "exit"]' in clean_code)
    record("AST.FALLBACK_STAGE3_CMD", "fallbackStage 3 defines discrete array for loginctl",
           '["loginctl", "terminate-session", ""]' in clean_code)


def main():
    print("=" * 80)
    print("  CHALLENGER 1 EMPIRICAL VERIFICATION HARNESS: MILESTONE 2")
    print("  Target: Compositor Detection, Logout Interception & Fallback Transitions")
    print("=" * 80)

    qs_bin = discover_quickshell()
    if not qs_bin:
        print("FATAL: Quickshell binary not found!")
        sys.exit(1)
    print(f"Quickshell binary: {qs_bin}")

    mock_dir, log_file = create_mock_environment()
    print(f"Mock directory: {mock_dir}")
    print(f"Mock log file:  {log_file}")

    try:
        test_nix_integration()
        test_environment_permutations(qs_bin, mock_dir)
        test_fallback_execution_transitions(qs_bin, mock_dir, log_file)
        test_known_compositor_interception(qs_bin, mock_dir, log_file)
        test_reentrancy_and_guards(qs_bin, mock_dir, log_file)
        test_ast_and_shell_safety()
    finally:
        if os.path.exists(mock_dir):
            shutil.rmtree(mock_dir, ignore_errors=True)

    print("\n" + "=" * 80)
    print(f"CHALLENGER 1 M2 SUMMARY: Total: {total_tests} | Passed: {passed_tests} | Failed: {len(failed_tests)}")
    print("=" * 80)

    if failed_tests:
        print(f"\nFAILED TESTS ({len(failed_tests)}):")
        for tid, tdesc, det in failed_tests:
            print(f"  - {tid}: {tdesc} ({det})")
        print("\nVERDICT: REJECT")
        sys.exit(1)
    else:
        print("\nALL EMPIRICAL CHALLENGES PASSED (VERDICT: APPROVE)\n")
        sys.exit(0)


if __name__ == "__main__":
    main()
