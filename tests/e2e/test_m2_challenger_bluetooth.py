#!/usr/bin/env python3
"""
================================================================================
CHALLENGER 1 EMPIRICAL VERIFICATION SUITE: MILESTONE 2
Bluetooth Backend Service Expansion (BluetoothService.qml)
================================================================================
Target: shell/desktop/services/BluetoothService.qml

Verifies:
1. Public Interface Contract & Method Declarations
2. Static Invariants (Zero Polling, Zero persistent Process running: true, No sh/bash -c)
3. Startup State & Model Initialization Invariants
4. Synthetic Parser Output Injections:
   - _parseShowOutput (on, off, missing controller, bluetoothd crash)
   - _parseConnectedOutput (single, multi, empty, unicode)
   - _parseDevicesOutput (inventory population, state preservation)
   - _parsePairedOutput (paired reconciliation, unpairing)
   - _parseScanOutput (new discovery, property updates, deletion)
5. Control Character Sanitization (\x00-\x1F\x7F) & 60+ Char Name Truncation
6. Power State Transitions & Discovered Device Cleanup Invariant
================================================================================
"""

import json
import os
import re
import subprocess
import sys
import tempfile

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SERVICE_PATH = os.path.join(PROJECT_ROOT, "shell/desktop/services/BluetoothService.qml")
QUICKSHELL_BIN = "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/bin/quickshell"

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

print("=" * 80)
print("CHALLENGER 1 EMPIRICAL SUITE: MILESTONE 2 (BLUETOOTH BACKEND SERVICE)")
print("=" * 80)

# ==============================================================================
# PHASE 1: STATIC CODE & INVARIANT AUDIT
# ==============================================================================
print("\n--- Phase 1: Static Code & Invariant Audit ---")

with open(SERVICE_PATH, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Pragma & Singleton
record("CHAL.STAT.01", "pragma Singleton" in content, "BluetoothService declares pragma Singleton")
record("CHAL.STAT.02", bool(re.search(r"^\s*Singleton\s*\{", content, re.MULTILINE)), "Root item is Singleton")

# 2. Process Safety & Invariants
process_blocks = re.findall(r"Process\s*\{([^}]+)\}", content)
record("CHAL.STAT.03", len(process_blocks) >= 7, f"Contains at least 7 Process instances (found {len(process_blocks)})")

has_running_true = bool(re.search(r"Process\s*\{[^}]*running\s*:\s*true", content, re.DOTALL))
record("CHAL.STAT.04", not has_running_true, "No Process instance statically declared with running: true")

has_sh_c = bool(re.search(r'[\"\'](?:sh|bash)[\"\']\s*,\s*[\"\']-c[\"\']', content))
record("CHAL.STAT.05", not has_sh_c, "No subshell invocations (sh -c / bash -c)")

literal_running_true = bool(re.search(r"running\s*:\s*true", content))
record("CHAL.STAT.06", not literal_running_true, "Zero literal 'running: true' tokens in file")

# 3. Timeout bounds on action commands
record("CHAL.STAT.07", '["bluetoothctl", "--timeout", "10", "connect", mac]' in content, "connectDevice uses --timeout 10")
record("CHAL.STAT.08", '["bluetoothctl", "--timeout", "10", "disconnect", mac]' in content, "disconnectDevice uses --timeout 10")
record("CHAL.STAT.09", '["bluetoothctl", "--timeout", "15", "pair", mac]' in content, "pairDevice uses --timeout 15")
record("CHAL.STAT.10", '["bluetoothctl", "--timeout", "15", "scan", "on"]' in content, "scanProcess uses --timeout 15")

# ==============================================================================
# PHASE 2: STATIC POLICY AUDITS
# ==============================================================================
print("\n--- Phase 2: Static Policy Audits (qml_inspector & qmllint) ---")

res_poll = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-polling", "shell/desktop"],
                          capture_output=True, text=True, cwd=PROJECT_ROOT)
record("CHAL.POL.01", res_poll.returncode == 0, "check-polling reports zero violations", res_poll.stdout.strip())

res_greet = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-greeter", "shell/desktop"],
                           capture_output=True, text=True, cwd=PROJECT_ROOT)
record("CHAL.POL.02", res_greet.returncode == 0, "check-greeter reports zero violations", res_greet.stdout.strip())

res_fmt = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-format", "shell/desktop"],
                         capture_output=True, text=True, cwd=PROJECT_ROOT)
record("CHAL.POL.03", res_fmt.returncode == 0, "check-format reports zero violations", res_fmt.stdout.strip())

res_lint = subprocess.run(["qmllint", SERVICE_PATH], capture_output=True, text=True, cwd=PROJECT_ROOT)
record("CHAL.POL.04", res_lint.returncode == 0, "qmllint succeeds on BluetoothService.qml", f"code={res_lint.returncode}")

# ==============================================================================
# PHASE 3: LIVE QUICKSHELL RUNTIME VERIFICATION
# ==============================================================================
print("\n--- Phase 3: Quickshell Runtime Verification & State Invariants ---")

harness_path = os.path.join(PROJECT_ROOT, "tests/e2e/harness/test_m2_bluetooth_backend_challenger.qml")
env = os.environ.copy()
env["QML_IMPORT_PATH"] = os.path.join(PROJECT_ROOT, "shell")
env["CTOS_SETTINGS_PATH"] = "/tmp/ctos_test_settings.json"

res_qs = subprocess.run([QUICKSHELL_BIN, "-p", harness_path],
                        capture_output=True, text=True, env=env, timeout=12)

# Parse harness stdout
output_lines = res_qs.stdout.splitlines()
pass_lines = [l for l in output_lines if "[PASS]" in l]
fail_lines = [l for l in output_lines if "[FAIL]" in l]

for l in pass_lines:
    match = re.search(r"\[PASS\]\s+([^:]+):\s+(.*)", l)
    if match:
        record(f"QS.{match.group(1)}", True, match.group(2))

for l in fail_lines:
    match = re.search(r"\[FAIL\]\s+([^:]+):\s+(.*)", l)
    if match:
        record(f"QS.{match.group(1)}", False, match.group(2))

print("\n" + "=" * 80)
print(f"SUMMARY: Total={total_tests}, Passed={passed_tests}, Failed={len(failed_tests)}")
if failed_tests:
    print("CONFIRMED FAILURES:")
    for fid, fdesc, fdet in failed_tests:
        print(f"  - {fid}: {fdesc} ({fdet})")
    print("=" * 80)
    sys.exit(1)
else:
    print("ALL TESTS PASSED")
    print("=" * 80)
    sys.exit(0)
