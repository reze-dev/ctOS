#!/usr/bin/env python3
"""
================================================================================
CHALLENGER M2-2 EMPIRICAL BOUNDARY, EDGE-CASE & REGRESSION STRESS SUITE
================================================================================
Performs empirical stress testing on Milestone 2:
- Missing and corrupted asset fallbacks (lock.png: missing, 0-byte, corrupt, 1x1)
- Font fallback resilience and fontconfig resolution (Maple Mono vs fallbacks)
- GaussianBlur parameter bounds, aspect ratio scaling, and QML syntax verification
- Wayland compositor cursor environment configurations (Hyprland, Niri, NixOS)
- Greeter boundary isolation (Tiers 1, 2, 4)
- M1 regression verification
- Git repository state invariants
"""

import base64
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
LOCK_PNG_PATH = os.path.join(PROJECT_ROOT, "shell/greeter/resources/lock.png")
GREETER_QML_PATH = os.path.join(PROJECT_ROOT, "shell/greeter.qml")
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

def record_result(test_id: str, desc: str, passed: bool, detail: str = ""):
    global PASS_COUNT, FAIL_COUNT
    if passed:
        PASS_COUNT += 1
        print(f"  [PASS] {test_id}: {desc}")
    else:
        FAIL_COUNT += 1
        print(f"  [FAIL] {test_id}: {desc} | Detail: {detail}")

def sha256_file(filepath: str) -> str:
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

class CmdResult:
    def __init__(self, returncode, stdout, stderr):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr

def run_cmd(cmd, env=None, cwd=PROJECT_ROOT, timeout=10):
    try:
        proc = subprocess.run(
            cmd,
            cwd=cwd,
            env=env or os.environ,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout
        )
        return CmdResult(proc.returncode, proc.stdout, proc.stderr)
    except subprocess.TimeoutExpired as exc:
        stdout_str = exc.stdout.decode("utf-8", errors="replace") if isinstance(exc.stdout, bytes) else (exc.stdout or "")
        stderr_str = exc.stderr.decode("utf-8", errors="replace") if isinstance(exc.stderr, bytes) else (exc.stderr or "")
        return CmdResult(124, stdout_str, stderr_str)

print("================================================================================")
print("     CHALLENGER M2-2 EMPIRICAL BOUNDARY & REGRESSION STRESS TEST SUITE          ")
print("================================================================================")

# ------------------------------------------------------------------------------
# Phase 1: Missing & Corrupted Wallpaper Asset Resilience
# ------------------------------------------------------------------------------
print("\n--- Phase 1: Missing & Corrupted Wallpaper Asset Resilience (lock.png) ---")

original_sha256 = sha256_file(LOCK_PNG_PATH)
backup_path = LOCK_PNG_PATH + ".challenger_bak"
shutil.copy2(LOCK_PNG_PATH, backup_path)

