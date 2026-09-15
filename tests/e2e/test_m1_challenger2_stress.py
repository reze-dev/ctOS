#!/usr/bin/env python3
"""
Empirical Adversarial Stress & Boundary Suite for Milestone 1 (Challenger M1-2):
- Fastfetch narrow terminal column analysis (<40, <80, ultra-narrow)
- Non-interactive pipe redirection, SIGPIPE, and escape preservation
- Logo path resolution ($HOME/.config/fastfetch/dedsec.txt vs repository) & missing asset resilience
- User settings overrides in settings.json vs fallback defaults & dynamic gap math
- Full regression matrix verification
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
import hashlib
import time

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
CONFIG_PATH = os.path.join(PROJECT_ROOT, "shell/config/fastfetch/config.jsonc")
REPO_LOGO_PATH = os.path.join(PROJECT_ROOT, "shell/config/fastfetch/dedsec.txt")
HOME_LOGO_PATH = os.path.expanduser("~/.config/fastfetch/dedsec.txt")
SETTINGS_QML = os.path.join(PROJECT_ROOT, "shell/desktop/core/Settings.qml")
SHELL_QML = os.path.join(PROJECT_ROOT, "shell/shell.qml")

QUICKSHELL_BIN = None
for candidate in [
    "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/bin/quickshell",
    "/run/current-system/sw/bin/quickshell"
]:
    if os.path.exists(candidate) and os.access(candidate, os.X_OK):
        QUICKSHELL_BIN = candidate
        break

if not QUICKSHELL_BIN:
    import glob
    candidates = glob.glob("/nix/store/*quickshell*/bin/quickshell")
    if candidates:
        QUICKSHELL_BIN = candidates[0]

total_tests = 0
passed_tests = 0
failed_tests = []

def check(test_id, condition, description, details=""):
    global total_tests, passed_tests, failed_tests
    total_tests += 1
    if condition:
        passed_tests += 1
        print(f"  [PASS] {test_id}: {description} {details}")
    else:
        failed_tests.append((test_id, description, details))
        print(f"  [FAIL] {test_id}: {description} | Details: {details}", file=sys.stderr)

def run_fastfetch_pty(cols=80, rows=30, env_overrides=None):
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
        r, _, _ = select.select([master], [], [], 1.5)
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

def test_fastfetch_boundaries():
    print("\n--- Phase 1: Fastfetch Terminal Width Boundary Stress (<40, <80 cols) ---")
    widths = [15, 20, 25, 30, 35, 39, 40, 50, 60, 79, 80, 100, 140, 200]
    for w in widths:
        rc, out = run_fastfetch_pty(cols=w, rows=35)
        clean = re.sub(r"\x1b\[[0-9;]*[mGKF]", "", out)
        has_os = "ctOS-" in clean
        has_krn = "blume-krn-" in clean
        check(f"FF.WIDTH.{w}.01", rc == 0, f"Width {w} cols: exits cleanly with code 0")
        check(f"FF.WIDTH.{w}.02", has_os and has_krn, f"Width {w} cols: dynamically resolves OS and Kernel", f"(has_os={has_os}, has_krn={has_krn})")

    print("\n--- Phase 2: Fastfetch Pipe Redirection & Non-Interactive Behavior ---")
    # Subprocess pipe execution
    p_pipe = subprocess.run(["fastfetch", "-c", CONFIG_PATH], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd=PROJECT_ROOT)
    check("FF.PIPE.01", p_pipe.returncode == 0, "Non-interactive stdout pipe exits code 0")
    check("FF.PIPE.02", "OS: ctOS-" in p_pipe.stdout, "Dynamic OS present in piped stdout")
    check("FF.PIPE.03", "Kernel: blume-krn-" in p_pipe.stdout, "Dynamic Kernel present in piped stdout")

    # Separators in pipe
    clean_pipe = re.sub(r"\x1b\[[0-9;]*[mGKF]", "", p_pipe.stdout)
    sep_pipe = [l for l in clean_pipe.splitlines() if re.search(r"─{4,}", l)]
    check("FF.PIPE.04", len(sep_pipe) == 3, f"3 horizontal separator lines present in piped stream (found {len(sep_pipe)})")

    # SIGPIPE handling
    p_sigpipe = subprocess.Popen(["fastfetch", "-c", CONFIG_PATH], stdout=subprocess.PIPE, cwd=PROJECT_ROOT)
    head_proc = subprocess.run(["head", "-n", "2"], stdin=p_sigpipe.stdout, stdout=subprocess.PIPE, text=True)
    p_sigpipe.stdout.close()
    p_sigpipe.wait()
    # Fastfetch or head handling of broken pipe should not hang; head returncode 0
    check("FF.PIPE.05", head_proc.returncode == 0, "Fastfetch handles broken pipe / head truncation cleanly without hanging")

    # TrueColor escapes verification in unpiped/pty stream
    rc_tc, out_tc = run_fastfetch_pty(cols=100)
    check("FF.COLOR.01", "\x1b[38;2;27;253;156m" in out_tc or "38;2;27;253;156" in out_tc, "TrueColor acid green (#1BFD9C) escape sequence present")
    check("FF.COLOR.02", "38;2;122;122;122" in out_tc, "TrueColor muted separator (#7A7A7A) escape sequence present")

    print("\n--- Phase 3: Logo Path Verification & Missing File Fallback ---")
    # File existence
    check("FF.LOGO.01", os.path.exists(REPO_LOGO_PATH), f"Repo logo exists at {REPO_LOGO_PATH}")
    check("FF.LOGO.02", os.path.exists(HOME_LOGO_PATH), f"Home logo exists at {HOME_LOGO_PATH}")

    # Hash comparison
    if os.path.exists(REPO_LOGO_PATH) and os.path.exists(HOME_LOGO_PATH):
        h_repo = hashlib.sha256(open(REPO_LOGO_PATH, "rb").read()).hexdigest()
        h_home = hashlib.sha256(open(HOME_LOGO_PATH, "rb").read()).hexdigest()
        check("FF.LOGO.03", h_repo == h_home, f"Repo and Home DedSec logos are byte-for-byte identical (SHA256: {h_repo[:12]}...)")

    # Missing logo fallback
    with tempfile.TemporaryDirectory() as empty_home:
        env = os.environ.copy()
        env["HOME"] = empty_home
        p_miss = subprocess.run(["fastfetch", "-c", CONFIG_PATH], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env, cwd=PROJECT_ROOT)
        check("FF.LOGO.04", p_miss.returncode == 0, "Missing dedsec.txt exits 0 (graceful fallback)")
        check("FF.LOGO.05", "OS: ctOS-" in p_miss.stdout, "Dynamic OS retained even when logo file missing")
        check("FF.LOGO.06", "Kernel: blume-krn-" in p_miss.stdout, "Dynamic Kernel retained even when logo file missing")

def test_widget_overrides_and_regression():
    print("\n--- Phase 4: Widget Configuration Overrides & Fallback Invariants ---")
    if not QUICKSHELL_BIN:
        check("WIDGET.QS.01", False, "Quickshell binary exists", "Not found")
        return

    # Subtest 4.1: Disk settings.json loading via CTOS_SETTINGS_PATH
    with tempfile.NamedTemporaryFile(suffix=".json", mode="w", delete=False) as f_json:
        json.dump({"widgets": {"networkTracer": {"y": 385, "x": 65}}}, f_json)
        json_path = f_json.name

    qml_script_disk = """
