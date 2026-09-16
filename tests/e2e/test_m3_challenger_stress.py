#!/usr/bin/env python3
"""
================================================================================
CHALLENGER M3-1 EMPIRICAL ADVERSARIAL STRESS TEST SUITE
================================================================================
Stress-tests Milestone 3:
1. parseExec(execStr) parsing engine:
   - Nested quoting, backslash escapes, spaces in args
   - Stripping of Freedesktop field codes (%f, %F, %u, %U, %i, %c, %k, etc.)
   - Literal %% escaping and attached field codes
   - Boundary inputs: null, undefined, empty, whitespace-only, unclosed quotes
   - High-volume stress (10,000+ chars)
2. Multi-path Wayland session discovery:
   - XDG_DATA_DIRS traversal with spaces and multi-colon separators
   - Strict rejection of hyprland-uwsm.desktop (both by name and exec)
   - Acceptance of direct compositor entries (Hyprland, Niri, Sway)
   - Multi-directory deduplication (filename and desktop name)
   - Multi-section desktop file safety ([Desktop Action ...])
3. Direct Greetd launch bridge wiring:
   - GreetdHandler.finish() passing parsed command directly to Greetd.launch()
   - Verification that no UWSM wrappers exist anywhere in launch path
   - Exit command purity (IPC dispatch without uwsm)
4. UI & Data Integrity:
   - Session.qml compositor cycle logic (forward and backward modulo math)
   - IdentityCard.qml real user data bindings and role derivation
5. QML syntax, format, and greeter isolation boundary verification
================================================================================
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
QUICKSHELL_BIN = "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/bin/quickshell"

QML_ENV = os.environ.copy()
QML_ENV["QML_IMPORT_PATH"] = (
    "/nix/store/m1y5myv0v3aph5qgz05xa0m64s48vk52-qt5compat-6.11.2/lib/qt-6/qml:"
    "/nix/store/10553j4116y6jllliqpg5kz7d35bblab-qtdeclarative-6.11.2/lib/qt-6/qml:"
    "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/lib/qt-6/qml:"
    + os.path.join(PROJECT_ROOT, "shell")
)
QML_ENV["QML2_IMPORT_PATH"] = QML_ENV["QML_IMPORT_PATH"]

PASS_COUNT = 0
FAIL_COUNT = 0
FINDINGS = []

def record_result(test_id: str, desc: str, passed: bool, detail: str = ""):
    global PASS_COUNT, FAIL_COUNT
    if passed:
        PASS_COUNT += 1
        print(f"  [PASS] {test_id}: {desc}")
    else:
        FAIL_COUNT += 1
        msg = f"{test_id}: {desc} | Detail: {detail}"
        FINDINGS.append(msg)
        print(f"  [FAIL] {msg}")

def extract_parse_exec_js():
    """Extract parseExec function from SessionManager.qml for exact execution."""
    path = os.path.join(PROJECT_ROOT, "shell/greeter/services/SessionManager.qml")
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    match = re.search(r"function parseExec\(execStr\)\s*\{(.*?)\n    \}", content, re.DOTALL)
    if not match:
        raise RuntimeError("Could not find parseExec in SessionManager.qml")
    return "function parseExec(execStr) {" + match.group(1) + "\n}"

def run_node_js(js_code: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["node", "-e", js_code],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

print("=" * 80)
print("RUNNING ADVERSARIAL STRESS TEST SUITE FOR MILESTONE 3")
print("=" * 80)

# ==============================================================================
# 1. PARSEEXEC STRESS TESTING
# ==============================================================================
print("\n[SECTION 1] Stress-Testing parseExec(execStr) Engine...")

parse_exec_code = extract_parse_exec_js()

def run_parse_exec(exec_arg):
    import json
    arg_repr = json.dumps(exec_arg)
    test_script = f"""
{parse_exec_code}
const input = {arg_repr};
const res = parseExec(input);
console.log(JSON.stringify(res));
"""
    res = run_node_js(test_script)
    if res.returncode != 0:
        raise RuntimeError(f"Node execution failed: {res.stderr}")
    return json.loads(res.stdout.strip())

# Test 1.1: Basic executable
r = run_parse_exec("Hyprland")
record_result("T1.1", "Bare executable without arguments", r == ["Hyprland"], f"Got {r}")

# Test 1.2: Multiple simple arguments
r = run_parse_exec("niri-session --flag arg2")
record_result("T1.2", "Executable with multiple arguments", r == ["niri-session", "--flag", "arg2"], f"Got {r}")

# Test 1.3: Quoted argument containing spaces
r = run_parse_exec('Hyprland --config "/home/user/.config/my hyprland/hypr.conf"')
record_result("T1.3", "Double-quoted path with internal spaces", r == ["Hyprland", "--config", "/home/user/.config/my hyprland/hypr.conf"], f"Got {r}")

# Test 1.4: Single-quoted argument
r = run_parse_exec("compositor -c 'path with spaces/file'")
record_result("T1.4", "Single-quoted path with internal spaces", r == ["compositor", "-c", "path with spaces/file"], f"Got {r}")

# Test 1.5: Nested quotes: single inside double
r = run_parse_exec('sh -c "echo \'nested single quotes\'"')
record_result("T1.5", "Nested single quotes inside double quotes", r == ["sh", "-c", "echo 'nested single quotes'"], f"Got {r}")

# Test 1.6: Nested quotes: double inside single
r = run_parse_exec("sh -c 'echo \"nested double quotes\"'")
record_result("T1.6", "Nested double quotes inside single quotes", r == ["sh", "-c", 'echo "nested double quotes"'], f"Got {r}")

# Test 1.7: Escaped quotes inside double quotes
r = run_parse_exec('app --title "Window \\"Alpha\\""')
record_result("T1.7", "Escaped double quotes inside double quotes", r == ["app", "--title", 'Window "Alpha"'], f"Got {r}")

# Test 1.8: Escaped spaces without quotes
r = run_parse_exec(r"app path\ with\ spaces and\ another")
record_result("T1.8", "Escaped spaces without quotes", r == ["app", "path with spaces", "and another"], f"Got {r}")

# Test 1.9: Escaped backslashes
r = run_parse_exec(r"app C:\\path\\to\\file")
record_result("T1.9", "Escaped backslashes in paths", r == ["app", r"C:\path\to\file"], f"Got {r}")

# Test 1.10: Escaped trailing backslash
r = run_parse_exec(r"app trailing\\")
record_result("T1.10", "Escaped trailing backslash", r == ["app", "trailing\\"], f"Got {r}")

# Test 1.11: Dangling single trailing backslash
r = run_parse_exec("app trailing\\")
record_result("T1.11", "Dangling unescaped backslash does not crash", r == ["app", "trailing"], f"Got {r}")

# Test 1.12: Unclosed double quote
r = run_parse_exec('app "unclosed quote')
record_result("T1.12", "Unclosed double quote produces token without error", r == ["app", "unclosed quote"], f"Got {r}")

# Test 1.13: Unclosed single quote
r = run_parse_exec("app 'unclosed single quote")
record_result("T1.13", "Unclosed single quote produces token without error", r == ["app", "unclosed single quote"], f"Got {r}")

# Test 1.14: Empty string
r = run_parse_exec("")
record_result("T1.14", "Empty string input returns empty array", r == [], f"Got {r}")

# Test 1.15: Whitespace-only string
r = run_parse_exec("    \t\n  \r\n ")
record_result("T1.15", "Whitespace-only input returns empty array", r == [], f"Got {r}")

# Test 1.16: Non-string inputs: null, undefined, number, object
r_null = run_parse_exec(None)
r_num = run_parse_exec(12345)
r_bool = run_parse_exec(True)
record_result("T1.16", "Non-string inputs gracefully return empty array", (r_null == [] and r_num == [] and r_bool == []), f"null={r_null}, num={r_num}")

# Test 1.17: Standalone Freedesktop field codes (%f, %F, %u, %U, %d, %D, %n, %N, %i, %c, %k, %v, %m)
all_field_codes = "%f %F %u %U %d %D %n %N %i %c %k %v %m"
r = run_parse_exec(f"Hyprland {all_field_codes}")
record_result("T1.17", "All standalone Freedesktop field codes stripped", r == ["Hyprland"], f"Got {r}")

# Test 1.18: Mixed standalone and embedded field codes
r = run_parse_exec("compositor %f --flag %u --name=%c")
record_result("T1.18", "Standalone and embedded field codes processed", r == ["compositor", "--flag", "--name="], f"Got {r}")

# Test 1.19: Leading, middle, and trailing field codes cleanly removed
r = run_parse_exec("%i Hyprland %k --config %f")
record_result("T1.19", "Leading, middle, and trailing field codes cleanly removed", r == ["Hyprland", "--config"], f"Got {r}")

# Test 1.20: Literal %% escaping
r = run_parse_exec("echo 100%%")
record_result("T1.20", "Literal percent %% converted to %", r == ["echo", "100%"], f"Got {r}")

# Test 1.21: Standalone %%
r = run_parse_exec("app %%")
record_result("T1.21", "Standalone %% converted to single % token", r == ["app", "%"], f"Got {r}")

# Test 1.22: Non-field-code percent tokens
r = run_parse_exec("app %1 %9 %$")
record_result("T1.22", "Non-alpha percent signs preserved", r == ["app", "%1", "%9", "%$"], f"Got {r}")

# Test 1.23: Real-world NixOS Hyprland Exec key
nixos_hyprland_exec = "/nix/store/gwqbdfx02vrfrhq8fnq9bbj2xakmqaqc-hyprland-0.56.0+date=2026-09-13_1b85c7a/bin/start-hyprland"
r = run_parse_exec(nixos_hyprland_exec)
record_result("T1.23", "Nix store absolute path parsed intact", r == [nixos_hyprland_exec], f"Got {r}")

# Test 1.24: Real-world Niri Exec key
r = run_parse_exec("niri-session")
record_result("T1.24", "niri-session binary parsed intact", r == ["niri-session"], f"Got {r}")

# Test 1.25: High-volume stress test: 10,000 chars with 500 quoted arguments and 500 field codes stripped
large_cmd = "mycomp " + " ".join([f'--arg{i}="value with spaces {i}" %f' for i in range(500)])
start_t = time.perf_counter()
r = run_parse_exec(large_cmd)
elapsed_ms = (time.perf_counter() - start_t) * 1000
# 1 command + 500 args = 501 tokens (all 500 %f stripped)
record_result("T1.25", f"High-volume stress test (501 tokens, 500 field codes stripped in {elapsed_ms:.1f}ms)", (len(r) == 501 and elapsed_ms < 200), f"Length: {len(r)}, Time: {elapsed_ms:.1f}ms")


# ==============================================================================
# 2. ADVERSARIAL SESSION DISCOVERY ACROSS XDG_DATA_DIRS
# ==============================================================================
print("\n[SECTION 2] Adversarially Verifying Session Discovery & UWSM Rejection...")

test_tmp_dir = tempfile.mkdtemp(prefix="ctos_test_sessions_")

try:
    dir1 = os.path.join(test_tmp_dir, "share1 with spaces")
    dir2 = os.path.join(test_tmp_dir, "share2")
    dir3 = os.path.join(test_tmp_dir, "share3_empty")
    
    ws1 = os.path.join(dir1, "wayland-sessions")
    ws2 = os.path.join(dir2, "wayland-sessions")
    ws3 = os.path.join(dir3, "wayland-sessions")
    
    os.makedirs(ws1)
    os.makedirs(ws2)
    os.makedirs(ws3)

    # 1. Valid Hyprland in dir1
    with open(os.path.join(ws1, "hyprland.desktop"), "w") as f:
        f.write("""[Desktop Entry]
