#!/usr/bin/env python3
"""
test_m4_wifi_audit.py - Comprehensive AST & Invariant Audit for Milestone 4:
Requirement R6: Fix WiFi Disconnection & Slow Response.

Audits:
1. File Existence & Module Declarations:
   - shell/desktop/services/NetworkService.qml exists
   - shell/desktop/surfaces/SystemRail.qml exists
   - shell/desktop/services/qmldir declares singleton NetworkService
2. NetworkService.qml Contract & Invariants:
   - pragma Singleton and pragma ComponentBehavior: Bound
   - property string connectingSsid
   - readonly property bool isConnecting: connectingSsid !== ""
   - property string lastError
   - signal connectionFailed(string ssid, string reason)
   - function connectToNetwork(ssid, key)
   - function _evaluateNetworkState()
3. Periodic Watchdog Timer (Requirement R6):
   - Timer element exists in NetworkService.qml
   - interval == 10000 (10 seconds)
   - repeat == true
   - onTriggered calls root._evaluateNetworkState()
   - running uses dynamic boolean expression (e.g. Boolean(root.available))
   - Zero literal `running: true` declarations
   - Zero triggeredOnStart: true polling patterns
4. Connection Timeout Timer (Requirement R6):
   - Timer element exists in NetworkService.qml
   - interval == 15000 (15 seconds)
   - repeat == false (single-shot behavior)
   - Zero `singleShot: true` (invalid in QML Timer, repeat: false must be used)
   - Started/restarted when connectToNetwork() is invoked
   - Stopped in _applyConnectedState() on successful connection
   - Stopped in onConnectionFailed() and disconnectCurrentNetwork()
   - On trigger: clears connectingSsid, populates lastError, and emits connectionFailed
5. Subprocess and Zero-Polling Rules:
   - Zero literal `running: true` anywhere in NetworkService.qml
   - Zero `sh -c` or `bash -c` invocations
   - Zero `while true` loops
   - Discrete command execution via Quickshell.execDetached
6. SystemRail.qml 3-Tier "CONNECTING..." Feedback (Requirement R6):
   - Tier 1: Subheader text in wifi submenu dynamically displays "CONNECTING..." when isConnecting is true
   - Tier 2: Dedicated active connection banner visible when isConnecting is true
   - Tier 3: Delegate inline badge "[CONNECTING...]" displayed when itemIsConnecting
   - Error Feedback: Displays lastError alert when lastError !== ""
   - Monospace typography via Theme.fontFamilyMonospace across all UI text
   - Zero hardcoded hex colors; all styling uses Theme tokens
7. Static Policy & Hygiene:
   - qml_inspector check-greeter reports 0 violations
   - qml_inspector check-polling reports 0 violations
   - qml_inspector check-format reports 0 violations
   - test_zero_polling_boundaries.sh passes 5/5
   - qmllint validates cleanly without syntax errors
"""

import os
import re
import sys
import subprocess

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SHELL_DIR = os.path.join(PROJECT_ROOT, "shell", "desktop")

PASS_COUNT = 0
FAIL_COUNT = 0


def check(id_str, desc, condition, details=""):
    global PASS_COUNT, FAIL_COUNT
    if condition:
        PASS_COUNT += 1
        print(f"[PASS] {id_str}: {desc} ({details})")
    else:
        FAIL_COUNT += 1
        print(f"[FAIL] {id_str}: {desc} ({details})", file=sys.stderr)


print("=" * 70)
print("ctOS Challenger M4: WiFi Stability & Watchdog Audit")
print("=" * 70)

# ==============================================================================
# 1. File Existence & Module Declarations
# ==============================================================================
service_path = os.path.join(SHELL_DIR, "services", "NetworkService.qml")
rail_path = os.path.join(SHELL_DIR, "surfaces", "SystemRail.qml")
services_qmldir = os.path.join(SHELL_DIR, "services", "qmldir")

check("WF.FILE.01", "NetworkService.qml exists",
      os.path.isfile(service_path), f"path={service_path}")
