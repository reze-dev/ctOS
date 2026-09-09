#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature R1: Plymouth Splash Screen Refactor
# Requirements: ORIGINAL_REQUEST §R1, PROJECT.md
# Verifies zero Image.Text calls inside refresh_callback, log_images pre-rendering,
# native Plymouth C parser AST validation, and Nix derivation packaging.
# ==============================================================================
set -u
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"

PLYMOUTH_DIR="${PROJECT_ROOT}/assets/ctos-plymouth"
SCRIPT_FILE="${PLYMOUTH_DIR}/ctos.script"
METADATA_FILE="${PLYMOUTH_DIR}/ctos.plymouth"

# ------------------------------------------------------------------------------
# R1.01: File Existence & Theme Metadata
# ------------------------------------------------------------------------------
test_case "R1.01" "Plymouth Refactor: ctos.script and metadata exist in assets/ctos-plymouth/"
assert_file_exists "${SCRIPT_FILE}" "assets/ctos-plymouth/ctos.script required"
assert_file_exists "${METADATA_FILE}" "assets/ctos-plymouth/ctos.plymouth metadata required"
assert_grep "ModuleName=script" "${METADATA_FILE}" "Plymouth theme must declare ModuleName=script"
assert_grep "ScriptFile=.*/ctos\.script" "${METADATA_FILE}" "Plymouth theme must point to ctos.script"

# ------------------------------------------------------------------------------
# R1.02: Native Plymouth C Parser AST Validation
# ------------------------------------------------------------------------------
test_case "R1.02" "Plymouth Refactor: Native Plymouth C AST parses with zero syntax errors"
python3 -c "
import sys, os, glob, ctypes

def find_script_so():
    candidates = glob.glob('/nix/store/*plymouth*/lib/plymouth/script.so')
    if candidates:
        return candidates[0]
    for p in ['/usr/lib/plymouth/script.so', '/usr/lib64/plymouth/script.so']:
        if os.path.exists(p):
            return p
    return None

lib_path = find_script_so()
if not lib_path:
    # If script.so not in standard paths, skip dynamic C parse
    sys.exit(0)

lib = ctypes.CDLL(lib_path)
lib.script_parse_file.argtypes = [ctypes.c_char_p]
lib.script_parse_file.restype = ctypes.c_void_p

ast = lib.script_parse_file('${SCRIPT_FILE}'.encode('utf-8'))
if not ast:
    sys.exit(1)
sys.exit(0)
" || assert_eq "0" "1" "script_parse_file returned NULL indicating C parser syntax error"

# ------------------------------------------------------------------------------
# R1.03: Zero Image.Text Inside refresh_callback Loop
# ------------------------------------------------------------------------------
test_case "R1.03" "Plymouth Refactor: Exactly zero Image.Text() calls inside refresh_callback loop"
if [[ -f "${SCRIPT_FILE}" ]]; then
    count=$(python3 -c "
with open('${SCRIPT_FILE}', 'r', encoding='utf-8') as f:
    text = f.read()
start = text.find('fun refresh_callback')
if start == -1:
    print('-1')
    sys.exit(0)
end = text.find('Plymouth.SetRefreshFunction', start)
if end == -1:
    end = len(text)
body = text[start:end]
print(body.count('Image.Text'))
")
    assert_eq "0" "${count}" "Image.Text() found inside refresh_callback loop (count must be 0)"
else
    assert_file_exists "${SCRIPT_FILE}"
fi

# ------------------------------------------------------------------------------
# R1.04: Pre-rendered log_images Array Outside Animation Loop
# ------------------------------------------------------------------------------
test_case "R1.04" "Plymouth Refactor: log_images array pre-rendered across 13 log lines outside loop"
if [[ -f "${SCRIPT_FILE}" ]]; then
    # Must declare log_images array and pre-render loop before refresh_callback
    assert_grep "log_images\s*=\s*\[\];" "${SCRIPT_FILE}" "Must initialize log_images array"
    assert_grep "for\s*\(\s*i\s*=\s*0;\s*i\s*<\s*13;\s*i\+\+\s*\)" "${SCRIPT_FILE}" "Must pre-render 13 log lines in init loop"
    assert_grep "log_images\[i\]\s*=\s*Image\.Text\(" "${SCRIPT_FILE}" "Must assign Image.Text to log_images[i]"
else
    assert_file_exists "${SCRIPT_FILE}"
fi

# ------------------------------------------------------------------------------
# R1.05: Sprite Image Pointer Updates in refresh_callback
# ------------------------------------------------------------------------------
test_case "R1.05" "Plymouth Refactor: Sprite image updates use log_images index and empty_image fallback"
if [[ -f "${SCRIPT_FILE}" ]]; then
    assert_grep "log_sprites\[i\]\.SetImage\(log_images\[line_idx\]\)" "${SCRIPT_FILE}" "Sprites must update image pointer to log_images"
    assert_grep "log_sprites\[i\]\.SetImage\(empty_image\)" "${SCRIPT_FILE}" "Sprites must fall back to pre-rendered empty_image"
else
    assert_file_exists "${SCRIPT_FILE}"
fi

# ------------------------------------------------------------------------------
# R1.06: Syntax Safety: Zero Unsupported Logical Operators in Script
# ------------------------------------------------------------------------------
test_case "R1.06" "Plymouth Refactor: Zero unsupported boolean operators (&&, ||) in conditionals"
if [[ -f "${SCRIPT_FILE}" ]]; then
    # Plymouth script does not support && or || in if expressions; nested ifs must be used
    assert_not_grep "if\s*\([^)]*(&&|\|\|)[^)]*\)" "${SCRIPT_FILE}" "Plymouth script does not support && or || inside if conditionals"
else
    assert_file_exists "${SCRIPT_FILE}"
fi

# ------------------------------------------------------------------------------
# R1.07: Nix Package Derivation Build Verification
# ------------------------------------------------------------------------------
test_case "R1.07" "Plymouth Refactor: Plymouth theme derivation packages cleanly with nix"
if command -v nix-build >/dev/null 2>&1; then
    nix-build -E 'with import <nixpkgs> {}; stdenv.mkDerivation { pname = "ctos-plymouth"; version = "1.0"; src = ./assets/ctos-plymouth; installPhase = "mkdir -p $out/share/plymouth/themes/ctos; cp * $out/share/plymouth/themes/ctos/"; }' --no-out-link >/dev/null 2>&1 || \
    assert_eq "0" "1" "Nix derivation build for ctos-plymouth failed"
fi

report_summary