try:
    # 1.1 Missing lock.png
    os.remove(LOCK_PNG_PATH)
    res_missing = run_cmd(
        [QUICKSHELL_BIN, "-p", GREETER_QML_PATH],
        env=QML_ENV,
        timeout=3
    )
    # QuickShell is long-running, so timeout (rc 124) or rc 0 is expected; NOT 134 (abort) or 139 (segfault)
    clean_exit = res_missing.returncode in (0, 124)
    warn_logged = "Cannot open" in res_missing.stdout or "Cannot open" in res_missing.stderr
    config_loaded = "Configuration Loaded" in res_missing.stdout or "Configuration Loaded" in res_missing.stderr
    record_result(
        "M2.ASSET.01",
        "Missing lock.png: Quickshell does not crash or abort (exit code in {0, 124})",
        clean_exit,
        f"rc={res_missing.returncode}"
    )
    record_result(
        "M2.ASSET.02",
        "Missing lock.png: Graceful warning logged and configuration successfully loaded",
        warn_logged and config_loaded,
        f"warn={warn_logged}, loaded={config_loaded}"
    )

    # 1.2 Empty 0-byte lock.png
    with open(LOCK_PNG_PATH, "wb") as f:
        pass
    res_empty = run_cmd(
        [QUICKSHELL_BIN, "-p", GREETER_QML_PATH],
        env=QML_ENV,
        timeout=3
    )
    clean_exit_empty = res_empty.returncode in (0, 124)
    format_warn = "Unsupported image format" in res_empty.stdout or "Unsupported image format" in res_empty.stderr
    record_result(
        "M2.ASSET.03",
        "0-byte lock.png: Handled cleanly without process crash or panic",
        clean_exit_empty,
        f"rc={res_empty.returncode}"
    )
    record_result(
        "M2.ASSET.04",
        "0-byte lock.png: Image decoder rejects malformed format gracefully",
        format_warn,
        f"warn={format_warn}"
    )

    # 1.3 Corrupted random byte stream
    with open(LOCK_PNG_PATH, "wb") as f:
        f.write(os.urandom(2048))
    res_corrupt = run_cmd(
        [QUICKSHELL_BIN, "-p", GREETER_QML_PATH],
        env=QML_ENV,
        timeout=3
    )
    clean_exit_corrupt = res_corrupt.returncode in (0, 124)
    record_result(
        "M2.ASSET.05",
        "Corrupted lock.png: Handled cleanly without process crash or panic",
        clean_exit_corrupt,
        f"rc={res_corrupt.returncode}"
    )

    # 1.4 Valid 1x1 PNG asset
    tiny_png_bytes = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==")
    with open(LOCK_PNG_PATH, "wb") as f:
        f.write(tiny_png_bytes)
    res_tiny = run_cmd(
        [QUICKSHELL_BIN, "-p", GREETER_QML_PATH],
        env=QML_ENV,
        timeout=3
    )
    clean_exit_tiny = res_tiny.returncode in (0, 124)
    loaded_tiny = "Configuration Loaded" in res_tiny.stdout or "Configuration Loaded" in res_tiny.stderr
    record_result(
        "M2.ASSET.06",
        "1x1 PNG: PreserveAspectCrop & GaussianBlur execute cleanly without arithmetic fault",
        clean_exit_tiny and loaded_tiny,
        f"rc={res_tiny.returncode}, loaded={loaded_tiny}"
    )

finally:
    # Restore original file
    if os.path.exists(backup_path):
        shutil.copy2(backup_path, LOCK_PNG_PATH)
        os.remove(backup_path)

restored_sha256 = sha256_file(LOCK_PNG_PATH)
record_result(
    "M2.ASSET.07",
    "Asset recovery: original lock.png byte-for-byte restored (SHA256 verified)",
    restored_sha256 == original_sha256,
    f"expected={original_sha256}, got={restored_sha256}"
)


# ------------------------------------------------------------------------------
# Phase 2: Font Fallback and Fontconfig Resolution
# ------------------------------------------------------------------------------
print("\n--- Phase 2: Font Fallback and Fontconfig Resolution ---")

# 2.1 Host fc-match for Maple Mono
res_fc_maple = run_cmd(["fc-match", "Maple Mono"])
has_maple = "Maple" in res_fc_maple.stdout
record_result(
    "M2.FONT.01",
    "Fontconfig: 'Maple Mono' matches system Maple Mono font file",
    res_fc_maple.returncode == 0 and has_maple,
    f"match={res_fc_maple.stdout.strip()}"
)

# 2.2 Fontconfig fallback for non-existent font
res_fc_fallback = run_cmd(["fc-match", "NonExistentCyberpunkFont"])
has_fallback = len(res_fc_fallback.stdout.strip()) > 0
record_result(
    "M2.FONT.02",
    "Fontconfig: non-existent font name falls back gracefully to system font without error",
    res_fc_fallback.returncode == 0 and has_fallback,
    f"match={res_fc_fallback.stdout.strip()}"
)

# 2.3 GeneralDto.qml fontFamily
general_dto_path = os.path.join(PROJECT_ROOT, "shell/greeter/config/GeneralDto.qml")
with open(general_dto_path) as f:
    dto_content = f.read()
record_result(
    "M2.FONT.03",
    "GeneralDto.qml: defines property string fontFamily = 'Maple Mono'",
    'property string fontFamily: "Maple Mono"' in dto_content
)

# 2.4 Theme.qml fontFamily
theme_qml_path = os.path.join(PROJECT_ROOT, "shell/greeter/common/Theme.qml")
with open(theme_qml_path) as f:
    theme_content = f.read()
record_result(
    "M2.FONT.04",
    "shell/greeter/common/Theme.qml: defines property string fontFamily = 'Maple Mono'",
    'property string fontFamily: "Maple Mono"' in theme_content
)