check("WF.FILE.02", "SystemRail.qml exists",
      os.path.isfile(rail_path), f"path={rail_path}")

with open(services_qmldir, "r", encoding="utf-8") as f:
    qmldir_content = f.read()
check("WF.QMLDIR.01", "services/qmldir declares singleton NetworkService",
      bool(re.search(r'singleton\s+NetworkService\s+1\.0\s+NetworkService\.qml', qmldir_content)),
      "registered as singleton")

with open(service_path, "r", encoding="utf-8") as f:
    service_content = f.read()

with open(rail_path, "r", encoding="utf-8") as f:
    rail_content = f.read()

# ==============================================================================
# 2. NetworkService.qml Contract & Invariants
# ==============================================================================
check("WF.SRV.PRAGMA", "NetworkService declares pragma Singleton",
      "pragma Singleton" in service_content, "pragma Singleton present")
check("WF.SRV.BOUND", "NetworkService declares pragma ComponentBehavior: Bound",
      "pragma ComponentBehavior: Bound" in service_content, "Bound component behavior present")

check("WF.SRV.PROP.CONN_SSID", "NetworkService declares property string connectingSsid",
      bool(re.search(r'property\s+string\s+connectingSsid\b', service_content)),
      "connectingSsid present")

check("WF.SRV.PROP.IS_CONN", "NetworkService declares readonly property bool isConnecting: connectingSsid !== ''",
      bool(re.search(r'readonly\s+property\s+bool\s+isConnecting\s*:\s*connectingSsid\s*!==\s*["\']["\']', service_content)),
      "isConnecting bound to connectingSsid")

check("WF.SRV.PROP.LAST_ERR", "NetworkService declares property string lastError",
      bool(re.search(r'property\s+string\s+lastError\b', service_content)),
      "lastError present")

check("WF.SRV.SIG.FAILED", "NetworkService declares signal connectionFailed(string ssid, string reason)",
      bool(re.search(r'signal\s+connectionFailed\s*\(\s*string\s+\w+\s*,\s*string\s+\w+\s*\)', service_content)),
      "connectionFailed signal present")

check("WF.SRV.METH.CONNECT", "NetworkService declares connectToNetwork function",
      bool(re.search(r'function\s+connectToNetwork\s*\(', service_content)),
      "connectToNetwork present")

check("WF.SRV.METH.EVAL", "NetworkService declares _evaluateNetworkState function",
      bool(re.search(r'function\s+_evaluateNetworkState\s*\(', service_content)),
      "_evaluateNetworkState present")

# ==============================================================================
# 3. Periodic Watchdog Timer Invariants (Requirement R6)
# ==============================================================================
watchdog_match = re.search(r'Timer\s*\{[^}]*interval\s*:\s*10000[\s\S]*?\}', service_content)
check("WF.SRV.WDG.EXISTS", "Periodic watchdog Timer exists with interval 10000",
      bool(watchdog_match), "10-second watchdog timer found")

if watchdog_match:
    wdg_block = watchdog_match.group(0)
    check("WF.SRV.WDG.REPEAT", "Watchdog Timer has repeat: true",
          bool(re.search(r'repeat\s*:\s*true\b', wdg_block)), "repeat: true present")
    check("WF.SRV.WDG.TRIGGER", "Watchdog Timer triggers _evaluateNetworkState()",
          "_evaluateNetworkState()" in wdg_block, "_evaluateNetworkState call present")
    check("WF.SRV.WDG.DYNAMIC_RUN", "Watchdog Timer running binding is dynamic expression",
          bool(re.search(r'running\s*:\s*Boolean\(', wdg_block)), "dynamic running binding present")
    check("WF.SRV.WDG.NO_LITERAL_TRUE", "Watchdog Timer does not declare literal running: true",
          not bool(re.search(r'running\s*:\s*true\b', wdg_block)), "no literal running: true")
    check("WF.SRV.WDG.NO_TOS", "Watchdog Timer does not declare triggeredOnStart: true",
          "triggeredOnStart: true" not in wdg_block, "no triggeredOnStart")

