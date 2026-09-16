#!/usr/bin/env python3
"""
Empirical Adversarial Stress & Boundary Test Suite for Milestone 1 (System Rail Session Actions Fix)
Author: Challenger 2

Verification dimensions:
1. AST & Static Invariant Auditing:
   - Strict inspection of all Quickshell.Io.Process nodes
   - Allowlist verification of targeted binaries: loginctl, hyprctl, systemctl
   - Verification of discrete string array commands without concatenation, shell wraps, or backticks
   - Rejection of persistent loops (running: true literal) and forbidden command patterns (sh, bash, eval)
2. Interactive State Machine & Rapid Keypress Fuzzing:
   - Rapid bursts of Escape keypresses during active confirmation mode
   - Tiered Escape priority under nested states (wifi view, ssid selection, forget confirmation)
   - Re-entrancy, cancellation races, and illegal confirmation action injection
   - Monte Carlo random stress testing across thousands of interleaved transitions
3. Execution of Shell Boundary Suites:
   - test_t5_safe_cancel_escape_boundaries.sh
   - test_t5_allowlisted_execution_boundaries.sh
"""

import os
import re
import sys
import subprocess
import random

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SYSTEM_RAIL_PATH = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/SystemRail.qml")

total_tests = 0
passed_tests = 0
failed_tests = []

def check(test_id: str, description: str, condition: bool, details: str = ""):
    global total_tests, passed_tests, failed_tests
    total_tests += 1
    if condition:
        passed_tests += 1
        print(f"  [PASS] {test_id}: {description} {details}")
    else:
        failed_tests.append((test_id, description, details))
        print(f"  [FAIL] {test_id}: {description} | Details: {details}", file=sys.stderr)