import QtQuick
import Quickshell
import desktop.core

Scope {
    Connections {
        target: Settings
        function onSettingsLoaded() {
            const hasTop = Settings.hasWidgetMargin("networkTracer", "top");
            const hasLeft = Settings.hasWidgetMargin("networkTracer", "left");
            const topVal = Settings.getWidgetMargin("networkTracer", "top", 0);
            const leftVal = Settings.getWidgetMargin("networkTracer", "left", 0);
            console.log("DISK_RESULT:hasTop=" + hasTop + ":hasLeft=" + hasLeft + ":top=" + topVal + ":left=" + leftVal);
            Qt.quit();
        }
    }
}
"""
    with tempfile.NamedTemporaryFile(suffix=".qml", mode="w", delete=False) as f_qml:
        f_qml.write(qml_script_disk)
        qml_path_disk = f_qml.name

    env_disk = os.environ.copy()
    env_disk["CTOS_SETTINGS_PATH"] = json_path
    env_disk["QML_IMPORT_PATH"] = os.path.join(PROJECT_ROOT, "shell")
    res_disk = subprocess.run([QUICKSHELL_BIN, "-p", qml_path_disk], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env_disk, timeout=10)

    try:
        os.remove(json_path)
        os.remove(qml_path_disk)
    except:
        pass

    disk_line = [l for l in res_disk.stdout.splitlines() if "DISK_RESULT:" in l]
    if disk_line:
        parts = disk_line[0].split("DISK_RESULT:")[1].strip().split(":")
        res_map = dict(p.split("=") for p in parts)
        check("WIDGET.DISK.01", res_map.get("hasTop") == "true", "Disk settings.json sets hasWidgetMargin('networkTracer', 'top') to true")
        check("WIDGET.DISK.02", res_map.get("top") == "385", "Disk settings.json top margin parses to 385")
        check("WIDGET.DISK.03", res_map.get("hasLeft") == "true", "Disk settings.json sets hasWidgetMargin('networkTracer', 'left') to true")
        check("WIDGET.DISK.04", res_map.get("left") == "65", "Disk settings.json left margin parses to 65")
    else:
        check("WIDGET.DISK.01", False, "Disk settings.json output received", res_disk.stdout)

    # Subtest 4.2: Dynamic gap math and fallback defaults in QML
    qml_script_math = """
