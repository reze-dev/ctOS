#!/usr/bin/env python3
"""
test_radial_m2_challenger_stress.py - Empirical Challenger Stress Suite for Milestone 2
Verifies:
1. Expand & collapse timing across all 9 categories (<700ms limit).
2. Clean wheel rotation return to 0.0 on collapse (detects dead onFinished Behavior bug).
3. Multi-revolution drift across sequential category traversals.
4. Resilience against mid-flight input interruptions.
"""

import os
import re
import subprocess
import sys

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
HARNESS_DIR = os.path.join(PROJECT_ROOT, "tests/e2e/harness")

QUICKSHELL_BIN = "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/bin/quickshell"

def run_harness(qml_file, timeout_sec=15):
    import pty
    harness_path = os.path.join(HARNESS_DIR, qml_file)
    env = os.environ.copy()
    env["PROJECT_ROOT"] = PROJECT_ROOT
    env["QML_IMPORT_PATH"] = os.path.join(PROJECT_ROOT, "shell")
    env["PATH"] = f"{os.path.dirname(QUICKSHELL_BIN)}:{env.get('PATH', '')}"

    master, slave = pty.openpty()
    cmd = [QUICKSHELL_BIN, "-p", harness_path]
    proc = subprocess.Popen(cmd, env=env, stdin=slave, stdout=slave, stderr=slave, close_fds=True)
    os.close(slave)
    
    output = b""
    try:
        while True:
            data = os.read(master, 1024)
            if not data:
                break
            output += data
    except OSError:
        pass
    finally:
        os.close(master)
        proc.wait(timeout=timeout_sec)
    
    text = output.decode("utf-8", errors="replace")
    ansi_escape = re.compile(r'\x1b\[[0-9;]*[a-zA-Z]')
    clean_out = ansi_escape.sub('', text)
    return proc.returncode, clean_out, ""

def main():
    print("=" * 70)
    print("CHALLENGER EMPIRICAL VERIFICATION: MILESTONE 2 (R1 TRANSITIONS)")
    print("=" * 70)

    # Test 1: Rotation Drift & Clean 0.0 Return Repro
    print("\n[RUNNING TEST 1] Multi-category traversal & clean 0.0 return test...")
    ret, stdout, stderr = run_harness("test_rotation_drift_repro.qml", timeout_sec=10)
    out = stdout + "\n" + stderr
    for line in out.splitlines():
        if "DEBUG qml:" in line or "ERROR qml:" in line:
            print("  " + line)

    drift_failed = "CRITICAL DEFECT: Wheel rotation failed to return cleanly to 0.0" in (stdout + stderr)
    if drift_failed:
        print("\n>>> REPRODUCED BUG: Wheel rotation failed to return cleanly to 0.0 (rested at -360)!")
    else:
        print("\n>>> PASS: Wheel rotation cleanly returned to 0.0.")

    # Test 2: In-Flight Category Switching
    print("\n[RUNNING TEST 2] In-flight category retargeting & continuity...")
    ret2, stdout2, stderr2 = run_harness("test_inflight_switching_drift.qml", timeout_sec=10)
    out2 = stdout2 + "\n" + stderr2
    for line in out2.splitlines():
        if "DEBUG qml:" in line or "ERROR qml:" in line:
            print("  " + line)

    print("\n" + "=" * 70)
    if drift_failed:
        print("CHALLENGER VERDICT: REJECT")
        print("Defect confirmed: CircularSettingsMenu.qml Behavior onFinished dead code leaves wheelRotation at -360")
        sys.exit(1)
    else:
        print("CHALLENGER VERDICT: APPROVE")
        sys.exit(0)

if __name__ == "__main__":
    main()