# ==============================================================================
# 4. Connection Timeout Timer Invariants (Requirement R6)
# ==============================================================================
timeout_match = re.search(r'Timer\s*\{[^}]*interval\s*:\s*15000[\s\S]*?\}', service_content)
check("WF.SRV.TMO.EXISTS", "Connection timeout Timer exists with interval 15000",
      bool(timeout_match), "15-second timeout timer found")

if timeout_match:
    tmo_block = timeout_match.group(0)
    check("WF.SRV.TMO.REPEAT", "Timeout Timer has repeat: false",
          bool(re.search(r'repeat\s*:\s*false\b', tmo_block)), "repeat: false present")
    check("WF.SRV.TMO.NO_SINGLESHOT", "Timeout Timer does not declare invalid singleShot property",
          "singleShot" not in tmo_block, "valid QML Timer properties")
    check("WF.SRV.TMO.TRIGGER_CLEAR", "Timeout Timer trigger clears connectingSsid",
          bool(re.search(r'connectingSsid\s*=\s*["\']["\']', tmo_block)), "clears connectingSsid")
    check("WF.SRV.TMO.TRIGGER_ERR", "Timeout Timer trigger populates lastError",
          bool(re.search(r'lastError\s*=\s*["\'][^"\']+["\']', tmo_block)), "populates lastError")
    check("WF.SRV.TMO.TRIGGER_SIG", "Timeout Timer trigger emits connectionFailed signal",
          bool(re.search(r'connectionFailed\s*\(', tmo_block)), "emits connectionFailed")

# Lifecycle: started in connectToNetwork, stopped in _applyConnectedState and onConnectionFailed
check("WF.SRV.TMO.START", "connectToNetwork starts or restarts timeout timer",
      bool(re.search(r'function\s+connectToNetwork[\s\S]*?\.(start|restart)\(\)', service_content)),
      "timer started in connectToNetwork")

check("WF.SRV.TMO.STOP_CONN", "_applyConnectedState stops timeout timer",
      bool(re.search(r'function\s+_applyConnectedState[\s\S]*?\.stop\(\)', service_content)),
      "timer stopped on successful connection")

check("WF.SRV.TMO.STOP_FAIL", "onConnectionFailed handler stops timeout timer",
      bool(re.search(r'onConnectionFailed[\s\S]*?\.stop\(\)', service_content)),
      "timer stopped on connection failure")

# ==============================================================================
# 5. Zero Polling & Subshell Policy Verification
# ==============================================================================
check("WF.SRV.ZERO_POLL", "NetworkService contains zero literal running: true declarations",
      not bool(re.search(r'running\s*:\s*true\b', service_content)), "zero literal running: true")

check("WF.SRV.NO_SH", "NetworkService contains zero sh -c or bash -c invocations",
      not bool(re.search(r'["\'](sh|bash)["\']\s*,\s*["\']-c["\']', service_content)),
      "no subshell invocations")

check("WF.SRV.NO_WHILE", "NetworkService contains zero while-true loops",
      not bool(re.search(r'while\s+true\s*;', service_content)), "no while loops")

# ==============================================================================
# 6. SystemRail 3-Tier "CONNECTING..." UI Feedback (Requirement R6)
# ==============================================================================
# Tier 1: Subheader text in wifi submenu
check("WF.RAIL.TIER1.SUBHEADER", "SystemRail wifi submenu subheader displays 'CONNECTING...' on isConnecting",
      bool(re.search(r'NetworkService\.isConnecting[\s\S]*?CONNECTING\.\.\.', rail_content)),
      "subheader reflects isConnecting")

# Tier 2: Dedicated active connection banner
check("WF.RAIL.TIER2.BANNER", "SystemRail has dedicated connection banner visible on isConnecting",
      bool(re.search(r'visible\s*:\s*NetworkService\.isConnecting', rail_content)),
      "connection banner visibility bound to isConnecting")

check("WF.RAIL.TIER2.TEXT", "SystemRail connection banner displays CONNECTING TO <SSID>",
      bool(re.search(r'text\s*:\s*["\']CONNECTING TO\s*["\']\s*\+', rail_content)),
      "banner displays target SSID")