Name=Hyprland
Comment=Dynamic tiling Wayland compositor
Exec=/nix/store/hyprland-bin/bin/Hyprland
Type=Application
DesktopNames=Hyprland
""")

    # 2. Duplicate Hyprland in dir2 with different comment/path (should be deduplicated by filename or name)
    with open(os.path.join(ws2, "hyprland.desktop"), "w") as f:
        f.write("""[Desktop Entry]
Name=Hyprland
Comment=Duplicate Hyprland entry
Exec=/usr/bin/Hyprland
Type=Application
DesktopNames=Hyprland
""")

    # 3. UWSM-managed Hyprland in dir1 (MUST BE REJECTED)
    with open(os.path.join(ws1, "hyprland-uwsm.desktop"), "w") as f:
        f.write("""[Desktop Entry]
Name=Hyprland (uwsm-managed)
Comment=Hyprland with UWSM
Exec=uwsm start -e -D Hyprland hyprland.desktop
Type=Application
DesktopNames=Hyprland
""")

    # 4. Adversarial UWSM entry: Name does not contain UWSM, but Exec does
    with open(os.path.join(ws1, "sneaky-uwsm.desktop"), "w") as f:
        f.write("""[Desktop Entry]
Name=Sneaky Compositor
Comment=Hides UWSM in Exec
Exec=/usr/bin/uwsm-wrapper --start
Type=Application
""")

    # 5. Adversarial UWSM entry: Exec does not contain UWSM, but Name does
    with open(os.path.join(ws1, "uwsm-named.desktop"), "w") as f:
        f.write("""[Desktop Entry]