# 2.5 Zero JetBrainsMono occurrences
res_grep_jbm = run_cmd(["grep", "-rn", "JetBrainsMono", "shell/greeter", "modules/features/desktop/greeter.nix"])
record_result(
    "M2.FONT.05",
    "Eradication: zero occurrences of 'JetBrainsMono' across greeter, common, and greeter.nix",
    res_grep_jbm.returncode == 1,
    f"matches={res_grep_jbm.stdout.strip()}"
)


# ------------------------------------------------------------------------------
# Phase 3: GaussianBlur & Visual Shading Boundary Stress
# ------------------------------------------------------------------------------
print("\n--- Phase 3: GaussianBlur & Visual Shading Boundary Stress ---")

main_layout_path = os.path.join(PROJECT_ROOT, "shell/greeter/components/MainLayout.qml")
with open(main_layout_path) as f:
    layout_content = f.read()

record_result(
    "M2.BLUR.01",
    "MainLayout.qml: imports Qt5Compat.GraphicalEffects",
    "import Qt5Compat.GraphicalEffects" in layout_content
)
record_result(
    "M2.BLUR.02",
    "MainLayout.qml: backgroundImage sets visible: false (suppresses raw raster pass)",
    "visible: false" in layout_content
)
record_result(
    "M2.BLUR.03",
    "MainLayout.qml: backgroundImage sets fillMode: Image.PreserveAspectCrop",
    "fillMode: Image.PreserveAspectCrop" in layout_content
)
record_result(
    "M2.BLUR.04",
    "MainLayout.qml: GaussianBlur sets source: backgroundImage",
    "source: backgroundImage" in layout_content
)

m_radius = re.search(r'radius:\s*(\d+)', layout_content)
radius_val = int(m_radius.group(1)) if m_radius else -1
record_result(
    "M2.BLUR.05",
    f"MainLayout.qml: GaussianBlur radius {radius_val} is within specified bounds [48, 64]",
    48 <= radius_val <= 64,
    f"radius={radius_val}"
)

m_samples = re.search(r'samples:\s*(\d+)', layout_content)
samples_val = int(m_samples.group(1)) if m_samples else -1
record_result(
    "M2.BLUR.06",
    f"MainLayout.qml: GaussianBlur samples {samples_val} is >= 16",
    samples_val >= 16,
    f"samples={samples_val}"
)

record_result(
    "M2.BLUR.07",
    "MainLayout.qml: GaussianBlur sets cached: true for one-time FBO render pass",
    "cached: true" in layout_content
)

record_result(
    "M2.BLUR.08",
    "MainLayout.qml: frostedTint Rectangle applies '#18000000' veil",
    'color: "#18000000"' in layout_content
)

qmllint_cmd = [
    "qmllint",
    "-I", "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/lib/qt-6/qml",
    "-I", "/nix/store/10553j4116y6jllliqpg5kz7d35bblab-qtdeclarative-6.11.2/lib/qt-6/qml",
    "-I", "/nix/store/m1y5myv0v3aph5qgz05xa0m64s48vk52-qt5compat-6.11.2/lib/qt-6/qml",
    "-I", "shell",
    main_layout_path,
    general_dto_path,
    theme_qml_path
]
res_qmllint = run_cmd(qmllint_cmd)
record_result(
    "M2.BLUR.09",
    "qmllint: validates MainLayout.qml, GeneralDto.qml, and Theme.qml with 0 errors",
    res_qmllint.returncode == 0,
    f"stderr={res_qmllint.stderr.strip()}"
)

res_format = run_cmd(["python3", "tests/e2e/harness/qml_inspector.py", "check-format", main_layout_path])
record_result(
    "M2.BLUR.10",
    "qml_inspector: validates code formatting of MainLayout.qml",
    res_format.returncode == 0
)


# ------------------------------------------------------------------------------
# Phase 4: Compositor & Cursor Enforcement
# ------------------------------------------------------------------------------
print("\n--- Phase 4: Compositor & Cursor Enforcement ---")

hypr_conf_path = os.path.join(PROJECT_ROOT, "shell/greeter/examples/greeter.hyprland.conf")
with open(hypr_conf_path) as f:
    hypr_content = f.read()

