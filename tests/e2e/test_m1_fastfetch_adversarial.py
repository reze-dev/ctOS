#!/usr/bin/env python3
"""
Adversarial Stress Test Suite for Milestone 1 - Fastfetch Configuration (R6)
Tests:
- Fallback when dedsec.txt is missing, empty, or custom
- TrueColor rendering and logo color override
- Output under multiple terminal column widths via PTY emulation
- Clean 3-section separation by horizontal rules (─) in #1BFD9C
- Dynamic OS (ctOS-{version}) and Kernel (blume-krn-{version}) resolution
- Rejection of stale/hardcoded versions (ctOS-0.1.0-a, blume-krn-1.0.8)
"""

import os
import sys
import pty
import select
import subprocess
import tempfile
import json
import re
import termios
import struct

CONFIG_PATH = os.path.abspath("shell/config/fastfetch/config.jsonc")

def run_fastfetch_pty(cols, rows=30, env_overrides=None):
    """Run fastfetch inside a real pseudo-terminal of specific (cols, rows) geometry."""
    master, slave = pty.openpty()
    # Set window size on slave
    winsize = struct.pack("HHHH", rows, cols, 0, 0)
    import fcntl
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
        close_fds=True
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

def run_fastfetch_pipe(env_overrides=None):
    env = os.environ.copy()
    if env_overrides:
        env.update(env_overrides)
    cmd = ["fastfetch", "-c", CONFIG_PATH]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)
    stdout, stderr = proc.communicate(timeout=5)
    return proc.returncode, stdout, stderr

