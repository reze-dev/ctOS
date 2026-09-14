#!/usr/bin/env python3
"""
test_m4_adversarial_challenger.py - Empirical Adversarial Stress Test Suite for Milestone 4:
Requirement R6: Fix WiFi Disconnection & Slow Response.

Author: challenger_m4_g3_1_r (Critic & Specialist)
Purpose: Rigorously challenge the 10-second watchdog and 15-second timeout logic against edge cases,
         concurrent connections, roaming collisions, abort sequences, and live runtime lifecycles.
"""

import os
import re
import sys
import subprocess
import time

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SHELL_DIR = os.path.join(PROJECT_ROOT, "shell", "desktop")
QS_BIN = "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/bin/quickshell"

PASS_COUNT = 0
FAIL_COUNT = 0
FINDINGS = []


def record(test_id, desc, passed, details=""):
    global PASS_COUNT, FAIL_COUNT
    if passed:
        PASS_COUNT += 1
        print(f"[PASS] {test_id}: {desc} ({details})")
    else:
        FAIL_COUNT += 1
        FINDINGS.append((test_id, desc, details))
        print(f"[FAIL] {test_id}: {desc} ({details})", file=sys.stderr)


print("=" * 80)
print("ctOS Empirical Challenger: Milestone 4 WiFi Adversarial Audit & Stress Suite")
print("=" * 80)

# ==============================================================================
# SECTION 1: Baseline AST Audit (test_m4_wifi_audit.py)
# ==============================================================================
print("\n--- Section 1: Baseline AST & Static Audit ---")
res_ast = subprocess.run(["python3", "tests/e2e/test_m4_wifi_audit.py"],
                         capture_output=True, text=True, cwd=PROJECT_ROOT)
record(
    "CHAL.AST.01",
    "test_m4_wifi_audit.py executes cleanly (43/43 assertions)",
    res_ast.returncode == 0,
    f"returncode={res_ast.returncode}"
)

# ==============================================================================
# SECTION 2: Headless Quickshell Runtime Harness (test_m4_wifi_runtime.qml)
# ==============================================================================
print("\n--- Section 2: Quickshell Runtime Baseline Harness ---")
env = os.environ.copy()
env["QML_IMPORT_PATH"] = os.path.join(PROJECT_ROOT, "shell")

res_runtime = subprocess.run(
    [QS_BIN, "-p", "tests/e2e/harness/test_m4_wifi_runtime.qml"],
    capture_output=True, text=True, env=env, cwd=PROJECT_ROOT, timeout=15
)
out_runtime = res_runtime.stdout + res_runtime.stderr
runtime_ok = "=== PASS: M4 WIFI RUNTIME HARNESS SUCCESSFUL ===" in out_runtime
record(
    "CHAL.RUN.01",
    "test_m4_wifi_runtime.qml executes cleanly (14/14 assertions)",
    runtime_ok,
    "Passed=14, Failed=0" if runtime_ok else "runtime harness reported failures"
)

# ==============================================================================
# SECTION 3: Edge Cases Harness (test_m4_edge_cases.qml)
# ==============================================================================
print("\n--- Section 3: Edge Cases: Rapid Calls, Abort & Watchdog Collision ---")
res_edge = subprocess.run(
    [QS_BIN, "-p", "tests/e2e/harness/test_m4_edge_cases.qml"],
    capture_output=True, text=True, env=env, cwd=PROJECT_ROOT, timeout=15
)
out_edge = res_edge.stdout + res_edge.stderr

# Rapid repeated connection calls
record(
    "CHAL.EDGE.RAPID",
    "Repeated rapid connection calls cleanly update target SSID",
    "[PASS] EDGE.RAPID.03" in out_edge and "[PASS] EDGE.RAPID.04" in out_edge,
    "rapid calls update connectingSsid without crash or stale state"
)

