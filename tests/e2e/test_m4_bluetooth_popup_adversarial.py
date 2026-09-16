#!/usr/bin/env python3
"""
Empirical Adversarial Stress & Edge Case Verification Suite for BluetoothPopup.qml
Milestone 4 - Requirements R1 & R3 Deep Adversarial Testing

Evaluates:
- Edge case 1 (Scale): 50 devices loaded, Flickable container bounds height to max 320px, clean scrolling without clipping.
- Edge case 2 (Extreme Strings): Device names with 100+ characters, elides cleanly with Text.ElideRight without button clipping or layout overflow.
- Edge case 3 (Untrusted Characters): Unicode, special symbols, newlines, and injection strings (<script>alert(1)</script>, $(reboot)).
- Edge case 4 (Action In-Flight Mutex): isActionPending displays [WAIT...] / [CONN...] / [PAIRING...] and prevents secondary dispatches.
- Edge case 5 (Rapid State Flapping): 100 rapid togglePower and toggleScan calls; state machine cleanly settles without locking.
- Edge case 6 (Radio Off Transition): Switch power off while scanning and with devices present; immediate transition to empty state.
- Edge case 7 (Click Shield): Clicks within popup bounds never trigger dismissals on the backdrop layer.
"""

import os
import re
import subprocess
import sys

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
QUICKSHELL_BIN = "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/bin/quickshell"
POPUP_QML = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/components/BluetoothPopup.qml")
SERVICE_QML = os.path.join(PROJECT_ROOT, "shell/desktop/services/BluetoothService.qml")
ADVERSARIAL_HARNESS_QML = os.path.join(PROJECT_ROOT, "tests/e2e/harness/test_m4_bluetooth_popup_adversarial.qml")

passed = 0
failed = 0


def assert_check(id_str, desc, condition, details=""):
    global passed, failed
    if condition:
        passed += 1
        print(f"[PASS] {id_str}: {desc}" + (f" ({details})" if details else ""))
    else:
        failed += 1
        print(f"[FAIL] {id_str}: {desc}" + (f" ({details})" if details else ""), file=sys.stderr)


def test_static_ast_adversarial_invariants():
    print("================================================================================")
    print("=== PART 1: STATIC AST & TOKEN ADVERSARIAL INVARIANT AUDIT ====================")
    print("================================================================================")

    with open(POPUP_QML, "r", encoding="utf-8") as f:
        popup_src = f.read()

    with open(SERVICE_QML, "r", encoding="utf-8") as f:
        service_src = f.read()

    # Edge Case 1: Scale bounds invariants
    assert_check("ADV.STAT.SCALE.01", "Flickable container height capped via Math.min(320, ...)",
                 "Math.min(320" in popup_src, "found Math.min(320 in BluetoothPopup.qml")

    assert_check("ADV.STAT.SCALE.02", "Flickable declares boundsBehavior: Flickable.StopAtBounds",
                 "boundsBehavior: Flickable.StopAtBounds" in popup_src, "StopAtBounds declared")

    assert_check("ADV.STAT.SCALE.03", "Flickable declares clip: true",
                 "clip: true" in popup_src, "clip: true declared")

    # Edge Case 2: Extreme string length invariants
    elide_matches = re.findall(r"elide:\s*Text\.ElideRight", popup_src)
    assert_check("ADV.STAT.STR.01", "Text elements use Text.ElideRight for safe label elision",
                 len(elide_matches) >= 4, f"found {len(elide_matches)} elide declarations")

    # Edge Case 3: Untrusted character & injection defense invariants
    assert_check("ADV.STAT.INJ.01", "BluetoothService sanitizes ASCII control characters and newlines",
                 r"/[\x00-\x1F\x7F]/g" in service_src, "control characters regex present")

    assert_check("ADV.STAT.INJ.02", "BluetoothService enforces strict MAC regex validation guard",
                 r"/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/i" in service_src, "MAC address regex validation present")

    assert_check("ADV.STAT.INJ.03", "BluetoothPopup declares zero raw eval or shell executions",
                 "eval(" not in popup_src and "sh -c" not in popup_src and "bash -c" not in popup_src,
                 "zero eval or subshell invocations")

    # Edge Case 4: Action in-flight mutex invariants
    assert_check("ADV.STAT.MUTEX.01", "MouseArea actions guarded by !BluetoothService.isActionPending",
                 "enabled: !BluetoothService.isActionPending" in popup_src, "isActionPending guard present")

    assert_check("ADV.STAT.MUTEX.02", "UI declares in-flight state text [WAIT...]",
                 "[WAIT...]" in popup_src, "[WAIT...] present")

    assert_check("ADV.STAT.MUTEX.03", "UI declares in-flight state text [CONN...]",
                 "[CONN...]" in popup_src, "[CONN...] present")

    assert_check("ADV.STAT.MUTEX.04", "UI declares in-flight state text [PAIRING...]",
                 "[PAIRING...]" in popup_src, "[PAIRING...] present")

    # Edge Case 5: State flapping invariants
    assert_check("ADV.STAT.FLAP.01", "togglePower has running guard on powerProcess",
                 "if (powerProcess.running" in service_src, "powerProcess.running guard present")

    assert_check("ADV.STAT.FLAP.02", "toggleScan has running guard on scanProcess",
                 "if (root._isScanning || scanProcess.running)" in service_src, "scanProcess.running guard present")

    # Edge Case 6: Radio off transition invariants
    assert_check("ADV.STAT.RADIO.01", "Empty state for radio off bound to !BluetoothService.powered",
                 "visible: !BluetoothService.powered" in popup_src, "radio off empty state present")

    assert_check("ADV.STAT.RADIO.02", "Device flickable hidden when radio is off",
                 "BluetoothService.powered && devCount > 0" in popup_src, "flickable visibility guarded by powered")

    # Edge Case 7: Click shield invariants
    assert_check("ADV.STAT.SHIELD.01", "Root shield MouseArea present with anchors.fill: parent",
                 re.search(r"MouseArea\s*\{[\s\S]*?anchors\.fill:\s*parent[\s\S]*?preventStealing:\s*true", popup_src) is not None,
                 "preventStealing shield present")

    assert_check("ADV.STAT.SHIELD.02", "Root shield swallows click events with accepted = true",
                 "mouse.accepted = true" in popup_src, "mouse.accepted = true declared")


