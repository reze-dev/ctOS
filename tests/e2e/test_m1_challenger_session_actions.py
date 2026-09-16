#!/usr/bin/env python3
"""
Empirical Adversarial Challenger Suite for Milestone 1:
System Rail Session Actions Fix (Lock, Logout, Reboot, Poweroff)

Invariants Verified:
1. All Process nodes initialize with running === false statically and dynamically.
2. Clicking lock closes OverlayController and triggers lockProcess without confirmation.
3. Confirmation state machine: triggerConfirmation sets confirmationAction & isConfirming;
   cancelConfirmation clears without triggering process.
   Escape key traps cancellation without closing overlay.
4. Confirmed execution triggers respective process and closes OverlayController.
5. Invariant against arbitrary action injection & command injection.
6. Execution log verification via sandboxed mock binaries.
7. Zero polling, zero greeter imports, zero shell wrappers.
"""

import os
import sys
import tempfile
import subprocess
import shutil

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SYSTEM_RAIL_PATH = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/SystemRail.qml")
HARNESS_PATH = os.path.join(PROJECT_ROOT, "tests/e2e/harness/test_m1_session_actions_challenger.qml")

# Locate quickshell binary
QUICKSHELL_BIN = None
for candidate in [
    "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/bin/quickshell",
    "/run/current-system/sw/bin/quickshell"
]:
    if os.path.exists(candidate) and os.access(candidate, os.X_OK):
        QUICKSHELL_BIN = candidate
        break

if not QUICKSHELL_BIN:
    import glob
    candidates = glob.glob("/nix/store/*quickshell*/bin/quickshell")
    if candidates:
        QUICKSHELL_BIN = candidates[0]

total_tests = 0
passed_tests = 0
failed_tests = []

def record(test_id, cond, desc, details=""):
    global total_tests, passed_tests, failed_tests
    total_tests += 1
    if cond:
        passed_tests += 1
        print(f"  [PASS] {test_id}: {desc} {details}")
    else:
        failed_tests.append((test_id, desc, details))
        print(f"  [FAIL] {test_id}: {desc} | Details: {details}", file=sys.stderr)

def test_static_ast():
    print("\n--- Phase 1: Static AST & Declaration Invariants ---")
    with open(SYSTEM_RAIL_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    record("STAT.01", "import Quickshell.Io" in content, "SystemRail imports Quickshell.Io")
    record("STAT.02", "id: lockProcess" in content, "SystemRail declares lockProcess")
    record("STAT.03", "id: logoutProcess" in content, "SystemRail declares logoutProcess")
    record("STAT.04", "id: rebootProcess" in content, "SystemRail declares rebootProcess")
    record("STAT.05", "id: poweroffProcess" in content, "SystemRail declares poweroffProcess")

    # Invariant: Zero running: true literal declarations
    import re
    running_true_matches = re.findall(r'running\s*:\s*true', content)
    record("STAT.06", len(running_true_matches) == 0, "Zero literal 'running: true' declarations", f"matches={len(running_true_matches)}")

    # Invariant: running: false declared for processes
    running_false_matches = re.findall(r'running\s*:\s*false', content)
    record("STAT.07", len(running_false_matches) >= 4, "At least 4 'running: false' declarations", f"matches={len(running_false_matches)}")

    # Invariant: Zero sh -c or bash -c command invocations
    record("STAT.08", "sh -c" not in content and "bash -c" not in content, "Zero shell wrapper ('sh -c' / 'bash -c') invocations")

    # Discrete commands
    record("STAT.09", 'command: ["loginctl", "lock-session"]' in content, "lockProcess discrete command array")
    record("STAT.10", 'command: ["hyprctl", "dispatch", "exit"]' in content, "logoutProcess discrete command array")
    record("STAT.11", 'command: ["systemctl", "reboot"]' in content, "rebootProcess discrete command array")
    record("STAT.12", 'command: ["systemctl", "poweroff"]' in content, "poweroffProcess discrete command array")

    # Lock button wiring
    lock_block = re.search(r'id:\s*lockMouseArea[\s\S]*?onClicked:\s*\{([\s\S]*?)\}', content)
    record("STAT.13", lock_block is not None, "lockMouseArea onClicked handler present")
    if lock_block:
        body = lock_block.group(1)
        record("STAT.14", "OverlayController.close()" in body, "lock button calls OverlayController.close()")
        record("STAT.15", "lockProcess.running = true" in body, "lock button sets lockProcess.running = true")

    # executeConfirmation wiring
    exec_block = re.search(r'function executeConfirmation\(\)[\s\S]*?\{([\s\S]*?)\n    \}', content)
    record("STAT.16", exec_block is not None, "executeConfirmation function present")
    if exec_block:
        ebody = exec_block.group(1)
        record("STAT.17", 'OverlayController.close()' in ebody, "executeConfirmation closes overlay")
        record("STAT.18", 'rebootProcess.running = true' in ebody, "executeConfirmation triggers rebootProcess")
        record("STAT.19", 'poweroffProcess.running = true' in ebody, "executeConfirmation triggers poweroffProcess")
        record("STAT.20", 'logoutProcess.running = true' in ebody, "executeConfirmation triggers logoutProcess")

def test_dynamic_runtime():
    print("\n--- Phase 2: Dynamic QML Runtime & Sandbox Command Execution ---")
    if not QUICKSHELL_BIN:
        record("DYN.01", False, "Quickshell binary found", "Not found in nix store")
        return

    record("DYN.01", True, "Quickshell binary found", f"path={QUICKSHELL_BIN}")

    # Create temporary mock bin directory and log file
    tmp_dir = tempfile.mkdtemp(prefix="ctos_m1_challenger_")
    mock_log = os.path.join(tmp_dir, "exec.log")

    try:
        # Create mock binaries
        for bin_name in ["loginctl", "hyprctl", "systemctl"]:
            bin_path = os.path.join(tmp_dir, bin_name)
            with open(bin_path, "w") as f:
                f.write(f"#!/bin/sh\necho \"{bin_name}: $*\" >> \"{mock_log}\"\nexit 0\n")
            os.chmod(bin_path, 0o755)

        env = os.environ.copy()
        env["PATH"] = f"{tmp_dir}:{env.get('PATH', '')}"
        env["QML_IMPORT_PATH"] = os.path.join(PROJECT_ROOT, "shell")
        settings_tmp = os.path.join(tmp_dir, "settings.json")
        with open(settings_tmp, "w") as f:
            f.write('{"reducedMotion": false}')
        env["CTOS_SETTINGS_PATH"] = settings_tmp

        cmd = [QUICKSHELL_BIN, "-p", HARNESS_PATH]
        res = subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=15)

        record("DYN.02", res.returncode == 0, "Quickshell test harness exited cleanly (0)", f"exit={res.returncode}")
        record("DYN.03", "=== PASS: M1 SYSTEM RAIL SESSION ACTIONS RUNTIME HARNESS ===" in res.stdout,
               "Harness reported PASS for all 66 runtime assertions")

        # Verify execution log
        if os.path.exists(mock_log):
            with open(mock_log, "r") as f:
                log_lines = [line.strip() for line in f if line.strip()]

            expected_log = [
                "loginctl: lock-session",
                "hyprctl: dispatch exit",
                "systemctl: reboot",
                "systemctl: poweroff"
            ]
            record("DYN.04", log_lines == expected_log, "Mock execution log matches exact expected sequence", f"log={log_lines}")
        else:
            record("DYN.04", False, "Mock execution log created", "File not found")

    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

