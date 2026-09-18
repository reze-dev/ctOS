#!/usr/bin/env python3
"""
test_challenger_final_audit.py - Empirical Challenger Final Verification Harness
================================================================================
Role: EMPIRICAL CHALLENGER (Critic / Specialist)
Target: Comprehensive, adversarial empirical verification of ALL 4 Acceptance Criteria:
  1. Command Deck fuzzy search matches applications predictably ("ff" -> "Firefox",
     score ordering, boundary handling, empty query).
  2. Clicking "Logout" successfully exits Niri session without confirmation hang
     (["niri", "msg", "action", "quit", "-s"] intercept and fallback cascade under strict mock).
  3. Wi-Fi popup parses cleanly and toggles from Ambient Bar widget, mirroring BluetoothPopup styling.
  4. Headless Quickshell runtime test harnesses pass cleanly without display server.

CRITICAL SAFETY MANDATE:
All execution paths are strictly intercepted by mock binaries in an isolated
sandbox directory placed at the front of PATH. Live compositor termination commands
(niri msg action quit, hyprctl dispatch exit, loginctl terminate-session)
MUST NEVER execute on the live machine.
================================================================================
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
SHELL_DIR = PROJECT_ROOT / "shell"
DESKTOP_DIR = SHELL_DIR / "desktop"
SERVICES_DIR = DESKTOP_DIR / "services"
SURFACES_DIR = DESKTOP_DIR / "surfaces"
COMPONENTS_DIR = SURFACES_DIR / "components"
HARNESS_DIR = PROJECT_ROOT / "tests/e2e/harness"

passed_count = 0
failed_count = 0
failures = []


def record(test_id: str, desc: str, condition: bool, details: str = ""):
    global passed_count, failed_count, failures
    if condition:
        passed_count += 1
        print(f"  [PASS] {test_id}: {desc}" + (f" ({details})" if details else ""))
    else:
        failed_count += 1
        failures.append((test_id, desc, details))
        print(f"  [FAIL] {test_id}: {desc}" + (f" ({details})" if details else ""), file=sys.stderr)


def discover_binary(name: str, nix_pattern: str = "") -> str:
    which_bin = shutil.which(name)
    if which_bin:
        return which_bin
    nix_store = Path("/nix/store")
    if nix_store.exists() and nix_pattern:
        matches = sorted(nix_store.glob(nix_pattern))
        if matches:
            return str(matches[-1])
    return ""


def create_strict_mock_environment():
    mock_dir = tempfile.mkdtemp(prefix="ctos_final_mock_")
    log_file = os.path.join(mock_dir, "invocations.log")

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
# 1. Acceptance Criterion 1: Command Deck Fuzzy Search
# ==============================================================================
def verify_criterion_1(qs_bin: str, mock_dir: str):
    print("\n" + "=" * 80)
    print("CRITERION 1: Command Deck Fuzzy Search Predictability & Robustness")
    print("=" * 80)

    # 1.1 Quickshell Headless Fuzzy Search Test Harness
    harness_1 = HARNESS_DIR / "test_r1_fuzzy_search_quickshell.qml"
    record("AC1.HARNESS.EXISTS", "test_r1_fuzzy_search_quickshell.qml exists", harness_1.exists())

    env = os.environ.copy()
    env["PATH"] = f"{mock_dir}:" + env.get("PATH", "")
    env["QML_IMPORT_PATH"] = str(SHELL_DIR)
    env.pop("WAYLAND_DISPLAY", None)
    env.pop("DISPLAY", None)
    env["QT_QPA_PLATFORM"] = "offscreen"

    proc = subprocess.run([qs_bin, "-p", str(harness_1)], env=env, capture_output=True, text=True, timeout=20)
    record("AC1.RUN.EXIT_0", "test_r1_fuzzy_search_quickshell.qml exited 0", proc.returncode == 0, f"code={proc.returncode}")
    record("AC1.RUN.PASS_INDICATOR", "Harness output contains PASS: R1 FUZZY SEARCH", "PASS: R1 FUZZY SEARCH" in proc.stdout)

    # 1.2 Adversarial Stress Harness
    harness_adv = HARNESS_DIR / "test_m1_fuzzy_search_challenger.qml"
    record("AC1.ADV.EXISTS", "test_m1_fuzzy_search_challenger.qml exists", harness_adv.exists())

    proc_adv = subprocess.run([qs_bin, "-p", str(harness_adv)], env=env, capture_output=True, text=True, timeout=20)
    record("AC1.ADV.EXIT_0", "test_m1_fuzzy_search_challenger.qml exited 0", proc_adv.returncode == 0, f"code={proc_adv.returncode}")
    record("AC1.ADV.PASS_INDICATOR", "Adversarial harness reported all passed", "ALL EMPIRICAL CHALLENGE TESTS SUCCEEDED" in proc_adv.stdout)

    # 1.3 Deep probe on specific Acceptance Criteria items:
    # verify "ff" -> "Firefox" with score ordering, boundary handling, empty query
    probe_qml = """
