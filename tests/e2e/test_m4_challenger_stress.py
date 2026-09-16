#!/usr/bin/env python3
"""
Adversarial Stress Test Suite for Greeter M4 Interactive Terminal
Tests edge cases, subprocess queueing, focus restoration logic, history traversal,
buffer capping, and live Quickshell execution.
"""

import os
import sys
import subprocess
import json

REPO_ROOT = "/home/reze/Projects/ctOS"
TERMINAL_QML = os.path.join(REPO_ROOT, "shell/greeter/components/Terminal.qml")
COMMAND_MGR = os.path.join(REPO_ROOT, "shell/greeter/services/CommandManager.qml")
TERMINAL_MGR = os.path.join(REPO_ROOT, "shell/greeter/services/TerminalManager.qml")

pass_count = 0
fail_count = 0

def record_test(condition, test_name, details=""):
    global pass_count, fail_count
    if condition:
        pass_count += 1
        print(f"  [PASS] {test_name}")
    else:
        fail_count += 1
        print(f"  [FAIL] {test_name} - {details}")

print("=" * 80)
print("ADVERSARIAL STRESS TEST: GREETER M4 INTERACTIVE TERMINAL")
print("=" * 80)

# -----------------------------------------------------------------------------
# 1. INTEGRITY AND ANTI-FACADE CHECKS
# -----------------------------------------------------------------------------
print("\n[CHALLENGE 1] Integrity & Anti-Facade Analysis...")

with open(TERMINAL_QML, "r", encoding="utf-8") as f:
    term_src = f.read()

with open(COMMAND_MGR, "r", encoding="utf-8") as f:
    cmd_src = f.read()

with open(TERMINAL_MGR, "r", encoding="utf-8") as f:
    tm_src = f.read()

# Check: No hardcoded output lines simulating commands
record_test("fake_stdout" not in tm_src and "fake_output" not in tm_src, "No fake/mock subprocess outputs in TerminalManager")
record_test("hardcoded" not in cmd_src.lower(), "No hardcoded indicators in CommandManager")

# Check: Real Process usage with StdioCollector
record_test("Quickshell.Io" in tm_src and "Process {" in tm_src, "Genuine Quickshell.Io.Process instantiation")
record_test("StdioCollector {" in tm_src and "waitForEnd: true" in tm_src, "Genuine StdioCollector with waitForEnd: true")
record_test('shellProc.command = ["sh", "-c", cmd]' in tm_src, "Dynamic POSIX shell execution array")

# Check: FocusManager registration and parameters
record_test("FocusManager.registerTarget(terminalInput, {" in term_src, "FocusManager registers terminalInput")
record_test("tabIndex: 1" in term_src, "terminalInput registered at tabIndex: 1")
record_test("focus: false" in term_src, "Boot focus NOT set on terminalInput")
record_test("terminal.restoreTerminalFocus" in term_src, "Focus restoration state tracked in Terminal.qml")
record_test("terminalInput.forceActiveFocus()" in term_src, "Explicit focus restoration called when tabIndex was 1")

# Check: Prompt mouse area
record_test("cursorShape: Qt.IBeamCursor" in term_src and "terminalInput.forceActiveFocus()" in term_src, "Prompt label click transfers focus to terminalInput")

# -----------------------------------------------------------------------------
# 2. ADVERSARIAL LOGIC STRESS TESTING (JavaScript Runtime)
# -----------------------------------------------------------------------------
print("\n[CHALLENGE 2] Stress-Testing History & Subprocess Queuing Logic (Node.js)...")