def test_regression_suites():
    print("\n--- Phase 3: Project Regression & Boundary Suites ---")
    scripts = [
        ("REG.01", "tests/e2e/tier1_features/test_t5_immediate_session_lock.sh"),
        ("REG.02", "tests/e2e/tier1_features/test_t5_allowlisted_execution.sh"),
        ("REG.03", "tests/e2e/tier1_features/test_t5_safe_cancel_escape.sh"),
        ("REG.04", "tests/e2e/tier2_boundaries/test_t5_allowlisted_execution_boundaries.sh"),
        ("REG.05", "tests/e2e/tier2_boundaries/test_t5_immediate_lock_boundaries.sh"),
        ("REG.06", "tests/e2e/tier2_boundaries/test_t5_safe_cancel_escape_boundaries.sh"),
        ("REG.07", "tests/e2e/tier4_real_world/test_t5_destructive_reboot_sequence_abort.sh"),
    ]

    for test_id, script_rel in scripts:
        script_path = os.path.join(PROJECT_ROOT, script_rel)
        if not os.path.exists(script_path):
            record(test_id, False, f"Script exists: {script_rel}", "Missing")
            continue

        res = subprocess.run(["bash", script_path], cwd=PROJECT_ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        record(test_id, res.returncode == 0, f"Passes {script_rel}", f"exit={res.returncode}")

def test_inspectors():
    print("\n--- Phase 4: Static Inspectors (Zero Polling, Greeter, Formatting) ---")
    commands = [
        ("INSP.01", ["python3", "tests/e2e/harness/qml_inspector.py", "check-polling", "shell/desktop"]),
        ("INSP.02", ["python3", "tests/e2e/harness/qml_inspector.py", "check-greeter", "shell/desktop"]),
        ("INSP.03", ["python3", "tests/e2e/harness/qml_inspector.py", "check-format", "shell/desktop"]),
    ]

    for test_id, cmd in commands:
        res = subprocess.run(cmd, cwd=PROJECT_ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        record(test_id, res.returncode == 0, f"Inspector {' '.join(cmd[2:])}", f"output={res.stdout.strip()}")

if __name__ == "__main__":
    print("=================================================================")
    print("=== EMPIRICAL CHALLENGER VERIFICATION: MILESTONE 1 (SESSION) ===")
    print("=================================================================")

    test_static_ast()
    test_dynamic_runtime()
    test_regression_suites()
    test_inspectors()

    print("\n=================================================================")
    print(f"Total Tests : {total_tests}")
    print(f"Passed      : {passed_tests}")
    print(f"Failed      : {len(failed_tests)}")
    print("=================================================================")

    if failed_tests:
        print("\nFAILURES:")
        for t_id, desc, details in failed_tests:
            print(f"  - [{t_id}] {desc}: {details}")
        sys.exit(1)
    else:
        print("\nALL VERIFICATIONS PASSED SUCCESSFULLY!")
        sys.exit(0)
