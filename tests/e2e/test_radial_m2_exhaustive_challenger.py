#!/usr/bin/env python3
"""
test_radial_m2_exhaustive_challenger.py
Exhaustive Empirical Challenger Verification for Milestone 2 Transition Choreography.

Executes `test_radial_m2_exhaustive_adversarial.qml` through Quickshell, verifying:
1. Exact expand durations across all 9 categories (<700ms limit).
2. Exact collapse durations across all 9 categories (<700ms limit).
3. Exact clean return to 0.0 wheelRotation across all 9 categories.
4. Multi-revolution boundary traversal in clockwise direction (-720 deg) with clean 0.0 return.
5. Multi-revolution boundary traversal in counter-clockwise direction (+720 deg) with clean 0.0 return.
6. Mid-flight interruption and churn recovery with clean 0.0 return.
"""

import os
import re
import subprocess
import sys

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
HARNESS_DIR = os.path.join(PROJECT_ROOT, "tests/e2e/harness")
QUICKSHELL_BIN = "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/bin/quickshell"

def run_harness(qml_file, timeout_sec=30):
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
    return proc.returncode, clean_out

def main():
    print("=" * 80)
    print("EXHAUSTIVE EMPIRICAL CHALLENGER: MILESTONE 2 TRANSITIONS & ROTATION DRIFT")
    print("=" * 80)

    ret, output = run_harness("test_radial_m2_exhaustive_adversarial.qml", timeout_sec=35)
    for line in output.splitlines():
        if any(prefix in line for prefix in ["[PASS]", "[FAIL]", "=== ", "Final", "After"]):
            print("  " + line)

    has_fail = "[FAIL]" in output or "DEFECTS DETECTED" in output or ret != 0
    print("=" * 80)
    if has_fail:
        print("EXHAUSTIVE CHALLENGER VERDICT: REJECT")
        sys.exit(1)
    else:
        print("EXHAUSTIVE CHALLENGER VERDICT: APPROVE")
        sys.exit(0)

if __name__ == "__main__":
    main()