def test_qmllint():
    print("================================================================================")
    print("=== PART 2: QMLLINT VALIDATION ================================================")
    print("================================================================================")

    cmd = [
        "qmllint",
        "-I", os.path.join(PROJECT_ROOT, "shell/desktop"),
        POPUP_QML,
        ADVERSARIAL_HARNESS_QML
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    assert_check("ADV.LINT.01", "qmllint checks pass cleanly on BluetoothPopup and adversarial harness",
                 res.returncode == 0, f"exitCode={res.returncode}")


def test_quickshell_adversarial_runtime():
    print("================================================================================")
    print("=== PART 3: QUICKSHELL HEADLESS ADVERSARIAL RUNTIME EXECUTION =================")
    print("================================================================================")

    env = os.environ.copy()
    env["CTOS_SETTINGS_PATH"] = "/tmp/ctos_test_settings.json"
    env["QML_IMPORT_PATH"] = os.path.join(PROJECT_ROOT, "shell")

    cmd = [
        "timeout", "10",
        QUICKSHELL_BIN,
        "-p", ADVERSARIAL_HARNESS_QML
    ]

    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)
    output = res.stdout + "\n" + res.stderr

    assert_check("ADV.RUN.CODE.01", "Quickshell harness exits with return code 0",
                 res.returncode == 0, f"returncode={res.returncode}")

    summary_match = re.search(r"ADVERSARIAL SUITE SUMMARY:\s*Passed=(\d+),\s*Failed=(\d+)", output)
    if summary_match:
        run_passed = int(summary_match.group(1))
        run_failed = int(summary_match.group(2))
        assert_check("ADV.RUN.SUMMARY.01", f"Adversarial runtime summary reports zero failures (Passed={run_passed}, Failed={run_failed})",
                     run_passed >= 60 and run_failed == 0, f"Passed={run_passed}, Failed={run_failed}")
    else:
        assert_check("ADV.RUN.SUMMARY.01", "Adversarial runtime summary parsed successfully",
                     False, "Summary line not found in output")

    assert_check("ADV.RUN.VERDICT.01", "Adversarial suite reports all 7 edge cases verified cleanly",
                 "PASS: ALL 7 EDGE CASES VERIFIED EMPIRICALLY WITH ZERO DEFECTS" in output,
                 "verdict verified in log")


def main():
    test_static_ast_adversarial_invariants()
    test_qmllint()
    test_quickshell_adversarial_runtime()

    print("================================================================================")
    print(f"ADVERSARIAL RUNNER SUMMARY: Passed={passed}, Failed={failed}")
    if failed == 0:
        print("=== ALL ADVERSARIAL TESTS & RUNTIME VERIFICATIONS PASSED CLEANLY ===")
    else:
        print("=== ADVERSARIAL FAILURES DETECTED ===", file=sys.stderr)
    print("================================================================================")
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