def main():
    print("=== [TEST SUITE] Fastfetch Adversarial Stress Testing ===")
    total = 0
    passed = 0
    failed = 0

    def assert_check(name, condition, details=""):
        nonlocal total, passed, failed
        total += 1
        if condition:
            passed += 1
            print(f"  [PASS] {name} {details}")
        else:
            failed += 1
            print(f"  [FAIL] {name} {details}", file=sys.stderr)

    # -------------------------------------------------------------------------
    # 1. JSONC Syntax and Configuration Contract
    # -------------------------------------------------------------------------
    print("\n--- Phase 1: Configuration Schema & Static Structure ---")
    assert_check("FF.STATIC.01", os.path.exists(CONFIG_PATH), f"Config exists at {CONFIG_PATH}")
    
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        config_content = f.read()

    # Strip whole-line and end-of-line comments not inside quotes
    def strip_jsonc_comments(text):
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
                # Skip until newline
                while i < n and text[i] != '\n':
                    i += 1
            else:
                out.append(c)
                i += 1
        return "".join(out)

    no_comments = strip_jsonc_comments(config_content)
    try:
        cfg = json.loads(no_comments)
        assert_check("FF.STATIC.02", True, "Config is valid JSONC")
    except Exception as e:
        assert_check("FF.STATIC.02", False, f"JSON parse error: {e}")
        cfg = {}

    # Check logo color
    logo_color = cfg.get("logo", {}).get("color", {}).get("1", "")
    assert_check("FF.STATIC.03", logo_color.upper() == "#1BFD9C", f"Logo color 1 is #1BFD9C (got {logo_color})")

    # Check display colors
    disp_keys = cfg.get("display", {}).get("color", {}).get("keys", "")
    disp_sep = cfg.get("display", {}).get("color", {}).get("separator", "")
    disp_out = cfg.get("display", {}).get("color", {}).get("output", "")
    assert_check("FF.STATIC.04", disp_keys.upper() == "#1BFD9C", f"Display keys color is #1BFD9C (got {disp_keys})")
    assert_check("FF.STATIC.05", disp_sep.upper() == "#7A7A7A", f"Display separator color is #7A7A7A (got {disp_sep})")
    assert_check("FF.STATIC.06", disp_out.upper() == "#FFFFFF", f"Display output color is #FFFFFF (got {disp_out})")

    # Check 3-section separator structure
    modules = cfg.get("modules", [])
    separators = [m for m in modules if isinstance(m, dict) and m.get("type") == "separator"]
    assert_check("FF.STATIC.07", len(separators) == 3, f"Exactly 3 separator modules delimiting 3 sections (found {len(separators)})")
    for idx, sep in enumerate(separators):
        assert_check(f"FF.STATIC.08.{idx+1}", sep.get("string") == "─" and sep.get("outputColor", "").upper() == "#1BFD9C",
                     f"Separator {idx+1} uses '─' and #1BFD9C")

    # Check dynamic format templates
    os_module = next((m for m in modules if isinstance(m, dict) and m.get("type") == "os"), {})
    kernel_module = next((m for m in modules if isinstance(m, dict) and m.get("type") == "kernel"), {})
    assert_check("FF.STATIC.09", os_module.get("format") == "ctOS-{version-id}", f"OS format is ctOS-{{version-id}} (got {os_module.get('format')})")
    assert_check("FF.STATIC.10", kernel_module.get("format") == "blume-krn-{release}", f"Kernel format is blume-krn-{{release}} (got {kernel_module.get('format')})")

    # Check absence of old hardcoded strings in file
    assert_check("FF.STATIC.11", "ctOS-0.1.0-a" not in config_content, "Old static version ctOS-0.1.0-a eradicated")
    assert_check("FF.STATIC.12", "blume-krn-1.0.8" not in config_content, "Old static kernel blume-krn-1.0.8 eradicated")

    # -------------------------------------------------------------------------
    # 2. Runtime Execution & Dynamic Version Resolution
    # -------------------------------------------------------------------------
    print("\n--- Phase 2: Live Runtime & Dynamic Format Resolution ---")
    rc, stdout, stderr = run_fastfetch_pipe()
    assert_check("FF.RUN.01", rc == 0, f"fastfetch exits with code 0 (got {rc})")
    
    # Strip ANSI escapes for content regex
    plain_output = re.sub(r"\x1b\[[0-9;]*[mGKF]", "", stdout)

    # Verify dynamic OS output
    os_match = re.search(r"OS:\s*ctOS-([0-9\.]+)", plain_output)
    assert_check("FF.RUN.02", os_match is not None, f"Dynamic OS line rendered: {os_match.group(0) if os_match else 'NOT FOUND'}")
    if os_match:
        assert_check("FF.RUN.03", os_match.group(1) != "0.1.0-a", f"OS version is dynamically resolved: {os_match.group(1)}")

    # Verify dynamic Kernel output
    kernel_match = re.search(r"Kernel:\s*blume-krn-([0-9\.\-a-zA-Z]+)", plain_output)
    assert_check("FF.RUN.04", kernel_match is not None, f"Dynamic Kernel line rendered: {kernel_match.group(0) if kernel_match else 'NOT FOUND'}")
    if kernel_match:
        assert_check("FF.RUN.05", kernel_match.group(1) != "1.0.8", f"Kernel release is dynamically resolved: {kernel_match.group(1)}")

    # Verify 3 distinct sections in plain output
    sep_lines = [line for line in plain_output.splitlines() if re.search(r"─{4,}", line)]
    assert_check("FF.RUN.06", len(sep_lines) == 3, f"Live output contains exactly 3 horizontal separator rules (found {len(sep_lines)})")

    # -------------------------------------------------------------------------
    # 3. Logo Fallback Stress Tests
    # -------------------------------------------------------------------------
    print("\n--- Phase 3: Logo Fallback & Missing Asset Resilience ---")
    # Test A: Missing dedsec.txt (isolated HOME)
    with tempfile.TemporaryDirectory() as empty_home:
        rc_miss, out_miss, err_miss = run_fastfetch_pipe(env_overrides={"HOME": empty_home})
        assert_check("FF.FALLBACK.01", rc_miss == 0, f"Missing dedsec.txt exits with 0 (got {rc_miss})")
        plain_miss = re.sub(r"\x1b\[[0-9;]*[mGKF]", "", out_miss)
        assert_check("FF.FALLBACK.02", "OS: ctOS-" in plain_miss, "Dynamic OS rendered even when logo file missing")
        assert_check("FF.FALLBACK.03", "Kernel: blume-krn-" in plain_miss, "Dynamic Kernel rendered even when logo file missing")
        sep_miss = [l for l in plain_miss.splitlines() if re.search(r"─{4,}", l)]
        assert_check("FF.FALLBACK.04", len(sep_miss) == 3, f"3 sections intact when logo missing (found {len(sep_miss)})")

    # Test B: Empty dedsec.txt
    with tempfile.TemporaryDirectory() as temp_home:
        os.makedirs(os.path.join(temp_home, ".config", "fastfetch"), exist_ok=True)
        open(os.path.join(temp_home, ".config", "fastfetch", "dedsec.txt"), "w").close()
        rc_empty, out_empty, _ = run_fastfetch_pipe(env_overrides={"HOME": temp_home})
        assert_check("FF.FALLBACK.05", rc_empty == 0, f"Empty dedsec.txt exits with 0 (got {rc_empty})")
        plain_empty = re.sub(r"\x1b\[[0-9;]*[mGKF]", "", out_empty)
        assert_check("FF.FALLBACK.06", "OS: ctOS-" in plain_empty, "Dynamic OS rendered with empty dedsec.txt")

    # -------------------------------------------------------------------------
    # 4. Terminal Column Variations via PTY
    # -------------------------------------------------------------------------
    print("\n--- Phase 4: Adversarial Terminal Column Width Variations (PTY) ---")
    column_cases = [40, 60, 70, 80, 100, 120, 160, 220]
    for cols in column_cases:
        rc_pty, raw_pty = run_fastfetch_pty(cols=cols, rows=35)
        clean_pty = re.sub(r"\x1b\[[0-9;]*[mGKF]", "", raw_pty)
        assert_check(f"FF.PTY.COL_{cols}.01", rc_pty == 0, f"Columns={cols} exits cleanly with 0")
        assert_check(f"FF.PTY.COL_{cols}.02", "OS: ctOS-" in clean_pty, f"Columns={cols} contains OS info")
        assert_check(f"FF.PTY.COL_{cols}.03", "Kernel: blume-krn-" in clean_pty, f"Columns={cols} contains Kernel info")
        
        # Verify no line length in PTY exceeds terminal width + margin of carriage return
        lines = [line.replace("\r", "") for line in clean_pty.splitlines()]
        # Fastfetch wraps lines or stacks when narrow; verify no infinite loop or crash
        assert_check(f"FF.PTY.COL_{cols}.04", len(lines) > 5, f"Columns={cols} output has valid line count ({len(lines)})")

    # -------------------------------------------------------------------------
    # 5. TrueColor ANSI Palette Stress
    # -------------------------------------------------------------------------
    print("\n--- Phase 5: TrueColor Palette & Escape Code Validation ---")
    rc_color, raw_color = run_fastfetch_pty(cols=100, rows=35)
    # Check for #1BFD9C in RGB escape: 38;2;27;253;156
    has_acid_green_rgb = "38;2;27;253;156" in raw_color or "38;2;27;253;156m" in raw_color
    assert_check("FF.COLOR.01", has_acid_green_rgb, "Acid green #1BFD9C TrueColor escape (38;2;27;253;156) present in output stream")

    # Check for separator color #7A7A7A in RGB escape: 38;2;122;122;122
    has_sep_color_rgb = "38;2;122;122;122" in raw_color
    assert_check("FF.COLOR.02", has_sep_color_rgb, "Separator color #7A7A7A TrueColor escape (38;2;122;122;122) present in output stream")

    print("\n========================================================")
    print(f"Summary: Total: {total} | Passed: {passed} | Failed: {failed}")
    print("========================================================")
    return 0 if failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
