#!/usr/bin/env python3
"""
test_radial_m3_adversarial_stress.py
Adversarial Boundary & Stress Challenger for ctOS Radial Settings Milestone 3 (Requirement R2: Edge Alignment).

Executes `test_radial_m3_adversarial_stress.qml` through Quickshell, verifying:
1. Dynamic model mutations & boundary values:
   - categoryCount = 0: safe rootNode evaluation to null, empty activeNodes, no division by zero.
   - Empty category (nodes.length = 0): safe rootNode null handling, default anchorRay fallback (70, 0), zero TypeErrors.
   - Single node category (1 node, no children): anchorRay targets root node, 0 inter-node edges, node center aligned.
   - Negative & extreme coordinates: edge and anchorRay coordinates track perfectly without overflow or drift.
   - Dangling / phantom child node references: omitted safely without throwing errors.
   - Graceful cascade offset degradation for out-of-bounds indices (index >= 8 returns 0.0).
2. Preview subtree polar alignment oracle:
   - All 9 preview subtrees follow reactive 40 deg polar layout (segAngle = 40.0 deg, baseAngle = -90.0 + i * 40.0 deg).
   - Polar anchor points (r0, r1, c1, c2, c3) adhere to exact trigonometry (max error < 1e-4).
3. Live 9-category edge alignment invariance oracle:
   - For all 9 categories (0..8), anchorRay connects wheel perimeter (wheelCenterX + 205, wheelCenterY) to root node center.
   - For all edges across all categories, edge endpoints (x1, y1) and (x2, y2) strictly coincide with parent and child node centers.
   - Edge count matches model edge definitions with 0 lingering or missing edges.
4. Rapid expand/collapse cycles & cascade animation churn:
   - 40 rapid toggles of isExpanded during active cascade animations (Theme.durationSlow = 350ms-770ms).
   - Real-time frame-by-frame invariance verification: max drift between edge endpoints and node centers is < 1e-4 (zero edge tearing).
5. In-flight category switching while expanded:
   - 20 rapid in-flight category retargetings during active animations across all 9 categories.
   - Immediate edge list synchronization (zero residual edges from prior categories).
   - Immediate anchorRay retargeting to new root node.
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
    print("ADVERSARIAL CHALLENGER: MILESTONE 3 (R2 EDGE ALIGNMENT & BOUNDARY STRESS)")
    print("=" * 80)

    ret, output = run_harness("test_radial_m3_adversarial_stress.qml", timeout_sec=35)
    pass_lines = []
    fail_lines = []
    for line in output.splitlines():
        if "[PASS]" in line:
            pass_lines.append(line)
            print("  " + line)
        elif "[FAIL]" in line:
            fail_lines.append(line)
            print("  " + line)
        elif "=== " in line or "RESULTS:" in line:
            print(line)

    has_fail = len(fail_lines) > 0 or "FAIL:" in output or ret != 0 or len(pass_lines) < 45
    print("=" * 80)
    print(f"SUMMARY: {len(pass_lines)} PASSED, {len(fail_lines)} FAILED, EXIT CODE {ret}")
    if has_fail:
        print("M3 CHALLENGER VERDICT: REJECT")
        sys.exit(1)
    else:
        print("M3 CHALLENGER VERDICT: APPROVE")
        sys.exit(0)

if __name__ == "__main__":
    main()