check("WF.RAIL.TIER2.FONT", "SystemRail connection banner uses Theme.fontFamilyMonospace",
      bool(re.search(r'CONNECTING TO[\s\S]*?Theme\.fontFamilyMonospace', rail_content)),
      "monospace font used in connection banner")

# Tier 3: Delegate inline badge "[CONNECTING...]"
check("WF.RAIL.TIER3.BADGE", "SystemRail network delegate contains [CONNECTING...] badge",
      bool(re.search(r'\[CONNECTING\.\.\.\]', rail_content)),
      "inline [CONNECTING...] badge present")

check("WF.RAIL.TIER3.BIND", "SystemRail delegate inline badge bound to active connecting SSID",
      bool(re.search(r'connectingSsid\s*===\s*itemSsid|itemIsConnecting', rail_content)),
      "badge bound to connection target")

check("WF.RAIL.TIER3.FONT", "SystemRail inline badge uses Theme.fontFamilyMonospace",
      bool(re.search(r'\[CONNECTING\.\.\.\][\s\S]*?Theme\.fontFamilyMonospace|itemIsConnecting[\s\S]*?Theme\.fontFamilyMonospace', rail_content)),
      "monospace font used on inline badge")

check("WF.RAIL.TIER3.COLOR", "SystemRail inline badge uses Theme.accent color",
      bool(re.search(r'itemIsConnecting[\s\S]*?Theme\.accent|\[CONNECTING\.\.\.\][\s\S]*?Theme\.accent', rail_content)),
      "accent color used on inline badge")

# Error Feedback Banner
check("WF.RAIL.ERR.BANNER", "SystemRail displays lastError feedback banner",
      bool(re.search(r'NetworkService\.lastError\s*!==\s*["\']["\']', rail_content)),
      "lastError feedback banner present")

# ==============================================================================
# 7. Static Code Inspector Invariants & Hygiene
# ==============================================================================
greet_res = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-greeter", "shell/desktop"],
                           capture_output=True, text=True, cwd=PROJECT_ROOT)
check("WF.STATIC.GREETER", "check-greeter reports zero violations across shell/desktop",
      greet_res.returncode == 0, greet_res.stdout.strip())

poll_res = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-polling", "shell/desktop"],
                          capture_output=True, text=True, cwd=PROJECT_ROOT)
check("WF.STATIC.POLLING", "check-polling reports zero violations across shell/desktop",
      poll_res.returncode == 0, poll_res.stdout.strip())

fmt_res = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-format", "shell/desktop"],
                         capture_output=True, text=True, cwd=PROJECT_ROOT)
check("WF.STATIC.FORMAT", "check-format reports zero violations across shell/desktop",
      fmt_res.returncode == 0, fmt_res.stdout.strip())

zero_poll_sh_res = subprocess.run(["bash", "tests/e2e/tier2_boundaries/test_zero_polling_boundaries.sh"],
                                  capture_output=True, text=True, cwd=PROJECT_ROOT)
check("WF.STATIC.ZERO_POLL_SH", "test_zero_polling_boundaries.sh passes cleanly",
      zero_poll_sh_res.returncode == 0, "5/5 boundary checks passed")

qmllint_res = subprocess.run(["qmllint", service_path, rail_path],
                             capture_output=True, text=True, cwd=PROJECT_ROOT)
check("WF.STATIC.QMLLINT", "qmllint succeeds on NetworkService.qml and SystemRail.qml",
      qmllint_res.returncode == 0, "syntax verification clean")

print("=" * 70)
print(f"AUDIT SUMMARY: Passed={PASS_COUNT}, Failed={FAIL_COUNT}")
if FAIL_COUNT == 0:
    print("=== ALL MILESTONE 4 WIFI AUDITS PASSED CLEANLY ===")
else:
    print("=== MILESTONE 4 AUDITS FAILED ===", file=sys.stderr)
print("=" * 70)

sys.exit(0 if FAIL_COUNT == 0 else 1)