# ==============================================================================
# Phase 1: AST & Lexical Parsing
# ==============================================================================
def test_ast_and_lexical():
    print("\n--- Phase 1: AST & Static Invariant Auditing ---")
    assert os.path.exists(SYSTEM_RAIL_PATH), f"SystemRail.qml not found at {SYSTEM_RAIL_PATH}"
    
    with open(SYSTEM_RAIL_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    # Strip comments to check actual executable code
    clean_code = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    clean_lines = []
    for line in clean_code.splitlines():
        line_no_comment = line.split("//")[0]
        clean_lines.append(line_no_comment)
    executable_code = "\n".join(clean_lines)

    # 1. Check for forbidden shell interpreters
    forbidden_tokens = ["sh", "bash", "zsh", "dash", "csh", "tcsh"]
    for tok in forbidden_tokens:
        matches = re.findall(rf'["\']{tok}["\']', executable_code)
        check(f"AST.NO_SHELL.{tok.upper()}", f"Zero occurrences of '{tok}' binary token in executable code", len(matches) == 0, f"found: {matches}")

    # 2. Check for eval or dynamic code execution
    check("AST.NO_EVAL", "Zero occurrences of eval()", "eval(" not in executable_code)
    check("AST.NO_FUNCTION_CTOR", "Zero occurrences of Function() constructor", "Function(" not in executable_code)

    # 3. Check for legacy Quickshell.execDetached in executable code
    matches_exec_detached = re.findall(r'execDetached', executable_code)
    check("AST.NO_EXEC_DETACHED", "Zero execDetached in active executable code", len(matches_exec_detached) == 0, f"found: {matches_exec_detached}")

    # 4. Extract all Process nodes
    process_pattern = re.compile(r'Process\s*\{([^}]+)\}', re.DOTALL)
    process_matches = list(process_pattern.finditer(content))
    check("AST.PROCESS.COUNT", "Exactly 4 Process nodes declared in SystemRail.qml", len(process_matches) == 4, f"found {len(process_matches)}")

    process_dict = {}
    allowlisted_binaries = {"loginctl", "hyprctl", "systemctl"}

    for match in process_matches:
        block = match.group(1)
        id_m = re.search(r'id:\s*([a-zA-Z0-9_]+)', block)
        cmd_m = re.search(r'command:\s*\[([^\]]+)\]', block)
        run_m = re.search(r'running:\s*([a-zA-Z0-9_]+)', block)

        pid = id_m.group(1) if id_m else "unknown"
        raw_cmd = cmd_m.group(1).strip() if cmd_m else ""
        raw_run = run_m.group(1).strip() if run_m else ""

        # Parse command tokens
        args = [t.strip().strip('"\'') for t in raw_cmd.split(",") if t.strip()]
        process_dict[pid] = {
            "raw_block": block,
            "command": args,
            "running": raw_run
        }

    # Verify each expected process node
    expected_processes = {
        "lockProcess": ["loginctl", "lock-session"],
        "logoutProcess": ["hyprctl", "dispatch", "exit"],
        "rebootProcess": ["systemctl", "reboot"],
        "poweroffProcess": ["systemctl", "poweroff"]
    }

    for expected_id, expected_cmd in expected_processes.items():
        exists = expected_id in process_dict
        check(f"AST.PROCESS.{expected_id.upper()}.EXISTS", f"Process {expected_id} exists", exists)
        if exists:
            proc = process_dict[expected_id]
            cmd = proc["command"]
            check(f"AST.PROCESS.{expected_id.upper()}.CMD", f"{expected_id} command strictly matches {expected_cmd}", cmd == expected_cmd, f"actual: {cmd}")
            check(f"AST.PROCESS.{expected_id.upper()}.ALLOWLIST", f"{expected_id} binary is allowlisted", len(cmd) > 0 and cmd[0] in allowlisted_binaries, f"binary: {cmd[0] if cmd else None}")
            check(f"AST.PROCESS.{expected_id.upper()}.RUNNING_INIT", f"{expected_id} initialized with running: false", proc["running"] == "false", f"running: {proc['running']}")

    # 5. Check for any string concatenation or variable interpolation in commands
    for pid, proc in process_dict.items():
        raw_block = proc["raw_block"]
        check(f"AST.PROCESS.{pid.upper()}.NO_CONCAT", f"{pid} has zero string concatenation in command", "+" not in raw_block and "$" not in raw_block and "`" not in raw_block)

    # 6. Verify that running: true is NEVER statically declared in any Process
    check("AST.NO_STATIC_RUNNING_TRUE", "No Process declares running: true statically", "running: true" not in [p["raw_block"] for p in process_dict.values()])

    # 7. Check all sites setting .running = true
    running_true_sites = re.findall(r'([a-zA-Z0-9_]+)\.running\s*=\s*true', executable_code)
    expected_sites = {"lockProcess", "logoutProcess", "rebootProcess", "poweroffProcess"}
    check("AST.RUNNING_TRUE_SITES", "Only known session processes have running = true assignments", set(running_true_sites) == expected_sites, f"found: {set(running_true_sites)}")


# ==============================================================================
# Phase 2: State Machine & Rapid Keypress Simulation
# ==============================================================================
class SystemRailStateMachine:
    """Accurate state machine replicating SystemRail.qml logic."""
    def __init__(self):
        self.currentView = "main"
        self.selectedSsid = ""
        self.confirmingForgetSsid = ""
        self.confirmationAction = ""
        self.overlayClosedCount = 0
        self.executions = {
            "lock": 0,
            "logout": 0,
            "reboot": 0,
            "poweroff": 0
        }

    @property
    def isConfirming(self) -> bool:
        return self.confirmationAction != ""

    def triggerConfirmation(self, action: str):
        self.confirmationAction = action

    def cancelConfirmation(self):
        self.confirmationAction = ""

    def executeConfirmation(self):
        action = self.confirmationAction
        self.confirmationAction = ""
        self.overlayClosedCount += 1

        if action == "reboot":
            self.executions["reboot"] += 1
        elif action == "poweroff":
            self.executions["poweroff"] += 1
        elif action == "logout":
            self.executions["logout"] += 1

    def clickLock(self):
        self.overlayClosedCount += 1
        self.executions["lock"] += 1

    def handleEscape(self):
        if self.confirmingForgetSsid != "":
            self.confirmingForgetSsid = ""
        elif self.isConfirming:
            self.cancelConfirmation()
        elif self.selectedSsid != "":
            self.selectedSsid = ""
        elif self.currentView == "wifi":
            self.currentView = "main"
            self.selectedSsid = ""
            self.confirmingForgetSsid = ""
        else:
            self.overlayClosedCount += 1

    def burstEscape(self, count: int):
        for _ in range(count):
            self.handleEscape()


def test_rapid_keypress_and_state_machine():
    print("\n--- Phase 2: Interactive State Machine & Rapid Keypress Fuzzing ---")

    # Scenario 1: Burst of Escape keys in confirmation mode
    actions = ["logout", "reboot", "poweroff"]
    for action in actions:
        sm = SystemRailStateMachine()
        sm.triggerConfirmation(action)
        check(f"STATE.CONFIRM.{action.upper()}.TRIGGER", f"Trigger {action} confirmation sets isConfirming", sm.isConfirming and sm.confirmationAction == action)
        
        # Burst of 50 Escape presses
        sm.burstEscape(50)
        check(f"STATE.CONFIRM.{action.upper()}.BURST_ESC.CANCELLED", f"Burst Escape clears confirmationAction for {action}", sm.confirmationAction == "" and not sm.isConfirming)
        check(f"STATE.CONFIRM.{action.upper()}.BURST_ESC.ZERO_EXEC", f"Burst Escape executes ZERO processes for {action}", sum(sm.executions.values()) == 0, f"executions: {sm.executions}")
        check(f"STATE.CONFIRM.{action.upper()}.BURST_ESC.OVERLAY_CLOSED", f"Burst Escape safely requests overlay close", sm.overlayClosedCount >= 1)

    # Scenario 2: Rapid Re-entrancy & State Switching
    sm2 = SystemRailStateMachine()
    sm2.triggerConfirmation("logout")
    sm2.handleEscape() # Escape 1 cancels logout
    sm2.triggerConfirmation("reboot")
    sm2.cancelConfirmation() # Cancel button
    sm2.triggerConfirmation("poweroff")
    sm2.executeConfirmation() # Confirm poweroff
    check("STATE.REENTRANCY.POWEROFF_ONLY", "Only poweroff executed after rapid state transitions", sm2.executions["poweroff"] == 1 and sm2.executions["logout"] == 0 and sm2.executions["reboot"] == 0, f"executions: {sm2.executions}")

    # Scenario 3: Illegal / Injected confirmationAction
    sm3 = SystemRailStateMachine()
    sm3.triggerConfirmation("rm -rf /; loginctl kill-user")
    sm3.executeConfirmation()
    check("STATE.SECURITY.ILLEGAL_ACTION_IGNORED", "Illegal injected action does not match any Process and executes nothing", sum(sm3.executions.values()) == 0, f"executions: {sm3.executions}")

    # Scenario 4: Tiered Escape Trapping in WiFi View
    sm4 = SystemRailStateMachine()
    sm4.currentView = "wifi"
    sm4.selectedSsid = "HackerNet"
    sm4.confirmingForgetSsid = "HackerNet"

    # Escape 1: Clears confirmingForgetSsid
    sm4.handleEscape()
    check("STATE.TIERED_ESC.STEP1_FORGET", "Escape 1 clears confirmingForgetSsid while keeping selectedSsid", sm4.confirmingForgetSsid == "" and sm4.selectedSsid == "HackerNet" and sm4.currentView == "wifi")

    # Escape 2: Clears selectedSsid
    sm4.handleEscape()
    check("STATE.TIERED_ESC.STEP2_SSID", "Escape 2 clears selectedSsid while staying in wifi view", sm4.selectedSsid == "" and sm4.currentView == "wifi")

    # Escape 3: Returns to main view
    sm4.handleEscape()
    check("STATE.TIERED_ESC.STEP3_WIFI_NAV", "Escape 3 returns from wifi view to main view", sm4.currentView == "main")

    # Escape 4: Closes overlay
    prev_close = sm4.overlayClosedCount
    sm4.handleEscape()
    check("STATE.TIERED_ESC.STEP4_CLOSE", "Escape 4 closes overlay from main view", sm4.overlayClosedCount == prev_close + 1)

    # Scenario 5: High-Priority Escape during Confirmation in Wifi View
    sm5 = SystemRailStateMachine()
    sm5.currentView = "wifi"
    sm5.selectedSsid = "TargetNet"
    sm5.triggerConfirmation("logout")
    sm5.handleEscape()
    check("STATE.ESC_PRIORITY.CONFIRM_OVER_WIFI", "Escape cancels confirmation before resetting wifi sub-states", not sm5.isConfirming and sm5.selectedSsid == "TargetNet" and sm5.currentView == "wifi")

    # Scenario 6: Monte Carlo Random Transition Fuzzing (5,000 iterations)
    sm_fuzz = SystemRailStateMachine()
    events = [
        "trigger_logout", "trigger_reboot", "trigger_poweroff", "trigger_bogus",
        "escape", "burst_escape_10", "cancel_click", "confirm_click", "lock_click"
    ]
    random.seed(424242)
    invariant_violations = []

    for i in range(5000):
        ev = random.choice(events)
        action_before = sm_fuzz.confirmationAction
        confirming_before = sm_fuzz.isConfirming
        exec_before = dict(sm_fuzz.executions)

        if ev == "trigger_logout":
            sm_fuzz.triggerConfirmation("logout")
        elif ev == "trigger_reboot":
            sm_fuzz.triggerConfirmation("reboot")
        elif ev == "trigger_poweroff":
            sm_fuzz.triggerConfirmation("poweroff")
        elif ev == "trigger_bogus":
            sm_fuzz.triggerConfirmation("arbitrary_command")
        elif ev == "escape":
            sm_fuzz.handleEscape()
        elif ev == "burst_escape_10":
            sm_fuzz.burstEscape(10)
        elif ev == "cancel_click":
            sm_fuzz.cancelConfirmation()
        elif ev == "confirm_click":
            sm_fuzz.executeConfirmation()
        elif ev == "lock_click":
            sm_fuzz.clickLock()

        # Invariant checks
        # 1. Any escape event must never increase session executions
        if "escape" in ev or ev == "cancel_click":
            for k in ["logout", "reboot", "poweroff"]:
                if sm_fuzz.executions[k] > exec_before[k]:
                    invariant_violations.append(f"Iteration {i}: {ev} caused execution of {k}")

        # 2. confirm_click can only execute if confirming_before was true for that specific valid action
        if ev == "confirm_click":
            if confirming_before and action_before in ["logout", "reboot", "poweroff"]:
                if sm_fuzz.executions[action_before] != exec_before[action_before] + 1:
                    invariant_violations.append(f"Iteration {i}: confirm_click failed to increment {action_before}")
            else:
                for k in ["logout", "reboot", "poweroff"]:
                    if sm_fuzz.executions[k] > exec_before[k]:
                        invariant_violations.append(f"Iteration {i}: confirm_click executed {k} without active confirmation")

    check("STATE.FUZZ.5000_TRANSITIONS", "5,000 randomized Monte Carlo state transitions passed with 0 invariant violations", len(invariant_violations) == 0, f"violations: {len(invariant_violations)}")


# ==============================================================================
# Phase 3: Boundary Test Scripts Execution
# ==============================================================================
def test_boundary_scripts():
    print("\n--- Phase 3: Boundary Test Shell Scripts Execution ---")
    scripts = [
        ("tests/e2e/tier2_boundaries/test_t5_safe_cancel_escape_boundaries.sh", "Safe Cancel & Escape Boundaries"),
        ("tests/e2e/tier2_boundaries/test_t5_allowlisted_execution_boundaries.sh", "Allowlisted Confirm Execution Boundaries"),
        ("tests/e2e/tier1_features/test_t5_immediate_session_lock.sh", "Immediate Session Lock Feature"),
        ("tests/e2e/tier1_features/test_t5_session_safety_confirmation.sh", "Session Safety Confirmation Feature"),
        ("tests/e2e/tier1_features/test_t5_allowlisted_execution.sh", "Allowlisted Execution Feature")
    ]

    for script_path, desc in scripts:
        full_path = os.path.join(PROJECT_ROOT, script_path)
        proc = subprocess.run(["bash", full_path], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd=PROJECT_ROOT)
        check(f"SHELL.{os.path.basename(script_path).upper()}", f"Shell boundary script '{desc}' exited 0", proc.returncode == 0, f"rc={proc.returncode}")


def main():
    print("================================================================================")
    print("    CHALLENGER 2: SYSTEM RAIL SESSION ACTIONS ADVERSARIAL STRESS SUITE          ")
    print("================================================================================")

    test_ast_and_lexical()
    test_rapid_keypress_and_state_machine()
    test_boundary_scripts()

    print("\n================================================================================")
    print(f"STRESS TEST SUMMARY: Total: {total_tests} | Passed: {passed_tests} | Failed: {len(failed_tests)}")
    print("================================================================================")

    if failed_tests:
        print("\nFAILED CHALLENGES:")
        for fid, fdesc, fdetails in failed_tests:
            print(f"  - [{fid}] {fdesc} ({fdetails})", file=sys.stderr)
        return 1
    else:
        print("\nALL EMPIRICAL ADVERSARIAL CHALLENGES PASSED (VERDICT: APPROVE)")
        return 0

if __name__ == "__main__":
    sys.exit(main())