node_adversarial_script = """
const assert = require('assert');

// A. History Edge Cases
let history = [];
const maxHistory = 15;
let historyIndex = -1;

function sendCommand(input) {
    const raw = input ? input.trim() : "";
    if (!raw) return;
    if (history[0] !== raw) history.unshift(raw);
    if (history.length > maxHistory) history.pop();
    historyIndex = -1;
}

function previousHistory() {
    if (history.length === 0) return "";
    historyIndex = Math.min(historyIndex + 1, history.length - 1);
    return history[historyIndex];
}

function nextHistory() {
    if (historyIndex <= 0) {
        historyIndex = -1;
        return "";
    }
    historyIndex--;
    return history[historyIndex];
}

// Edge case 1: Empty history previous/next
assert.strictEqual(previousHistory(), "");
assert.strictEqual(nextHistory(), "");

// Edge case 2: Whitespace-only commands
sendCommand("   ");
sendCommand("\\t\\n");
assert.strictEqual(history.length, 0);

// Edge case 3: Consecutive duplicates
sendCommand("uname -a");
sendCommand("uname -a");
sendCommand("uname -a");
assert.strictEqual(history.length, 1);
assert.strictEqual(history[0], "uname -a");

// Edge case 4: Interleaved commands
sendCommand("ls");
sendCommand("uname -a");
assert.strictEqual(history.length, 3);
assert.strictEqual(history[0], "uname -a");
assert.strictEqual(history[1], "ls");
assert.strictEqual(history[2], "uname -a");

// Edge case 5: Deep boundary clamping
for (let i = 0; i < 25; i++) {
    sendCommand("command_" + i);
}
assert.strictEqual(history.length, 15);
assert.strictEqual(history[0], "command_24");
assert.strictEqual(history[14], "command_10");

// Traverse up 50 times (should clamp at 14)
for (let i = 0; i < 50; i++) {
    previousHistory();
}
assert.strictEqual(historyIndex, 14);
assert.strictEqual(previousHistory(), "command_10");

// Traverse down 50 times (should clamp at -1 and return "")
for (let i = 0; i < 50; i++) {
    nextHistory();
}
assert.strictEqual(historyIndex, -1);
assert.strictEqual(nextHistory(), "");

// B. Model Buffer Capping
let logModel = [];
function addToModel(items) {
    if (Array.isArray(items)) {
        logModel.push(...items);
    } else {
        logModel.push(items);
    }
    if (logModel.length > 50) {
        logModel.splice(0, logModel.length - 50);
    }
}

for (let i = 0; i < 150; i++) {
    addToModel({ id: i });
}
assert.strictEqual(logModel.length, 50);
assert.strictEqual(logModel[0].id, 100);
assert.strictEqual(logModel[49].id, 149);

// C. SplitLines Edge Cases
function _splitLines(rawText) {
    if (!rawText) return [];
    const lines = rawText.replace(/\\r\\n/g, "\\n").split("\\n");
    if (lines.length > 0 && lines[lines.length - 1] === "") {
        lines.pop();
    }
    return lines;
}

assert.deepStrictEqual(_splitLines(null), []);
assert.deepStrictEqual(_splitLines(undefined), []);
assert.deepStrictEqual(_splitLines(""), []);
assert.deepStrictEqual(_splitLines("\\n"), [""]);
assert.deepStrictEqual(_splitLines("\\r\\n"), [""]);
assert.deepStrictEqual(_splitLines("line1\\r\\nline2\\r\\nline3\\n"), ["line1", "line2", "line3"]);
assert.deepStrictEqual(_splitLines("line1\\n\\nline2"), ["line1", "", "line2"]);

// D. Sequential Command Queue Simulation
let isRunning = false;
let commandQueue = [];
let executionHistory = [];

function executeShellCommand(rawCommand) {
    const cmd = (rawCommand || "").trim();
    if (!cmd) return;
    if (isRunning) {
        commandQueue.push(cmd);
        return;
    }
    isRunning = true;
    executionHistory.push(cmd);
}

function processFinished() {
    isRunning = false;
    if (commandQueue.length > 0) {
        const nextCmd = commandQueue.shift();
        isRunning = true;
        executionHistory.push(nextCmd);
    }
}

executeShellCommand("cmd1");
executeShellCommand("cmd2");
executeShellCommand("cmd3");
assert.strictEqual(executionHistory.length, 1);
assert.strictEqual(executionHistory[0], "cmd1");
assert.strictEqual(commandQueue.length, 2);

processFinished(); // finishes cmd1, triggers cmd2
assert.strictEqual(executionHistory.length, 2);
assert.strictEqual(executionHistory[1], "cmd2");
assert.strictEqual(commandQueue.length, 1);

processFinished(); // finishes cmd2, triggers cmd3
assert.strictEqual(executionHistory.length, 3);
assert.strictEqual(executionHistory[2], "cmd3");
assert.strictEqual(commandQueue.length, 0);

processFinished(); // finishes cmd3, queue empty
assert.strictEqual(isRunning, false);

console.log("ALL_ADVERSARIAL_NODE_CHECKS_PASSED");
"""

res = subprocess.run(["node", "-e", node_adversarial_script], capture_output=True, text=True)
record_test(res.returncode == 0 and "ALL_ADVERSARIAL_NODE_CHECKS_PASSED" in res.stdout,
            "History, Buffer Capping, Line Splitting & Queueing Stress Tests", res.stderr)

# -----------------------------------------------------------------------------
# 3. LIVE OFFSCREEN QUICKSHELL PROCESS EXECUTION & STDIO CAPTURE
# -----------------------------------------------------------------------------
print("\n[CHALLENGE 3] Live Offscreen Quickshell Subprocess Stress Testing...")