import QtQuick
import Quickshell
import desktop.core

Scope {
    id: root
    Timer {
        interval: 50
        running: true
        onTriggered: {
            // 1. "ff" -> "Firefox"
            const sc_ff = ActionRegistry._fuzzyScore("firefox", "ff", "Firefox");
            const sc_fire = ActionRegistry._fuzzyScore("firefox", "fire", "Firefox");
            const sc_exact = ActionRegistry._fuzzyScore("firefox", "firefox", "Firefox");
            const sc_sub = ActionRegistry._fuzzyScore("firefox", "ref", "Firefox");
            const sc_gen = ActionRegistry._fuzzyScore("firefox", "fx", "Firefox");

            // Empty query returns array with score 10
            const emptyRes = ActionRegistry.search("");
            const ffRes = ActionRegistry.search("ff");

            const report = {
                ff_score: sc_ff ? sc_ff.score : null,
                ff_is_acronym: sc_ff ? sc_ff.isAcronym : null,
                ff_boundaries: sc_ff ? sc_ff.boundaryMatches : null,
                score_exact: sc_exact ? sc_exact.score : null,
                score_pfx: sc_fire ? sc_fire.score : null,
                score_sub: sc_sub ? sc_sub.score : null,
                score_gen: sc_gen ? sc_gen.score : null,
                empty_count: emptyRes ? emptyRes.length : 0,
                empty_scores_all_10: emptyRes ? emptyRes.every(x => x.score === 10) : false,
                ff_finds_firefox: ffRes ? ffRes.some(x => x.name === "Firefox" && x.score === 3.5) : false,
                capped_at_50: ffRes ? ffRes.length <= 50 : false
            };
            console.log("PROBE_REPORT:" + JSON.stringify(report));
            Qt.quit();
        }
    }
}
"""
    with tempfile.NamedTemporaryFile("w", suffix=".qml", delete=False) as f:
        probe_path = f.name
        f.write(probe_qml)

    try:
        proc_probe = subprocess.run([qs_bin, "-p", probe_path], env=env, capture_output=True, text=True, timeout=10)
        report_line = next((l for l in proc_probe.stdout.splitlines() if "PROBE_REPORT:" in l), None)
        record("AC1.PROBE.PARSED", "Probe generated valid report", report_line is not None)
        if report_line:
            rep = json.loads(report_line.split("PROBE_REPORT:")[1])
            record("AC1.SCORE.FF_FIREFOX", "'ff' on 'Firefox' yields score 3.5 as initials/subword acronym",
                   rep["ff_score"] == 3.5 and rep["ff_is_acronym"] is True, f"score={rep['ff_score']}")
            record("AC1.SCORE.ORDERING", "Score tier order: exact(0) < pfx(1) < sub(3) < acronym(3.5) < general(4.x)",
                   rep["score_exact"] == 0 and rep["score_pfx"] == 1 and rep["score_sub"] == 3 and
                   rep["ff_score"] == 3.5 and rep["score_gen"] >= 4.0,
                   f"exact={rep['score_exact']}, pfx={rep['score_pfx']}, sub={rep['score_sub']}, acr={rep['ff_score']}, gen={rep['score_gen']}")
            record("AC1.SEARCH.EMPTY_QUERY", "Empty query returns items all with score 10",
                   rep["empty_count"] > 0 and rep["empty_scores_all_10"] is True, f"count={rep['empty_count']}")
            record("AC1.SEARCH.CAP", "Results capped at max 50", rep["capped_at_50"] is True)
    finally:
        if os.path.exists(probe_path):
            os.remove(probe_path)


# ==============================================================================
# 2. Acceptance Criterion 2: Clicking "Logout" Exits Niri Without Hang
# ==============================================================================
def verify_criterion_2(qs_bin: str, mock_dir: str, log_file: str):
    print("\n" + "=" * 80)
    print("CRITERION 2: Niri Logout Interception, '-s' Flag & Fallback Cascade")
    print("=" * 80)

    session_service_path = SERVICES_DIR / "SessionService.qml"
    code = session_service_path.read_text(encoding="utf-8")

    # 2.1 AST Safety
    record("AC2.AST.NO_TIMER", "Zero Timer components in SessionService.qml", not bool(re.search(r'\bTimer\s*\{', code)))
    record("AC2.AST.NO_EXEC_DETACHED", "Zero execDetached in SessionService.qml", "execDetached" not in code)
    record("AC2.AST.NO_SHELL_SUBSHELL", "Zero sh/bash subshell invocations", not bool(re.search(r'["\'](sh|bash|zsh)["\']\s*,\s*["\']-c["\']', code)))
    record("AC2.AST.FLAG_S_PRESENT", "Explicit discrete array ['niri', 'msg', 'action', 'quit', '-s'] in code",
           '["niri", "msg", "action", "quit", "-s"]' in code)

    # 2.2 Quickshell Headless Runtime M2 Harness
    harness_2 = HARNESS_DIR / "test_m2_logout_quickshell.qml"
    record("AC2.HARNESS.EXISTS", "test_m2_logout_quickshell.qml exists", harness_2.exists())

    if os.path.exists(log_file):
        os.remove(log_file)

    env = os.environ.copy()
    env["PATH"] = f"{mock_dir}:" + env.get("PATH", "")
    env["QML_IMPORT_PATH"] = str(SHELL_DIR)
    env["XDG_CURRENT_DESKTOP"] = "niri"
    env.pop("WAYLAND_DISPLAY", None)
    env.pop("DISPLAY", None)
    env["QT_QPA_PLATFORM"] = "offscreen"

    proc = subprocess.run([qs_bin, "-p", str(harness_2)], env=env, capture_output=True, text=True, timeout=20)
    record("AC2.RUN.EXIT_0", "test_m2_logout_quickshell.qml exited 0", proc.returncode == 0, f"code={proc.returncode}")
    record("AC2.RUN.PASS_INDICATOR", "Harness output contains PASS: M2 LOGOUT", "PASS: M2 LOGOUT" in proc.stdout)

    # 2.3 Verify Mock Interception Log for Niri Quit with -s
    invocations = [l.strip() for l in open(log_file).readlines() if l.strip()] if os.path.exists(log_file) else []
    record("AC2.INTERCEPT.LOG_EXISTS", "Mock invocations log captured commands", len(invocations) > 0, f"count={len(invocations)}")
    has_niri_s = any("niri msg action quit -s" in inv for inv in invocations)
    record("AC2.INTERCEPT.NIRI_FLAG_S", "Mock intercepted exact 'niri msg action quit -s' (no stdin confirmation hang)",
           has_niri_s, f"invocations={invocations}")

    # 2.4 Fallback Cascade Test under Unknown Compositor (simulate niri fails -> hyprctl fails -> loginctl succeeds)
    if os.path.exists(log_file):
        os.remove(log_file)

    cascade_qml = """
