#!/usr/bin/env python3
"""
Adversarial Challenger Deep-Dive Test Suite for Milestone 1:
- Fastfetch TrueColor ANSI & dynamic OS/Kernel variables (R6)
- 16px widget separation math and runtime visibility toggles (R7)
"""

import os
import sys
import pty
import select
import subprocess
import tempfile
import json
import re
import fcntl
import termios
import struct

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
CONFIG_PATH = os.path.join(PROJECT_ROOT, "shell/config/fastfetch/config.jsonc")
SETTINGS_QML = os.path.join(PROJECT_ROOT, "shell/desktop/core/Settings.qml")
SHELL_QML = os.path.join(PROJECT_ROOT, "shell/shell.qml")

# Find quickshell
QUICKSHELL_BIN = None
for candidate in [
    "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/bin/quickshell",
    "/run/current-system/sw/bin/quickshell"
]:
    if os.path.exists(candidate) and os.access(candidate, os.X_OK):
        QUICKSHELL_BIN = candidate
        break

if not QUICKSHELL_BIN:
    # Try glob
    import glob
    candidates = glob.glob("/nix/store/*quickshell*/bin/quickshell")
    if candidates:
        QUICKSHELL_BIN = candidates[0]

passed_tests = []
failed_tests = []

def record(test_id, passed, description, details=""):
    if passed:
        passed_tests.append((test_id, description))
        print(f"  [PASS] {test_id}: {description} {details}")
    else:
        failed_tests.append((test_id, description, details))
        print(f"  [FAIL] {test_id}: {description} | Details: {details}", file=sys.stderr)

def run_fastfetch_pty(cols=100, rows=35, env_overrides=None):
    master, slave = pty.openpty()
    winsize = struct.pack("HHHH", rows, cols, 0, 0)
    fcntl.ioctl(slave, termios.TIOCSWINSZ, winsize)

    env = os.environ.copy()
    env["COLUMNS"] = str(cols)
    env["LINES"] = str(rows)
    if env_overrides:
        env.update(env_overrides)

    cmd = ["fastfetch", "-c", CONFIG_PATH, "--pipe", "false"]
    proc = subprocess.Popen(
        cmd,
        stdin=slave,
        stdout=slave,
        stderr=slave,
        env=env,
        close_fds=True,
        cwd=PROJECT_ROOT
    )
    os.close(slave)

    output = bytearray()
    while True:
        r, _, _ = select.select([master], [], [], 2.0)
        if not r:
            break
        try:
            chunk = os.read(master, 4096)
            if not chunk:
                break
            output.extend(chunk)
        except OSError:
            break

    os.close(master)
    proc.wait()
    return proc.returncode, output.decode("utf-8", errors="replace")