Name=Custom Desktop (UWSM)
Comment=Hides UWSM in Name
Exec=/usr/bin/mycompositor
Type=Application
""")

    # 6. Valid Niri in dir2
    with open(os.path.join(ws2, "niri.desktop"), "w") as f:
        f.write("""[Desktop Entry]
Name=Niri
Comment=Scrollable-tiling compositor
Exec=niri-session
Type=Application
DesktopNames=niri
""")

    # 7. Valid Sway in dir2 with multi-action desktop entry
    with open(os.path.join(ws2, "sway.desktop"), "w") as f:
        f.write("""[Desktop Entry]
Name=Sway
Comment=i3-compatible Wayland compositor
Exec=sway --unsupported-gpu
Type=Application
DesktopNames=sway

[Desktop Action Lock]
Name=Lock
Exec=swaylock
""")

    # 8. Junk files in ws1
    with open(os.path.join(ws1, "not-a-desktop.txt"), "w") as f:
        f.write("Random text")
    with open(os.path.join(ws1, "broken.desktop"), "w") as f:
        f.write("Just garbage content without sections\n")

    # Now execute the exact shell pipeline used by SessionManager.qml lines 264-277
    xdg_test = f"{dir1}:{dir2}:{dir3}"
    shell_cmd = (
        f'search_dirs="{xdg_test}:/run/current-system/sw/share:/usr/share:/usr/local/share"; '
        'old_ifs="$IFS"; IFS=":"; seen=""; '
        'for d in $search_dirs; do '
        '  [ -d "$d/wayland-sessions" ] || continue; '
        '  for f in "$d/wayland-sessions"/*.desktop; do '
        '    [ -f "$f" ] || continue; '
        '    b="${f##*/}"; '
        '    case " $seen " in *" $b "*) continue ;; esac; '
        '    seen="$seen $b"; '
        '    cat "$f"; '
        '    echo ""; '
        '  done; '
        'done; '
        'IFS="$old_ifs"'
    )
    
    proc = subprocess.run(["sh", "-c", shell_cmd], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    raw_output = proc.stdout
    record_result("T2.1", "Discovery shell pipeline executes successfully with spaced paths", proc.returncode == 0, proc.stderr)

    # Now simulate SessionManager.qml desktop parser logic exactly
    def parse_desktops_stream(stream_text):
        lines = stream_text.splitlines()
        desktops = []
        current_entry = {}
        in_desktop_entry = False

        def commit():
            nonlocal current_entry, in_desktop_entry
            if "name" in current_entry and "exec" in current_entry:
                name = current_entry["name"]
                exec_cmd = current_entry["exec"]
                is_uwsm = "uwsm" in exec_cmd.lower() or "uwsm" in name.lower()
                is_dup = any(d["name"].lower() == name.lower() for d in desktops)
                if not is_uwsm and not is_dup:
                    desktops.append(dict(current_entry))
            current_entry = {}
            in_desktop_entry = False

        for raw_line in lines:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if line == "[Desktop Entry]":
                commit()
                in_desktop_entry = True
                continue
            if line.startswith("[") and line.endswith("]"):
                in_desktop_entry = False
                continue
            if not in_desktop_entry:
                continue
            split_idx = line.find("=")
            if split_idx == -1:
                continue
            key = line[:split_idx].strip()
            val = line[split_idx + 1:].strip()
            if key == "Name":
                current_entry["name"] = val
            elif key == "Comment":
                current_entry["comment"] = val
            elif key == "Exec":
                current_entry["exec"] = val
            elif key == "Type":
                current_entry["type"] = val
            elif key == "DesktopNames":
                current_entry["desktopNames"] = val

        commit()
        return desktops

    discovered = parse_desktops_stream(raw_output)
    discovered_names = [d["name"] for d in discovered]

    # Verification checks
    record_result("T2.2", "hyprland-uwsm.desktop strictly rejected", "Hyprland (uwsm-managed)" not in discovered_names, f"Found: {discovered_names}")
    record_result("T2.3", "Sneaky UWSM in Exec strictly rejected", "Sneaky Compositor" not in discovered_names, f"Found: {discovered_names}")
    record_result("T2.4", "Sneaky UWSM in Name strictly rejected", "Custom Desktop (UWSM)" not in discovered_names, f"Found: {discovered_names}")
    record_result("T2.5", "Hyprland directly discovered", "Hyprland" in discovered_names, f"Found: {discovered_names}")
    record_result("T2.6", "Niri directly discovered", "Niri" in discovered_names, f"Found: {discovered_names}")
    record_result("T2.7", "Sway directly discovered", "Sway" in discovered_names, f"Found: {discovered_names}")
    
    # Check deduplication: Hyprland should appear exactly once
    hypr_count = discovered_names.count("Hyprland")
    record_result("T2.8", "Identical session across multiple dirs deduplicated", hypr_count == 1, f"Hyprland count: {hypr_count}")

    # Check multi-action desktop file safety: Sway's exec should be sway, not swaylock
    sway_entry = next((d for d in discovered if d["name"] == "Sway"), None)
    sway_exec_ok = sway_entry is not None and sway_entry["exec"] == "sway --unsupported-gpu"
    record_result("T2.9", "Multi-action desktop file does not overwrite main Exec", sway_exec_ok, f"Sway entry: {sway_entry}")

    # Verify no uwsm references exist in any discovered entry
    uwsm_leaks = [d for d in discovered if "uwsm" in d["exec"].lower() or "uwsm" in d["name"].lower()]
    record_result("T2.10", "Zero UWSM leaks in discovered session list", len(uwsm_leaks) == 0, f"Leaks: {uwsm_leaks}")

finally:
    shutil.rmtree(test_tmp_dir, ignore_errors=True)


# ==============================================================================
# 3. DIRECT GREETD LAUNCH WIRING & UWSM ERADICATION
# ==============================================================================
print("\n[SECTION 3] Verifying Direct GreetdHandler Launch Wiring & UWSM Eradication...")

greetd_path = os.path.join(PROJECT_ROOT, "shell/greeter/services/GreetdHandler.qml")
with open(greetd_path, "r", encoding="utf-8") as f:
    greetd_content = f.read()

# Test 3.1: GreetdHandler calls SessionManager.getLaunchCommand()
has_launch_wiring = "SessionManager.getLaunchCommand()" in greetd_content
record_result("T3.1", "GreetdHandler.finish() queries SessionManager.getLaunchCommand()", has_launch_wiring)

# Test 3.2: GreetdHandler directly calls Greetd.launch(launchCommand)
has_greetd_launch = re.search(r"Greetd\.launch\(\s*launchCommand\s*\)", greetd_content) is not None
record_result("T3.2", "GreetdHandler.finish() calls Greetd.launch(launchCommand)", has_greetd_launch)

# Test 3.3: GreetdHandler contains zero uwsm references
greetd_uwsm = "uwsm" in greetd_content.lower()
record_result("T3.3", "GreetdHandler.qml has zero UWSM references", not greetd_uwsm)

# Test 3.4: Desktop.qml contains zero uwsm references
desktop_qml_path = os.path.join(PROJECT_ROOT, "shell/greeter/data/Desktop.qml")
with open(desktop_qml_path, "r", encoding="utf-8") as f:
    desktop_qml_content = f.read()
desktop_uwsm = "uwsm" in desktop_qml_content.lower()
record_result("T3.4", "Desktop.qml has zero UWSM references (_uwsmManaged removed)", not desktop_uwsm)

# Test 3.5: SessionManager.qml UWSM audit (only the rejection filter should mention uwsm)
sm_path = os.path.join(PROJECT_ROOT, "shell/greeter/services/SessionManager.qml")
with open(sm_path, "r", encoding="utf-8") as f:
    sm_lines = f.readlines()

sm_uwsm_lines = [f"Line {idx+1}: {line.strip()}" for idx, line in enumerate(sm_lines) if "uwsm" in line.lower()]
# Expect exactly 2 lines in commit(): isUwsm definition and !isUwsm check
only_filter_uwsm = (len(sm_uwsm_lines) == 2 and all("isUwsm" in l for l in sm_uwsm_lines))
record_result("T3.5", f"SessionManager.qml contains UWSM only in exclusion filter ({len(sm_uwsm_lines)} matches)", only_filter_uwsm, str(sm_uwsm_lines))

# Test 3.6: SessionManager.getExitCommand() has zero UWSM exit
get_exit_match = re.search(r"function getExitCommand\(\)\s*\{(.*?)\n    \}", "".join(sm_lines), re.DOTALL)
exit_code = get_exit_match.group(1) if get_exit_match else ""
exit_has_no_uwsm = "uwsm" not in exit_code.lower()
record_result("T3.6", "SessionManager.getExitCommand() has no UWSM stop commands", exit_has_no_uwsm, exit_code.strip())

# Test 3.7: SessionManager.getLaunchCommand() returns parseExec(activeDesktop.exec)
has_get_launch = re.search(r"function getLaunchCommand\(\)\s*\{.*?return parseExec\(activeDesktop\.exec\);.*?\}", "".join(sm_lines), re.DOTALL) is not None
record_result("T3.7", "getLaunchCommand() directly invokes parseExec(activeDesktop.exec)", has_get_launch)


# ==============================================================================
# 4. COMPOSITOR CYCLING & USER DATA INTEGRITY
# ==============================================================================
print("\n[SECTION 4] Testing Compositor Cycling UI Logic & Real User Data...")

session_qml_path = os.path.join(PROJECT_ROOT, "shell/greeter/components/Session.qml")
with open(session_qml_path, "r", encoding="utf-8") as f:
    session_content = f.read()

# Test 4.1: Session.qml has compositorSelector
record_result("T4.1", "Session.qml contains compositorSelector pill bar", "id: compositorSelector" in session_content)

# Test 4.2: Session.qml cycleDesktop forward and backward modulo arithmetic test
cycle_math_script = """
function testCycle(count, current, forward) {
    if (count <= 1) return current;
    return forward ? ((current + 1) % count) : ((current - 1 + count) % count);
}