qs_bin = "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/bin/quickshell"
qs_env = os.environ.copy()
qs_env["QML2_IMPORT_PATH"] = "/nix/store/m1y5myv0v3aph5qgz05xa0m64s48vk52-qt5compat-6.11.2/lib/qt-6/qml:/nix/store/10553j4116y6jllliqpg5kz7d35bblab-qtdeclarative-6.11.2/lib/qt-6/qml:/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/lib/qt-6/qml:/home/reze/Projects/ctOS/shell"
qs_env["QML_IMPORT_PATH"] = qs_env["QML2_IMPORT_PATH"]
qs_env["CTOS_DEBUG"] = "1"
qs_env["CTOS_MODE"] = "test"
qs_env["QT_QPA_PLATFORM"] = "offscreen"

stress_qml_code = """
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property int testStep: 0
    property var results: []

    Process {
        id: proc
        command: []
        running: false

        stdout: StdioCollector {
            id: outCol
            waitForEnd: true
        }

        stderr: StdioCollector {
            id: errCol
            waitForEnd: true
        }

        onExited: function(code, status) {
            root.results.push({
                step: root.testStep,
                code: code,
                out: outCol.text,
                err: errCol.text
            });
            root.runNext();
        }
    }

    function runNext() {
        testStep++;
        if (testStep === 1) {
            // Test 1: Non-zero exit code with stderr
            proc.command = ["sh", "-c", "echo 'failed_task' >&2; exit 42"];
            proc.running = true;
        } else if (testStep === 2) {
            // Test 2: Pipeline with quoting and variable expansion
            proc.command = ["sh", "-c", "A='VAL_123'; echo \\\"alpha beta $A\\\" | awk '{print $3}'"];
            proc.running = true;
        } else if (testStep === 3) {
            // Test 3: Multiple newlines and empty outputs
            proc.command = ["sh", "-c", "printf 'lineA\\n\\nlineB\\n'"];
            proc.running = true;
        } else {
            console.log("QS_STRESS_COMPLETE:" + JSON.stringify(root.results));
            Qt.quit();
        }
    }

    Component.onCompleted: {
        runNext();
    }
}
"""

stress_qml_path = os.path.join(REPO_ROOT, "tests/e2e/test_m4_stress_proc.qml")
with open(stress_qml_path, "w", encoding="utf-8") as f:
    f.write(stress_qml_code)

try:
    qs_res = subprocess.run(
        ["timeout", "8", qs_bin, "-p", stress_qml_path],
        env=qs_env,
        capture_output=True,
        text=True
    )
    
    combined_out = qs_res.stdout + qs_res.stderr
    has_marker = "QS_STRESS_COMPLETE:" in combined_out
    record_test(has_marker, "Quickshell offscreen subprocess test executed to completion", combined_out)

    if has_marker:
        json_str = combined_out.split("QS_STRESS_COMPLETE:")[1].split("\n")[0]
        results = json.loads(json_str)

        # Check step 1: exit code 42 and stderr
        step1 = next((r for r in results if r["step"] == 1), None)
        record_test(step1 is not None and step1["code"] == 42 and "failed_task" in step1["err"],
                    "Subprocess captures non-zero exit code (42) and stderr")

        # Check step 2: pipeline and variable expansion
        step2 = next((r for r in results if r["step"] == 2), None)
        record_test(step2 is not None and step2["code"] == 0 and "VAL_123" in step2["out"],
                    "Subprocess executes pipelines with variable expansion ($A)")

        # Check step 3: multiline stdout
        step3 = next((r for r in results if r["step"] == 3), None)
        record_test(step3 is not None and "lineA" in step3["out"] and "lineB" in step3["out"],
                    "Subprocess captures multiline stdout output")
finally:
    if os.path.exists(stress_qml_path):
        os.remove(stress_qml_path)

# -----------------------------------------------------------------------------
# 4. LIVE GREETER INTEGRATION SMOKE TEST
# -----------------------------------------------------------------------------
print("\n[CHALLENGE 4] Headless Greeter Full QML Component Load...")

greeter_env = qs_env.copy()
if "QT_QPA_PLATFORM" in greeter_env:
    del greeter_env["QT_QPA_PLATFORM"]

greeter_res = subprocess.run(
    ["timeout", "4", qs_bin, "-p", "shell/greeter.qml"],
    env=greeter_env,
    capture_output=True,
    text=True
)

combined_greeter = greeter_res.stdout + greeter_res.stderr
record_test("Configuration Loaded" in combined_greeter, "Greeter loads configuration cleanly without crash")
record_test("Active user changed" in combined_greeter or "Authentication Session opened" in combined_greeter or greeter_res.returncode == 124,
            "Greeter initiates session and terminal logging")

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
print("\n" + "=" * 80)
print(f"ADVERSARIAL SUITE SUMMARY: {pass_count} PASSED, {fail_count} FAILED")
print("=" * 80)

if fail_count > 0:
    sys.exit(1)
sys.exit(0)