def test_fastfetch_ansi_and_dynamic():
    print("\n=== CHALLENGE SUITE 1: Fastfetch TrueColor ANSI & Dynamic Variables ===")
    
    # 1. Inspect os-release and uname
    os_release_version = None
    if os.path.exists("/etc/os-release"):
        with open("/etc/os-release", "r") as f:
            for line in f:
                if line.startswith("VERSION_ID="):
                    os_release_version = line.strip().split("=")[1].strip('"')
                    break

    uname_release = os.uname().release
    print(f"System Reference: VERSION_ID='{os_release_version}', uname release='{uname_release}'")

    # Run fastfetch in PTY
    rc, raw_output = run_fastfetch_pty(cols=120, rows=40)
    record("FF.CHALLENGE.01", rc == 0, "Fastfetch executes cleanly with code 0")

    # 2. TrueColor ANSI escapes
    # Hex #1BFD9C -> RGB: 27, 253, 156
    # Escape: \x1b[38;2;27;253;156m
    acid_green_escape = "\x1b[38;2;27;253;156m"
    has_acid_green = acid_green_escape in raw_output
    record("FF.CHALLENGE.02", has_acid_green, "Output stream contains TrueColor #1BFD9C escape sequence", f"Found: {has_acid_green}")

    # Separator color #7A7A7A -> RGB: 122, 122, 122
    sep_color_escape = "38;2;122;122;122"
    has_sep_color = sep_color_escape in raw_output
    record("FF.CHALLENGE.03", has_sep_color, "Output stream contains Separator TrueColor #7A7A7A escape sequence", f"Found: {has_sep_color}")

    # Output color #FFFFFF -> RGB: 255, 255, 255
    output_color_escape = "38;2;255;255;255"
    has_output_color = output_color_escape in raw_output
    record("FF.CHALLENGE.04", has_output_color, "Output stream contains Output TrueColor #FFFFFF escape sequence", f"Found: {has_output_color}")

    # 3. Dynamic OS and Kernel verification
    plain_output = re.sub(r"\x1b\[[0-9;]*[mGKF]", "", raw_output)

    # OS regex
    os_match = re.search(r"OS:\s*ctOS-([0-9\.]+)", plain_output)
    record("FF.CHALLENGE.05", os_match is not None, "OS line matches dynamic ctOS-<version> format", f"Matched: {os_match.group(0) if os_match else 'None'}")
    if os_match and os_release_version:
        resolved_os_ver = os_match.group(1)
        record("FF.CHALLENGE.06", resolved_os_ver == os_release_version, f"OS version dynamically equals /etc/os-release VERSION_ID ({os_release_version})", f"Resolved: {resolved_os_ver}")
        record("FF.CHALLENGE.07", resolved_os_ver != "0.1.0-a", "OS version is NOT hardcoded 0.1.0-a")

    # Kernel regex
    kernel_match = re.search(r"Kernel:\s*blume-krn-([0-9\.\-a-zA-Z]+)", plain_output)
    record("FF.CHALLENGE.08", kernel_match is not None, "Kernel line matches dynamic blume-krn-<release> format", f"Matched: {kernel_match.group(0) if kernel_match else 'None'}")
    if kernel_match:
        resolved_krn_ver = kernel_match.group(1)
        record("FF.CHALLENGE.09", resolved_krn_ver == uname_release, f"Kernel release dynamically equals uname -r ({uname_release})", f"Resolved: {resolved_krn_ver}")
        record("FF.CHALLENGE.10", resolved_krn_ver != "1.0.8", "Kernel release is NOT hardcoded 1.0.8")

    # 4. Section structure verification
    # Separator character is '─' (U+2500)
    # Count occurrences of lines with multiple '─'
    separator_lines = [line for line in plain_output.splitlines() if "────" in line]
    record("FF.CHALLENGE.11", len(separator_lines) == 3, f"Exactly 3 horizontal '─' separator lines present in live output", f"Found: {len(separator_lines)}")

    # 5. Check config.jsonc module definitions
    with open(CONFIG_PATH, "r") as f:
        cfg_raw = f.read()
    
    # Strip comments to parse JSON
    def strip_comments(text):
        out = []
        in_string = False
        i = 0
        n = len(text)
        while i < n:
            c = text[i]
            if c == '"' and (i == 0 or text[i-1] != '\\'):
                in_string = not in_string
                out.append(c)
                i += 1
            elif not in_string and i + 1 < n and text[i:i+2] == "//":
                while i < n and text[i] != '\n':
                    i += 1
            else:
                out.append(c)
                i += 1
        return "".join(out)
    
    cfg = json.loads(strip_comments(cfg_raw))
    modules = cfg.get("modules", [])
    
    # Check sections delimited by separator
    sep_indices = [i for i, m in enumerate(modules) if isinstance(m, dict) and m.get("type") == "separator"]
    record("FF.CHALLENGE.12", len(sep_indices) == 3, f"config.jsonc declares exactly 3 separator modules", f"Indices: {sep_indices}")
    
    # Section 1: before sep_indices[1] (contains os, kernel)
    sec1_types = [m.get("type") if isinstance(m, dict) else m for m in modules[:sep_indices[1]]]
    record("FF.CHALLENGE.13", "os" in sec1_types and "kernel" in sec1_types, "Section 1 contains OS and Kernel modules")

    # Section 2: between sep_indices[1] and sep_indices[2] (desktop/UI: shell, wm, terminal, theme)
    sec2_types = [m.get("type") if isinstance(m, dict) else m for m in modules[sep_indices[1]+1:sep_indices[2]]]
    record("FF.CHALLENGE.14", "shell" in sec2_types and "wm" in sec2_types, "Section 2 contains Shell and WM modules")

    # Section 3: after sep_indices[2] (hardware/network: disk, localip, battery)
    sec3_types = [m.get("type") if isinstance(m, dict) else m for m in modules[sep_indices[2]+1:]]
    record("FF.CHALLENGE.15", "disk" in sec3_types and "battery" in sec3_types, "Section 3 contains Disk and Battery modules")