record_result(
    "M2.CUR.01",
    "greeter.hyprland.conf: exports XCURSOR_THEME=Bibata-Modern-Classic",
    "env = XCURSOR_THEME,Bibata-Modern-Classic" in hypr_content
)
record_result(
    "M2.CUR.02",
    "greeter.hyprland.conf: exports XCURSOR_SIZE=24",
    "env = XCURSOR_SIZE,24" in hypr_content
)
record_result(
    "M2.CUR.03",
    "greeter.hyprland.conf: exports HYPRCURSOR_THEME=Bibata-Modern-Classic",
    "env = HYPRCURSOR_THEME,Bibata-Modern-Classic" in hypr_content
)
record_result(
    "M2.CUR.04",
    "greeter.hyprland.conf: exports HYPRCURSOR_SIZE=24",
    "env = HYPRCURSOR_SIZE,24" in hypr_content
)
record_result(
    "M2.CUR.05",
    "greeter.hyprland.conf: executes 'hyprctl setcursor Bibata-Modern-Classic 24'",
    "exec-once = hyprctl setcursor Bibata-Modern-Classic 24" in hypr_content
)

niri_conf_path = os.path.join(PROJECT_ROOT, "shell/greeter/examples/greeter.niri.kdl")
with open(niri_conf_path) as f:
    niri_content = f.read()

res_niri = run_cmd(["niri", "validate", "-c", niri_conf_path])
record_result(
    "M2.CUR.06",
    "niri validate: validates greeter.niri.kdl successfully (rc=0)",
    res_niri.returncode == 0,
    f"stderr={res_niri.stderr.strip()}"
)
record_result(
    "M2.CUR.07",
    "greeter.niri.kdl: environment block configures XCURSOR_THEME 'Bibata-Modern-Classic' and XCURSOR_SIZE '24'",
    'XCURSOR_THEME "Bibata-Modern-Classic"' in niri_content and 'XCURSOR_SIZE "24"' in niri_content
)
record_result(
    "M2.CUR.08",
    "greeter.niri.kdl: cursor block configures xcursor-theme 'Bibata-Modern-Classic' and xcursor-size 24",
    'xcursor-theme "Bibata-Modern-Classic"' in niri_content and 'xcursor-size 24' in niri_content
)

greeter_nix_path = os.path.join(PROJECT_ROOT, "modules/features/desktop/greeter.nix")
with open(greeter_nix_path) as f:
    nix_content = f.read()

res_nix_parse = run_cmd(["nix-instantiate", "--parse", greeter_nix_path])
record_result(
    "M2.CUR.09",
    "nix-instantiate: greeter.nix AST parses cleanly (rc=0)",
    res_nix_parse.returncode == 0,
    f"stderr={res_nix_parse.stderr.strip()}"
)
record_result(
    "M2.CUR.10",
    "greeter.nix: cage launcher script exports cursor environment variables",
    ("export XCURSOR_THEME=Bibata-Modern-Classic" in nix_content and
     "export XCURSOR_SIZE=24" in nix_content and
     "export HYPRCURSOR_THEME=Bibata-Modern-Classic" in nix_content and
     "export HYPRCURSOR_SIZE=24" in nix_content)
)
record_result(
    "M2.CUR.11",
    "greeter.nix: cage launcher script exports XCURSOR_PATH and XDG_DATA_DIRS with bibata-cursors",
    ('export XCURSOR_PATH="${pkgs.bibata-cursors}/share/icons' in nix_content and
     'export XDG_DATA_DIRS="${pkgs.bibata-cursors}/share' in nix_content)
)
record_result(
    "M2.CUR.12",
    "greeter.nix: environment.systemPackages includes pkgs.bibata-cursors and pkgs.kdePackages.qt5compat",
    "environment.systemPackages = [ pkgs.bibata-cursors pkgs.kdePackages.qt5compat ];" in nix_content
)
record_result(
    "M2.CUR.13",
    "greeter.nix: runtime config.json sets fontFamily = 'Maple Mono'",
    'fontFamily = "Maple Mono";' in nix_content
)

res_bibata_eval = run_cmd(["nix-instantiate", "--eval", "-E", "with import <nixpkgs> {}; bibata-cursors.name"])
record_result(
    "M2.CUR.14",
    "Nixpkgs: pkgs.bibata-cursors evaluates to valid package derivation",
    res_bibata_eval.returncode == 0 and "bibata-cursors" in res_bibata_eval.stdout,
    f"eval={res_bibata_eval.stdout.strip()}"
)


# ------------------------------------------------------------------------------
# Phase 5: Boundary & Regression Suites
# ------------------------------------------------------------------------------
print("\n--- Phase 5: Boundary & Regression Suites ---")