# Abort during connect
record(
    "CHAL.EDGE.ABORT",
    "Abort during connect (disconnect and radio off) stops connecting cleanly",
    "[PASS] EDGE.ABORT.02" in out_edge and "[PASS] EDGE.ABORT.04" in out_edge,
    "aborts reset connectingSsid and isConnecting"
)

# Watchdog collision with existing Wi-Fi connection
edge_coll2_pass = "[PASS] EDGE.COLL.02" in out_edge
record(
    "CHAL.EDGE.COLL_WIFI",
    "Watchdog evaluating existing Wi-Fi does NOT prematurely destroy active connecting attempt",
    edge_coll2_pass,
    "connectingSsid preserved" if edge_coll2_pass else "CRITICAL BUG: _applyConnectedState prematurely clears connectingSsid on watchdog re-evaluation of existing connection!"
)

# Watchdog collision with active Ethernet
edge_coll3_pass = "[PASS] EDGE.COLL.03" in out_edge
record(
    "CHAL.EDGE.COLL_ETH",
    "Watchdog evaluating active Ethernet does NOT prematurely destroy active Wi-Fi connecting attempt",
    edge_coll3_pass,
    "connectingSsid preserved" if edge_coll3_pass else "CRITICAL BUG: _applyConnectedState prematurely clears connectingSsid on active Ethernet!"
)

# ==============================================================================
# SECTION 4: Live 15-Second Real Timeout & Watchdog Lifecycle (test_m4_adversarial_runtime.qml)
# ==============================================================================
print("\n--- Section 4: Live Real-Time 15-Second Timeout & Watchdog Lifecycle ---")
t0 = time.time()
res_adv = subprocess.run(
    [QS_BIN, "-p", "tests/e2e/harness/test_m4_adversarial_runtime.qml"],
    capture_output=True, text=True, env=env, cwd=PROJECT_ROOT, timeout=25
)
elapsed = time.time() - t0
out_adv = res_adv.stdout + res_adv.stderr

wdg_abort_pass = "[PASS] ADV.TMO.REAL.03" in out_adv
record(
    "CHAL.LIVE.WDG_PRESERVE",
    "At t=10.5s live, 10s watchdog re-evaluation preserves active connectingSsid",
    wdg_abort_pass,
    f"elapsed={elapsed:.1f}s, " + ("preserved" if wdg_abort_pass else "CRITICAL BUG: connectingSsid prematurely aborted by 10s watchdog")
)

tmo_error_pass = "[PASS] ADV.TMO.REAL.06" in out_adv
record(
    "CHAL.LIVE.TMO_ERROR",
    "At t=15.3s live, lastError populated with 'Connection timed out'",
    tmo_error_pass,
    "lastError set correctly" if tmo_error_pass else "CRITICAL BUG: 15s timeout failed to fire because timer was stopped prematurely by watchdog"
)

tmo_sig_pass = "[PASS] ADV.TMO.REAL.07" in out_adv
record(
    "CHAL.LIVE.TMO_SIGNAL",
    "At t=15.3s live, connectionFailed signal emitted on timeout",
    tmo_sig_pass,
    "signal emitted" if tmo_sig_pass else "CRITICAL BUG: connectionFailed signal never emitted due to premature watchdog cancellation"
)

# ==============================================================================
# SUMMARY & VERDICT
# ==============================================================================
print("\n" + "=" * 80)
print(f"EMPIRICAL CHALLENGER SUMMARY: Passed={PASS_COUNT}, Failed={FAIL_COUNT}")
print("=" * 80)
if FAIL_COUNT > 0:
    print(f"\nCRITICAL DEFECTS CONFIRMED ({FAIL_COUNT}):", file=sys.stderr)
    for f_id, f_desc, f_det in FINDINGS:
        print(f"  - [{f_id}] {f_desc}: {f_det}", file=sys.stderr)
    print("\nVERDICT: REJECT")
    sys.exit(1)
else:
    print("\nVERDICT: APPROVE")
    sys.exit(0)