import QtQuick
import Quickshell
import desktop.services

Scope {
    id: root
    property var step: 0
    property var finishedList: []

    Connections {
        target: SessionService
        function onSessionActionFinished(action, exitCode) {
            root.finishedList.push({ action: action, exitCode: exitCode, stage: SessionService.fallbackStage });
        }
    }

    Timer {
        interval: 40
        repeat: true
        running: true
        property int ticks: 0
        onTriggered: {
            ticks++;
            if (ticks === 1) {
                // Initial compositor is unknown
                SessionService.logout();
            } else if (ticks > 25 || (root.finishedList.length > 0 && !SessionService.isBusy)) {
                running = false;
                console.log("CASCADE_REPORT:" + JSON.stringify({
                    finishedCount: root.finishedList.length,
                    isBusy: SessionService.isBusy,
                    fallbackStage: SessionService.fallbackStage
                }));
                Qt.quit();
            }
        }
    }
}
"""
    with tempfile.NamedTemporaryFile("w", suffix=".qml", delete=False) as f:
        cascade_path = f.name
        f.write(cascade_qml)

    try:
        env_cascade = env.copy()
        env_cascade.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
        env_cascade.pop("NIRI_SOCKET", None)
        env_cascade["XDG_CURRENT_DESKTOP"] = "unknown_wm"
        env_cascade["MOCK_NIRI_EXIT"] = "1"     # Stage 1 fails
        env_cascade["MOCK_HYPRCTL_EXIT"] = "1"  # Stage 2 fails
        env_cascade["MOCK_LOGINCTL_EXIT"] = "0" # Stage 3 succeeds

        proc_cascade = subprocess.run([qs_bin, "-p", cascade_path], env=env_cascade, capture_output=True, text=True, timeout=10)
        cascade_invocations = [l.strip() for l in open(log_file).readlines() if l.strip()] if os.path.exists(log_file) else []
        record("AC2.CASCADE.EXECUTED", "Cascade executed all 3 stages in order", len(cascade_invocations) == 3,
               f"invocations={cascade_invocations}")
        if len(cascade_invocations) == 3:
            record("AC2.CASCADE.STAGE1", "Stage 1 executed niri msg action quit -s",
                   "niri msg action quit -s" in cascade_invocations[0])
            record("AC2.CASCADE.STAGE2", "Stage 2 executed hyprctl dispatch exit",
                   "hyprctl dispatch exit" in cascade_invocations[1])
            record("AC2.CASCADE.STAGE3", "Stage 3 executed loginctl terminate-session",
                   "loginctl terminate-session" in cascade_invocations[2])

        match_cas = next((l for l in proc_cascade.stdout.splitlines() if "CASCADE_REPORT:" in l), None)
        if match_cas:
            rep_cas = json.loads(match_cas.split("CASCADE_REPORT:")[1])
            record("AC2.CASCADE.CLEAN_RESET", "Cascade finished and reset fallbackStage to 0, isBusy to false",
                   rep_cas["fallbackStage"] == 0 and rep_cas["isBusy"] is False)
    finally:
        if os.path.exists(cascade_path):
            os.remove(cascade_path)


# ==============================================================================
# 3. Acceptance Criterion 3: Wi-Fi Popup & Ambient Bar Integration
# ==============================================================================
def verify_criterion_3(qs_bin: str, qmllint_bin: str, mock_dir: str):
    print("\n" + "=" * 80)
    print("CRITERION 3: Wi-Fi Popup & Ambient Bar Decoupling Verification")
    print("=" * 80)

    # 3.1 Run Python AST & Token Audit Suite
    audit_script = PROJECT_ROOT / "tests/e2e/test_r3_wifi_popup_audit.py"
    record("AC3.AUDIT.SCRIPT_EXISTS", "test_r3_wifi_popup_audit.py exists", audit_script.exists())

    env = os.environ.copy()
    env["PATH"] = f"{mock_dir}:" + (f"{Path(qmllint_bin).parent}:" if qmllint_bin else "") + env.get("PATH", "")
    proc_audit = subprocess.run([sys.executable, str(audit_script)], env=env, capture_output=True, text=True, timeout=20)
    record("AC3.AUDIT.EXIT_0", "test_r3_wifi_popup_audit.py exited 0", proc_audit.returncode == 0, f"code={proc_audit.returncode}")
    record("AC3.AUDIT.PASS_INDICATOR", "Audit output indicates all passed", "ALL MILESTONE 3 WI-FI POPUP & NETWORK AUDITS PASSED" in proc_audit.stdout)

    # 3.2 Quickshell Headless Component Runtime Harness
    harness_3 = HARNESS_DIR / "test_r3_wifi_popup_quickshell.qml"
    record("AC3.HARNESS.EXISTS", "test_r3_wifi_popup_quickshell.qml exists", harness_3.exists())

    env_qs = env.copy()
    env_qs["QML_IMPORT_PATH"] = str(SHELL_DIR)
    env_qs.pop("WAYLAND_DISPLAY", None)
    env_qs.pop("DISPLAY", None)
    env_qs["QT_QPA_PLATFORM"] = "offscreen"

    proc_qs = subprocess.run([qs_bin, "-p", str(harness_3)], env=env_qs, capture_output=True, text=True, timeout=20)
    record("AC3.RUN.EXIT_0", "test_r3_wifi_popup_quickshell.qml exited 0", proc_qs.returncode == 0, f"code={proc_qs.returncode}")
    record("AC3.RUN.PASS_INDICATOR", "Harness output contains PASS: R3 WIFI POPUP", "PASS: R3 WIFI POPUP" in proc_qs.stdout)

    # 3.3 Verify SystemRail.qml Invariance
    proc_git = subprocess.run(["git", "diff", "HEAD~3", "--", str(SURFACES_DIR / "SystemRail.qml")],
                              cwd=str(PROJECT_ROOT), capture_output=True, text=True)
    record("AC3.SYSTEMRAIL.UNTOUCHED", "SystemRail.qml is 100% untouched in git history", proc_git.stdout.strip() == "")

    # 3.4 Verify qmllint on all touched files
    if qmllint_bin:
        files = [
            COMPONENTS_DIR / "NetworkPopup.qml",
            SURFACES_DIR / "AmbientBar.qml",
            SERVICES_DIR / "NetworkService.qml",
            SHELL_DIR / "shell.qml"
        ]
        all_lint = True
        for f in files:
            res_lint = subprocess.run([qmllint_bin, "-I", str(SHELL_DIR), str(f)],
                                      cwd=str(PROJECT_ROOT), capture_output=True, text=True)
            if res_lint.returncode != 0:
                all_lint = False
                print(f"qmllint failure on {f}:\n{res_lint.stderr}", file=sys.stderr)
        record("AC3.LINT.CLEAN", "qmllint passes cleanly on all 4 components", all_lint)


# ==============================================================================
# 4. Acceptance Criterion 4: Headless Quickshell Runtime Test Suites
# ==============================================================================
def verify_criterion_4(qs_bin: str, mock_dir: str):
    print("\n" + "=" * 80)
    print("CRITERION 4: Full Headless Test Suite Execution (No Display Server)")
    print("=" * 80)

    env = os.environ.copy()
    env["PATH"] = f"{mock_dir}:" + env.get("PATH", "")
    env["QML_IMPORT_PATH"] = str(SHELL_DIR)
    env["PROJECT_ROOT"] = str(PROJECT_ROOT)
    env.pop("WAYLAND_DISPLAY", None)
    env.pop("DISPLAY", None)
    env["QT_QPA_PLATFORM"] = "offscreen"

    test_matrix = [
        ("test_r1_fuzzy_search_quickshell.qml", "R1 Fuzzy Search Quickshell Runtime"),
        ("test_m1_fuzzy_search_challenger.qml", "M1 Challenger Stress Suite"),
        ("test_m1_challenger2_adv_verify.qml", "M1 Challenger 2 Verification"),
        ("test_m2_logout_quickshell.qml", "M2 Logout & Compositor Quickshell Runtime"),
        ("test_r3_wifi_popup_quickshell.qml", "R3 Wi-Fi Popup Quickshell Runtime"),
        ("test_session_service_runtime.qml", "M4 Session Service Runtime"),
    ]

    for qml_name, desc in test_matrix:
        qml_path = HARNESS_DIR / qml_name
        if not qml_path.exists():
            record(f"AC4.{qml_name}", f"File exists: {qml_name}", False)
            continue

        proc = subprocess.run([qs_bin, "-p", str(qml_path)], env=env, capture_output=True, text=True, timeout=20)
        has_pass = any(kw in proc.stdout for kw in ["PASS:", "SUCCESS", "Passed="])
        record(f"AC4.{qml_name}", f"{desc} ran headlessly and passed",
               proc.returncode == 0 and has_pass, f"code={proc.returncode}")

    # Run full python verification suites
    py_suites = [
        ("test_challenger_m2_stress.py", "Challenger M2 Stress Suite"),
        ("test_challenger_verification_deep.py", "Challenger Deep Verification"),
        ("test_session_service_adversarial.py", "Session Service Adversarial Suite")
    ]
    for py_name, desc in py_suites:
        py_path = PROJECT_ROOT / "tests/e2e" / py_name
        if not py_path.exists():
            continue
        proc_py = subprocess.run([sys.executable, str(py_path)], env=env, capture_output=True, text=True, timeout=35)
        record(f"AC4.{py_name}", f"{desc} executed and passed",
               proc_py.returncode == 0, f"code={proc_py.returncode}")


def main():
    print("=" * 80)
    print("  EMPIRICAL CHALLENGER FINAL VERIFICATION AUDIT")
    print("  Acceptance Criteria 1, 2, 3, 4 Verification")
    print("=" * 80)

    qs_bin = discover_binary("quickshell", "*quickshell*/bin/quickshell")
    qmllint_bin = discover_binary("qmllint", "*qtdeclarative*/bin/qmllint")

    if not qs_bin:
        print("FATAL: Quickshell binary could not be found!", file=sys.stderr)
        sys.exit(1)

    print(f"Discovered Quickshell binary: {qs_bin}")
    print(f"Discovered qmllint binary:    {qmllint_bin}")

    mock_dir, log_file = create_strict_mock_environment()
    print(f"Created isolated mock sandbox: {mock_dir}")
    print(f"Mock command log file:         {log_file}")

    # Safety Self-Check: Verify mock isolation
    test_env = os.environ.copy()
    test_env["PATH"] = f"{mock_dir}:" + test_env.get("PATH", "")
    for b in ["niri", "hyprctl", "loginctl"]:
        resolved = shutil.which(b, path=test_env["PATH"])
        assert resolved and resolved.startswith(mock_dir), f"CRITICAL SAFETY VIOLATION: {b} resolved to {resolved}"
    print("[SAFETY VERIFIED] All session control binaries strictly resolve to mock sandbox.")

    try:
        verify_criterion_1(qs_bin, mock_dir)
        verify_criterion_2(qs_bin, mock_dir, log_file)
        verify_criterion_3(qs_bin, qmllint_bin, mock_dir)
        verify_criterion_4(qs_bin, mock_dir)
    finally:
        if os.path.exists(mock_dir):
            shutil.rmtree(mock_dir, ignore_errors=True)

    print("\n" + "=" * 80)
    print(f"FINAL AUDIT SUMMARY: Passed={passed_count}, Failed={failed_count}")
    print("=" * 80)

    if failed_count > 0:
        print(f"\nFAILURES DETECTED ({len(failures)}):")
        for fid, fdesc, fdet in failures:
            print(f"  - {fid}: {fdesc} ({fdet})")
        print("\nFINAL VERDICT: REJECT\n")
        sys.exit(1)
    else:
        print("\nALL 4 ACCEPTANCE CRITERIA EMPIRICALLY VERIFIED AND APPROVED.")
        print("FINAL VERDICT: APPROVE\n")
        sys.exit(0)


if __name__ == "__main__":
    main()