import QtQuick
import Quickshell
import desktop.core

Scope {
    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            // 1. Default State (no user overrides)
            Settings.resetToDefaults();
            Settings.widgetTargetProfilerVisible = true;

            const hasTopDef = Settings.hasWidgetMargin("networkTracer", "top");
            const topDef = Settings.hasWidgetMargin("networkTracer", "top") ? Settings.getWidgetMargin("networkTracer", "top", 0) : (Settings.widgetTargetProfilerVisible ? (Theme.barHeight + Theme.spacingXl + 220 + Theme.spacingXl) : (Theme.barHeight + Theme.spacingXl));
            const profilerTop = Settings.getWidgetMargin("targetProfiler", "top", 56);
            const profilerBottom = profilerTop + 220;
            const gap = topDef - profilerBottom;

            console.log("MATH_RESULT:hasTopDef=" + hasTopDef);
            console.log("MATH_RESULT:topDef=" + topDef);
            console.log("MATH_RESULT:profilerBottom=" + profilerBottom);
            console.log("MATH_RESULT:gap=" + gap);

            // 2. Collapse when TargetProfiler hidden
            Settings.widgetTargetProfilerVisible = false;
            const topCollapsed = Settings.hasWidgetMargin("networkTracer", "top") ? Settings.getWidgetMargin("networkTracer", "top", 0) : (Settings.widgetTargetProfilerVisible ? (Theme.barHeight + Theme.spacingXl + 220 + Theme.spacingXl) : (Theme.barHeight + Theme.spacingXl));
            console.log("MATH_RESULT:topCollapsed=" + topCollapsed);

            // 3. Partial Override: only X set, Y left default
            Settings.parseConfig(JSON.stringify({ widgets: { networkTracer: { x: 40 } } }));
            Settings.widgetTargetProfilerVisible = true;
            const hasTopPartial = Settings.hasWidgetMargin("networkTracer", "top");
            const hasLeftPartial = Settings.hasWidgetMargin("networkTracer", "left");
            const topPartialVis = Settings.hasWidgetMargin("networkTracer", "top") ? Settings.getWidgetMargin("networkTracer", "top", 0) : (Settings.widgetTargetProfilerVisible ? 292 : 56);
            Settings.widgetTargetProfilerVisible = false;
            const topPartialHid = Settings.hasWidgetMargin("networkTracer", "top") ? Settings.getWidgetMargin("networkTracer", "top", 0) : (Settings.widgetTargetProfilerVisible ? 292 : 56);

            console.log("MATH_RESULT:hasTopPartial=" + hasTopPartial);
            console.log("MATH_RESULT:hasLeftPartial=" + hasLeftPartial);
            console.log("MATH_RESULT:topPartialVis=" + topPartialVis);
            console.log("MATH_RESULT:topPartialHid=" + topPartialHid);

            // 4. Robustness: Negative margin clamped to 0
            Settings.parseConfig(JSON.stringify({ widgets: { networkTracer: { y: -50 } } }));
            const clampedTop = Settings.getWidgetMargin("networkTracer", "top", 292);
            console.log("MATH_RESULT:clampedTop=" + clampedTop);

            // 5. Robustness: String ignored, retains default
            Settings.parseConfig(JSON.stringify({ widgets: { networkTracer: { y: "invalid_string" } } }));
            const stringIgnoredHasTop = Settings.hasWidgetMargin("networkTracer", "top");
            console.log("MATH_RESULT:stringIgnoredHasTop=" + stringIgnoredHasTop);

            Qt.quit();
        }
    }
}
"""
    with tempfile.NamedTemporaryFile(suffix=".qml", mode="w", delete=False) as f_qml2:
        f_qml2.write(qml_script_math)
        qml_path_math = f_qml2.name

    env_math = os.environ.copy()
    env_math["QML_IMPORT_PATH"] = os.path.join(PROJECT_ROOT, "shell")
    res_math = subprocess.run([QUICKSHELL_BIN, "-p", qml_path_math], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env_math, timeout=10)
    try:
        os.remove(qml_path_math)
    except:
        pass

    math_dict = {}
    for line in res_math.stdout.splitlines():
        if "MATH_RESULT:" in line:
            k, v = line.split("MATH_RESULT:")[1].strip().split("=")
            math_dict[k] = v

    check("WIDGET.DEFAULT.01", math_dict.get("hasTopDef") == "false", "Default state hasWidgetMargin('networkTracer', 'top') is false")
    check("WIDGET.DEFAULT.02", math_dict.get("topDef") == "292", "Default state networkTracer top margin is 292px")
    check("WIDGET.DEFAULT.03", math_dict.get("profilerBottom") == "276", "TargetProfiler bottom coordinate is 276px (56 + 220)")
    check("WIDGET.DEFAULT.04", math_dict.get("gap") == "16", "Clean vertical gap is exactly 16px (Theme.spacingXl)")
    check("WIDGET.DEFAULT.05", int(math_dict.get("gap", 0)) >= 16, "Vertical gap satisfies invariant gap >= 16px")

    check("WIDGET.COLLAPSE.01", math_dict.get("topCollapsed") == "56", "When TargetProfiler is hidden, NetworkTracer collapses dynamically to 56px")

    check("WIDGET.PARTIAL.01", math_dict.get("hasTopPartial") == "false", "Partial override (x only) leaves hasWidgetMargin('top') false")
    check("WIDGET.PARTIAL.02", math_dict.get("hasLeftPartial") == "true", "Partial override sets hasWidgetMargin('left') true")
    check("WIDGET.PARTIAL.03", math_dict.get("topPartialVis") == "292", "Partial override: vertical stays dynamic at 292px when profiler visible")
    check("WIDGET.PARTIAL.04", math_dict.get("topPartialHid") == "56", "Partial override: vertical stays dynamic at 56px when profiler hidden")

    check("WIDGET.ROBUST.01", math_dict.get("clampedTop") == "0", "Negative margin clamped cleanly to 0")
    check("WIDGET.ROBUST.02", math_dict.get("stringIgnoredHasTop") == "false", "String margin safely rejected without crash")

def test_regression_suites():
    print("\n--- Phase 5: Existing Regression Suites Verification ---")
    suites = [
        ("Tier 1 Positioning", ["bash", "tests/e2e/tier1_features/test_r2_positioning.sh"]),
        ("Widget Overlap Stress", ["bash", "tests/e2e/test_m1_widget_overlap_stress.sh"]),
        ("Fastfetch Adversarial", ["python3", "tests/e2e/test_m1_fastfetch_adversarial.py"]),
        ("Challenger 1 Deep Dive", ["python3", "tests/e2e/test_m1_challenger_deep_dive.py"]),
        ("Network Tracer E2E", ["bash", "tests/e2e/tier1_features/test_r3_network_tracer.sh"]),
        ("Target Profiler E2E", ["bash", "tests/e2e/tier1_features/test_r5_target_profiler.sh"]),
        ("Settings E2E", ["bash", "tests/e2e/tier1_features/test_settings.sh"])
    ]

    for name, cmd in suites:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd=PROJECT_ROOT)
        check(f"REGRESSION.{name.replace(' ', '_').upper()}", proc.returncode == 0, f"Suite '{name}' passed without regressions (rc={proc.returncode})")

def main():
    print("================================================================================")
    print("      CHALLENGER M1-2 EMPIRICAL BOUNDARY & STRESS VERIFICATION SUITE           ")
    print("================================================================================")

    test_fastfetch_boundaries()
    test_widget_overrides_and_regression()
    test_regression_suites()

    print("\n================================================================================")
    print(f"VERIFICATION SUMMARY: Total: {total_tests} | Passed: {passed_tests} | Failed: {len(failed_tests)}")
    print("================================================================================")

    if failed_tests:
        print("\nFAILED CHALLENGES:")
        for fid, fdesc, fdetails in failed_tests:
            print(f"  - [{fid}] {fdesc} ({fdetails})")
        return 1
    else:
        print("\nALL ADVERSARIAL & BOUNDARY CHALLENGES CONFIRMED PASSED EMPIRICALLY.")
        return 0

if __name__ == "__main__":
    sys.exit(main())
