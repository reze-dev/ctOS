#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 9 Boundary: WM Keybindings & Launcher Packaging Edge Cases
# Validates robustness of syntax checkers, argument propagation, and safety bounds
# Strictly non-destructive: requires zero active display sessions
# ==============================================================================
set -u
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../../.." 2>/dev/null && pwd)}"
if [[ ! -f "${PROJECT_ROOT}/flake.nix" ]]; then
    PROJECT_ROOT="/home/reze/Projects/ctOS"
fi

# Locate mock_environment.sh
if [[ -f "${SCRIPT_DIR}/../harness/mock_environment.sh" ]]; then
    source "${SCRIPT_DIR}/../harness/mock_environment.sh"
elif [[ -f "${PROJECT_ROOT}/tests/e2e/harness/mock_environment.sh" ]]; then
    source "${PROJECT_ROOT}/tests/e2e/harness/mock_environment.sh"
else
    echo "Error: mock_environment.sh not found" >&2
    exit 1
fi

PACKAGE_NIX="${PROJECT_ROOT}/shell/nix/package.nix"

# Discover Luajit binary
LUAJIT_BIN=""
if command -v luajit >/dev/null 2>&1; then
    LUAJIT_BIN="$(command -v luajit)"
else
    for candidate in /nix/store/*luajit*/bin/luajit; do
        if [[ -x "${candidate}" ]]; then
            LUAJIT_BIN="${candidate}"
            break
        fi
    done
fi

# Discover Niri binary
NIRI_BIN=""
if command -v niri >/dev/null 2>&1; then
    NIRI_BIN="$(command -v niri)"
elif [[ -x "/run/current-system/sw/bin/niri" ]]; then
    NIRI_BIN="/run/current-system/sw/bin/niri"
else
    for candidate in /nix/store/*niri*/bin/niri; do
        if [[ -x "${candidate}" ]]; then
            NIRI_BIN="${candidate}"
            break
        fi
    done
fi

# ------------------------------------------------------------------------------
# Boundary Tests
# ------------------------------------------------------------------------------

test_case "T2.WM.1" "Boundary: LuaJIT validator detects corrupt Lua syntax"
if [[ -z "${LUAJIT_BIN}" ]]; then
    test_skip "LuaJIT binary not found"
else
    CORRUPT_LUA="${TEST_TMP_DIR}/corrupt_syntax.lua"
    echo "function broken( { syntax error here" > "${CORRUPT_LUA}"
    set +e
    "${LUAJIT_BIN}" -b "${CORRUPT_LUA}" /dev/null >/dev/null 2>&1
    RET=$?
    set -u
    assert_neq 0 "${RET}" "LuaJIT must reject malformed Lua syntax"
    rm -f "${CORRUPT_LUA}"
fi

test_case "T2.WM.2" "Boundary: Niri validator detects corrupt KDL syntax"
if [[ -z "${NIRI_BIN}" ]]; then
    test_skip "niri binary not found"
else
    CORRUPT_KDL="${TEST_TMP_DIR}/corrupt_config.kdl"
    echo "binds { Mod+D { spawn unclosed string " > "${CORRUPT_KDL}"
    set +e
    "${NIRI_BIN}" validate --config "${CORRUPT_KDL}" >/dev/null 2>&1
    RET=$?
    set -u
    assert_neq 0 "${RET}" "niri validate must reject malformed KDL syntax"
    rm -f "${CORRUPT_KDL}"
fi

test_case "T2.WM.3" "Boundary: IPC wrapper uses strict double-quoted argument forwarding (\"\$@\")"
assert_grep 'call\s+ctos\s+"\\\$@"' "${PACKAGE_NIX}" \
    "package.nix must preserve spaced arguments with double-quoted \"\$@\""

test_case "T2.WM.4" "Boundary: IPC wrapper resolves absolute store path to shell.qml"
CTOS_OUT=$(nix build .#ctos-shell --no-link --print-out-paths 2>/dev/null)
MSG_BIN="${CTOS_OUT}/bin/ctos-shell-msg"
MSG_CONTENT=$(cat "${MSG_BIN}")
assert_match 'quickshell ipc -p "/nix/store/[^"]+/share/ctos/shell\.qml"' "${MSG_CONTENT}" \
    "ctos-shell-msg must embed absolute immutable nix store path to shell.qml"

test_case "T2.WM.5" "Boundary: Symlinked invocation of ctos-shell-msg functions identically"
SYMLINK_BIN="${TEST_TMP_DIR}/symlinked-msg"
ln -s "${MSG_BIN}" "${SYMLINK_BIN}"
assert_exit_code 0 "${SYMLINK_BIN}" --help
rm -f "${SYMLINK_BIN}"

report_summary