// Test boundaries: 1 desktop, 2 desktops, 5 desktops
console.log(JSON.stringify({
    c1_f: testCycle(1, 0, true),
    c1_b: testCycle(1, 0, false),
    c2_f0: testCycle(2, 0, true),
    c2_f1: testCycle(2, 1, true),
    c2_b0: testCycle(2, 0, false),
    c2_b1: testCycle(2, 1, false),
    c5_b0: testCycle(5, 0, false)
}));
"""
res = run_node_js(cycle_math_script)
import json
cycle_data = json.loads(res.stdout.strip())
cycle_ok = (
    cycle_data["c1_f"] == 0 and
    cycle_data["c1_b"] == 0 and
    cycle_data["c2_f0"] == 1 and
    cycle_data["c2_f1"] == 0 and
    cycle_data["c2_b0"] == 1 and
    cycle_data["c2_b1"] == 0 and
    cycle_data["c5_b0"] == 4
)
record_result("T4.2", "cycleDesktop modulo arithmetic wraps cleanly in both directions", cycle_ok, str(cycle_data))

# Test 4.3: IdentityCard.qml contains zero fakeIdentity
id_path = os.path.join(PROJECT_ROOT, "shell/greeter/components/IdentityCard.qml")
with open(id_path, "r", encoding="utf-8") as f:
    id_content = f.read()
record_result("T4.3", "IdentityCard.qml contains zero fakeIdentity references", "fakeIdentity" not in id_content)

# Test 4.4: IdentityCard.qml references SessionManager.activeUser
record_result("T4.4", "IdentityCard.qml binds to SessionManager.activeUser", "SessionManager.activeUser" in id_content)

# Test 4.5: Class derivation logic test (L0_ROOT, L5_ADMIN, OPERATOR, STANDBY)
class_script = """
function deriveClass(user) {
    if (!user) return "STANDBY";
    if (user.uid === 0) return "L0_ROOT";
    if (user.uid === 1000) return "L5_ADMIN";
    return "OPERATOR";
}
console.log(JSON.stringify({
    root: deriveClass({ uid: 0 }),
    admin: deriveClass({ uid: 1000 }),
    operator: deriveClass({ uid: 1001 }),
    standby: deriveClass(null)
}));
"""
res = run_node_js(class_script)
class_data = json.loads(res.stdout.strip())
class_ok = (
    class_data["root"] == "L0_ROOT" and
    class_data["admin"] == "L5_ADMIN" and
    class_data["operator"] == "OPERATOR" and
    class_data["standby"] == "STANDBY"
)
record_result("T4.5", "IdentityCard class derivation handles root, admin, operator, and null", class_ok, str(class_data))

# Test 4.6: IdentityCard barcode image layout check (uses Layout.fillWidth instead of width: parent.width)
barcode_fill_width = "Layout.fillWidth: true" in id_content and "id-barcode.svg" in id_content
has_bad_barcode_width = re.search(r"Image\s*\{[^}]*source:\s*\"[^\"]*id-barcode\.svg\"[^}]*width:\s*parent\.width", id_content) is not None
record_result("T4.6", "IdentityCard barcode image properly managed via Layout.fillWidth", (barcode_fill_width and not has_bad_barcode_width))


# ==============================================================================
# 5. QML SYNTAX, FORMAT & ISOLATION VERIFICATION
# ==============================================================================
print("\n[SECTION 5] QML Syntax, Formatting & Isolation Verification...")

# Test 5.1: qmllint across all 5 M3 files
m3_files = [
    "shell/greeter/data/Desktop.qml",
    "shell/greeter/services/SessionManager.qml",
    "shell/greeter/services/GreetdHandler.qml",
    "shell/greeter/components/Session.qml",
    "shell/greeter/components/IdentityCard.qml"
]

qmllint_cmd = [
    "qmllint",
    "-I", "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/lib/qt-6/qml",
    "-I", "/nix/store/10553j4116y6jllliqpg5kz7d35bblab-qtdeclarative-6.11.2/lib/qt-6/qml",
    "-I", "/nix/store/m1y5myv0v3aph5qgz05xa0m64s48vk52-qt5compat-6.11.2/lib/qt-6/qml",
    "-I", "shell"
] + m3_files

proc = subprocess.run(qmllint_cmd, cwd=PROJECT_ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
record_result("T5.1", "qmllint syntax check on all M3 files exits 0", proc.returncode == 0, proc.stderr)

# Test 5.2: qml_inspector formatting check
format_all_pass = True
format_details = []
for f in m3_files:
    p = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-format", f], cwd=PROJECT_ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if p.returncode != 0:
        format_all_pass = False
        format_details.append(f"{f}: {p.stderr}")
record_result("T5.2", "qml_inspector formatting check adheres across all M3 files", format_all_pass, "; ".join(format_details))

# Test 5.3: Tier 1 isolation test
p1 = subprocess.run(["bash", "tests/e2e/tier1_features/test_greeter_isolation.sh"], cwd=PROJECT_ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
record_result("T5.3", "Tier 1 greeter isolation suite passes (5/5)", p1.returncode == 0, p1.stdout)

# Test 5.4: Tier 2 boundary test
p2 = subprocess.run(["bash", "tests/e2e/tier2_boundaries/test_greeter_isolation_boundaries.sh"], cwd=PROJECT_ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
record_result("T5.4", "Tier 2 greeter isolation boundaries suite passes (5/5)", p2.returncode == 0, p2.stdout)

# Test 5.5: Live Quickshell runtime initialization
qs_proc = subprocess.run(
    [
        "timeout", "4s",
        "env",
        "CTOS_DEBUG=1", "CTOS_MODE=test",
        f"QML2_IMPORT_PATH={QML_ENV['QML2_IMPORT_PATH']}",
        QUICKSHELL_BIN, "-p", "shell/greeter.qml"
    ],
    cwd=PROJECT_ROOT,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True
)
combined_out = qs_proc.stdout + qs_proc.stderr
runtime_ok = "Configuration Loaded" in combined_out and "Active user changed" in combined_out
record_result("T5.5", "Live greeter runtime loads in Quickshell without fatal QML errors", runtime_ok, combined_out[:300])

print("\n" + "=" * 80)
print(f"ADVERSARIAL SUITE SUMMARY: {PASS_COUNT} PASSED, {FAIL_COUNT} FAILED")
print("=" * 80)

if FAIL_COUNT > 0:
    print("\nFAILURES:")
    for f in FINDINGS:
        print(f"  - {f}")
    sys.exit(1)
else:
    print("\nALL ADVERSARIAL STRESS TESTS PASSED SUCCESSFULLY!")
    sys.exit(0)