def test_widget_separation_and_runtime_math():
    print("\n=== CHALLENGE SUITE 2: Widget Separation Math & Runtime Visibility Toggles ===")
    
    if not QUICKSHELL_BIN:
        print("ERROR: Quickshell binary not found! Cannot execute runtime QML test harness.", file=sys.stderr)
        record("WIDGET.CHALLENGE.00", False, "Quickshell binary exists", "Not found")
        return

    # Create temporary QML test harness
    qml_harness_path = os.path.join(tempfile.gettempdir(), "test_m1_challenger_qml.qml")
    with open(qml_harness_path, "w") as f:
        f.write("""
import QtQuick
import Quickshell
import desktop.core

Scope {
    id: root

    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            console.log("=== QML CHALLENGER RUNTIME START ===");

            // 1. Initial State & Defaults
            Settings.resetToDefaults();
            const profilerH = 220; // TargetProfiler implicitHeight
            const pTop = Settings.getWidgetMargin("targetProfiler", "top", 56);
            const tTop = Settings.getWidgetMargin("networkTracer", "top", 292);
            const pBottom = pTop + profilerH;
            const gap = tTop - pBottom;

            console.log("CHALLENGE_METRIC:P_TOP:" + pTop);
            console.log("CHALLENGE_METRIC:P_HEIGHT:" + profilerH);
            console.log("CHALLENGE_METRIC:P_BOTTOM:" + pBottom);
            console.log("CHALLENGE_METRIC:T_TOP:" + tTop);
            console.log("CHALLENGE_METRIC:DEFAULT_GAP:" + gap);

            // 2. shell.qml Dynamic Evaluation Simulation
            function computeTracerTop(hasMargin, marginVal, profilerVis) {
                return hasMargin ? marginVal : (profilerVis ? (Theme.barHeight + Theme.spacingXl + 220 + Theme.spacingXl) : (Theme.barHeight + Theme.spacingXl));
            }

            // Test State A: TargetProfiler Visible
            Settings.widgetTargetProfilerVisible = true;
            let computedA = computeTracerTop(Settings.hasWidgetMargin("networkTracer", "top"), Settings.getWidgetMargin("networkTracer", "top", 0), Settings.widgetTargetProfilerVisible);
            console.log("CHALLENGE_METRIC:STATE_A_TOP:" + computedA);
            console.log("CHALLENGE_METRIC:STATE_A_GAP:" + (computedA - pBottom));

            // Test State B: TargetProfiler Hidden (Dynamic Collapse)
            Settings.widgetTargetProfilerVisible = false;
            let computedB = computeTracerTop(Settings.hasWidgetMargin("networkTracer", "top"), Settings.getWidgetMargin("networkTracer", "top", 0), Settings.widgetTargetProfilerVisible);
            console.log("CHALLENGE_METRIC:STATE_B_COLLAPSED_TOP:" + computedB);

            // Test State C: 100 Rapid Cyclic Toggles (Stress & Stability)
            let toggleStressPassed = true;
            for (let i = 0; i < 100; i++) {
                Settings.widgetTargetProfilerVisible = (i % 2 === 0);
                let topVal = computeTracerTop(Settings.hasWidgetMargin("networkTracer", "top"), Settings.getWidgetMargin("networkTracer", "top", 0), Settings.widgetTargetProfilerVisible);
                let expected = (i % 2 === 0) ? 292 : 56;
                if (topVal !== expected) {
                    toggleStressPassed = false;
                    console.log("STRESS_FAIL_ITERATION_" + i + "_GOT_" + topVal + "_EXPECTED_" + expected);
                    break;
                }
            }
            console.log("CHALLENGE_METRIC:STRESS_PASSED:" + toggleStressPassed);

            // Test State D: User Override Protection
            // User specifies custom y = 350
            Settings.parseConfig(JSON.stringify({
                widgets: {
                    networkTracer: { y: 350 }
                }
            }));
            let userOverrideHasMargin = Settings.hasWidgetMargin("networkTracer", "top");
            let userOverrideVal = Settings.getWidgetMargin("networkTracer", "top", 0);
            let userOverrideTopVisible = computeTracerTop(userOverrideHasMargin, userOverrideVal, true);
            let userOverrideTopHidden = computeTracerTop(userOverrideHasMargin, userOverrideVal, false);

            console.log("CHALLENGE_METRIC:OVERRIDE_HAS_MARGIN:" + userOverrideHasMargin);
            console.log("CHALLENGE_METRIC:OVERRIDE_TOP_PROFILER_VISIBLE:" + userOverrideTopVisible);
            console.log("CHALLENGE_METRIC:OVERRIDE_TOP_PROFILER_HIDDEN:" + userOverrideTopHidden);

            // Test State E: Restoration after reset
            Settings.resetToDefaults();
            let restoredHasMargin = Settings.hasWidgetMargin("networkTracer", "top");
            let restoredTop = computeTracerTop(restoredHasMargin, Settings.getWidgetMargin("networkTracer", "top", 0), true);
            console.log("CHALLENGE_METRIC:RESTORED_HAS_MARGIN:" + restoredHasMargin);
            console.log("CHALLENGE_METRIC:RESTORED_TOP:" + restoredTop);

            console.log("=== QML CHALLENGER RUNTIME END ===");
            Qt.quit();
        }
    }
}
""")

    env = os.environ.copy()
    env["QML_IMPORT_PATH"] = os.path.join(PROJECT_ROOT, "shell")
    tmp_settings = os.path.join(tempfile.gettempdir(), "test_ctos_temp_settings.json")
    env["CTOS_SETTINGS_PATH"] = tmp_settings

    proc = subprocess.Popen(
        [QUICKSHELL_BIN, "-p", qml_harness_path],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env
    )
    stdout, stderr = proc.communicate(timeout=10)
    try:
        os.remove(qml_harness_path)
        if os.path.exists(tmp_settings):
            os.remove(tmp_settings)
    except:
        pass

    record("WIDGET.CHALLENGE.01", proc.returncode == 0, "Quickshell runtime harness executed cleanly", f"Returncode: {proc.returncode}")

    metrics = {}
    for line in stdout.splitlines():
        if "CHALLENGE_METRIC:" in line:
            parts = line.split("CHALLENGE_METRIC:")[1].strip().split(":")
            if len(parts) >= 2:
                metrics[parts[0]] = parts[1]

    # Evaluate metrics
    p_top = int(metrics.get("P_TOP", 0))
    p_bottom = int(metrics.get("P_BOTTOM", 0))
    t_top = int(metrics.get("T_TOP", 0))
    default_gap = int(metrics.get("DEFAULT_GAP", 0))

    record("WIDGET.CHALLENGE.02", p_top == 56, f"Default targetProfiler top margin is 56px", f"Got {p_top}")
    record("WIDGET.CHALLENGE.03", p_bottom == 276, f"Default targetProfiler bottom is 276px (top 56 + height 220)", f"Got {p_bottom}")
    record("WIDGET.CHALLENGE.04", t_top == 292, f"Default networkTracer top margin is 292px", f"Got {t_top}")
    record("WIDGET.CHALLENGE.05", default_gap == 16, f"Default vertical gap is exactly 16px (Theme.spacingXl)", f"Got {default_gap}")
    record("WIDGET.CHALLENGE.06", default_gap >= 16, f"Default vertical gap satisfies invariant >= 16px", f"Got {default_gap}")

    # State A: Both visible
    state_a_top = int(metrics.get("STATE_A_TOP", 0))
    state_a_gap = int(metrics.get("STATE_A_GAP", 0))
    record("WIDGET.CHALLENGE.07", state_a_top == 292, "State A: computed networkTracer top is 292px when targetProfiler is visible", f"Got {state_a_top}")
    record("WIDGET.CHALLENGE.08", state_a_gap == 16, "State A: clean gap is 16px when targetProfiler is visible", f"Got {state_a_gap}")

    # State B: Dynamic Collapse
    state_b_top = int(metrics.get("STATE_B_COLLAPSED_TOP", 0))
    record("WIDGET.CHALLENGE.09", state_b_top == 56, "State B: networkTracer collapses upward to Y=56px when targetProfiler is hidden", f"Got {state_b_top}")

    # State C: Stress cyclic toggles
    stress_passed = metrics.get("STRESS_PASSED", "false") == "true"
    record("WIDGET.CHALLENGE.10", stress_passed, "State C: 100 rapid cyclic visibility toggles maintain deterministic 56px/292px coordinates without jitter", f"Result: {stress_passed}")

    # State D: User override isolation
    override_has_margin = metrics.get("OVERRIDE_HAS_MARGIN", "false") == "true"
    override_visible = int(metrics.get("OVERRIDE_TOP_PROFILER_VISIBLE", 0))
    override_hidden = int(metrics.get("OVERRIDE_TOP_PROFILER_HIDDEN", 0))
    record("WIDGET.CHALLENGE.11", override_has_margin, "State D: User manual coordinate override sets hasWidgetMargin to true", f"Got {override_has_margin}")
    record("WIDGET.CHALLENGE.12", override_visible == 350, "State D: User manual coordinate override (350px) is respected when profiler visible", f"Got {override_visible}")
    record("WIDGET.CHALLENGE.13", override_hidden == 350, "State D: User manual coordinate override (350px) is preserved when profiler hidden (immune to auto-collapse)", f"Got {override_hidden}")

    # State E: Restoration after reset
    restored_has_margin = metrics.get("RESTORED_HAS_MARGIN", "true") == "false"
    restored_top = int(metrics.get("RESTORED_TOP", 0))
    record("WIDGET.CHALLENGE.14", restored_has_margin, "State E: Settings.resetToDefaults() clears user override flag (hasWidgetMargin = false)", f"hasMargin={not restored_has_margin}")
    record("WIDGET.CHALLENGE.15", restored_top == 292, "State E: Dynamic positioning restored to 292px", f"Got {restored_top}")

def main():
    print("================================================================================")
    print("           CHALLENGER M1-1 EMPIRICAL ADVERSARIAL STRESS TEST SUITE              ")
    print("================================================================================")
    
    test_fastfetch_ansi_and_dynamic()
    test_widget_separation_and_runtime_math()

    total = len(passed_tests) + len(failed_tests)
    print("\n================================================================================")
    print(f"SUMMARY: Total Tests: {total} | Passed: {len(passed_tests)} | Failed: {len(failed_tests)}")
    print("================================================================================")

    if failed_tests:
        print("\nFAILED TESTS:")
        for fid, fdesc, fdetails in failed_tests:
            print(f"  - [{fid}] {fdesc} ({fdetails})")
        return 1
    else:
        print("\nALL ADVERSARIAL CHALLENGES CONFIRMED PASSED EMPIRICALLY.")
        return 0

if __name__ == "__main__":
    sys.exit(main())