res_t1 = run_cmd(["bash", "tests/e2e/tier1_features/test_greeter_isolation.sh"])
record_result(
    "M2.ISO.01",
    "Tier 1 Greeter Isolation: passes with 0 failures",
    res_t1.returncode == 0,
    f"rc={res_t1.returncode}"
)

res_t2 = run_cmd(["bash", "tests/e2e/tier2_boundaries/test_greeter_isolation_boundaries.sh"])
record_result(
    "M2.ISO.02",
    "Tier 2 Greeter Isolation Boundaries: passes with 0 failures",
    res_t2.returncode == 0,
    f"rc={res_t2.returncode}"
)

res_t4 = run_cmd(["bash", "tests/e2e/tier4_real_world/test_greeter_isolation_audit.sh"])
record_result(
    "M2.ISO.03",
    "Tier 4 Greeter Isolation Audit: passes with 0 failures",
    res_t4.returncode == 0,
    f"rc={res_t4.returncode}"
)

res_m1_ff = run_cmd(["python3", "tests/e2e/test_m1_fastfetch_adversarial.py"])
record_result(
    "M2.REG.01",
    "M1 Regression: Fastfetch Adversarial suite passes 60/60 tests",
    res_m1_ff.returncode == 0,
    f"rc={res_m1_ff.returncode}"
)

res_m1_wo = run_cmd(["bash", "tests/e2e/test_m1_widget_overlap_stress.sh"])
record_result(
    "M2.REG.02",
    "M1 Regression: Widget Overlap Stress suite passes 19/19 tests",
    res_m1_wo.returncode == 0,
    f"rc={res_m1_wo.returncode}"
)


# ------------------------------------------------------------------------------
# Phase 6: Git Constraints & State Invariants
# ------------------------------------------------------------------------------
print("\n--- Phase 6: Git Constraints & State Invariants ---")

res_git_log = run_cmd(["git", "log", "-1", "--format=%s"])
latest_commit = res_git_log.stdout.strip()
record_result(
    "M2.GIT.01",
    f"Git Invariant: HEAD commit is unchanged ('{latest_commit}')",
    latest_commit == "config(hyprland): change gap thickness",
    f"HEAD={latest_commit}"
)

res_git_staged = run_cmd(["git", "diff", "--name-only", "--cached"])
staged_files = sorted(res_git_staged.stdout.strip().splitlines())
expected_staged = [
    "shell/config/fastfetch/config.jsonc",
    "shell/desktop/core/Settings.qml",
    "shell/shell.qml"
]
record_result(
    "M2.GIT.02",
    "Git Invariant: Milestone 1 files remain staged in git index",
    staged_files == expected_staged,
    f"staged={staged_files}"
)

res_git_unstaged = run_cmd(["git", "diff", "--name-only"])
unstaged_files = sorted(res_git_unstaged.stdout.strip().splitlines())
expected_unstaged = [
    "modules/features/desktop/greeter.nix",
    "shell/greeter/common/Theme.qml",
    "shell/greeter/README.md",
    "shell/greeter/components/MainLayout.qml",
    "shell/greeter/config/GeneralDto.qml",
    "shell/greeter/examples/greeter.hyprland.conf",
    "shell/greeter/examples/greeter.niri.kdl"
]
record_result(
    "M2.GIT.03",
    "Git Invariant: Exactly 7 Milestone 2 files modified in working tree (unstaged)",
    unstaged_files == expected_unstaged,
    f"unstaged={unstaged_files}"
)

res_git_agents = run_cmd(["git", "status", "--porcelain"])
agents_untracked = ".agents/" in res_git_agents.stdout and not any(
    line.startswith(("M  .agents", "A  .agents", "D  .agents"))
    for line in res_git_agents.stdout.splitlines()
)
record_result(
    "M2.GIT.04",
    "Git Invariant: .agents/ directory is untracked and not staged",
    agents_untracked,
    "status check"
)


# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
print("\n================================================================================")
total_tests = PASS_COUNT + FAIL_COUNT
print(f"STRESS HARNESS SUMMARY: Total: {total_tests} | Passed: {PASS_COUNT} | Failed: {FAIL_COUNT}")
print("================================================================================")

if FAIL_COUNT > 0:
    print(f"\n[VERDICT: REJECT] Milestone 2 failed {FAIL_COUNT} stress tests.")
    sys.exit(1)
else:
    print("\n[VERDICT: APPROVE] Milestone 2 PASSED all empirical boundary, edge-case & regression tests.")
    sys.exit(0)
