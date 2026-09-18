#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 9: Window Manager Keybindings & IPC Launcher Packaging
# Verifies Hyprland (Super+R), Niri (Super+D/Mod+D), and ctos-shell-msg IPC
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

HYPRLAND_NIX="${PROJECT_ROOT}/modules/features/desktop/hyprland.nix"
NIRI_NIX="${PROJECT_ROOT}/modules/features/desktop/niri.nix"
PACKAGE_NIX="${PROJECT_ROOT}/shell/nix/package.nix"
SHELL_QML="${PROJECT_ROOT}/shell/shell.qml"

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
# Phase 1: Hyprland Keybindings & Configuration Tests
# ------------------------------------------------------------------------------

test_case "T1.WM.1" "Hyprland: Module defines hyprland.lua configuration"
assert_file_exists "${HYPRLAND_NIX}" "modules/features/desktop/hyprland.nix must exist"
assert_grep 'xdg\.configFile\."hypr/hyprland\.lua"\.text' "${HYPRLAND_NIX}" \
    "Hyprland module must configure hyprland.lua in xdg.configFile"

test_case "T1.WM.2" "Hyprland: Super + R bound to ctos-shell-msg toggleCommandDeck"
assert_grep 'local menu = "ctos-shell-msg toggleCommandDeck"' "${HYPRLAND_NIX}" \
    "menu variable must point to ctos-shell-msg toggleCommandDeck"
assert_grep 'hl\.bind\(mainMod \.\. " \+ R", hl\.dsp\.exec_cmd\(menu\)\)' "${HYPRLAND_NIX}" \
    "Super + R must be bound to hl.dsp.exec_cmd(menu)"

test_case "T1.WM.3" "Hyprland: Safe exit chord Super + Shift + E verified"
assert_grep 'hl\.bind\(mainMod \.\. " \+ SHIFT \+ E", hl\.dsp\.exit\(\)\)' "${HYPRLAND_NIX}" \
    "Compositor exit must require Super + Shift + E chord"

test_case "T1.WM.4" "Hyprland: Hazardous single-key Super + M exit is strictly absent"
assert_not_grep 'mainMod \.\. " \+ M"' "${HYPRLAND_NIX}" \
    "Super + M binding must not exist"
assert_not_grep 'bind.*,\s*M\s*,\s*exit' "${HYPRLAND_NIX}" \
    "Hazardous single-key M exit must not exist"

test_case "T1.WM.5" "Hyprland: Lua configuration compiles cleanly under LuaJIT"
if [[ -z "${LUAJIT_BIN}" ]]; then
    test_skip "LuaJIT binary not found in PATH or /nix/store"
else
    TMP_HYPR_LUA=$(mktemp "${TEST_TMP_DIR}/hyprland_XXXXXX.lua")
    nix eval --impure --raw --expr "
      let
        flake = builtins.getFlake (toString \"${PROJECT_ROOT}\");
      in flake.nixosConfigurations.Makima.config.home-manager.users.reze.xdg.configFile.\"hypr/hyprland.lua\".text
    " > "${TMP_HYPR_LUA}" 2>/dev/null

    if [[ ! -s "${TMP_HYPR_LUA}" ]]; then
        # Fallback: extract lua text block directly from hyprland.nix if nix eval fails
        sed -n "/xdg\.configFile\.\"hypr\/hyprland\.lua\"\.text = ''/,/''/p" "${HYPRLAND_NIX}" \
            | sed "1d;\$d" > "${TMP_HYPR_LUA}"
    fi

    assert_exit_code 0 "${LUAJIT_BIN}" -b "${TMP_HYPR_LUA}" /dev/null
    rm -f "${TMP_HYPR_LUA}"
fi

# ------------------------------------------------------------------------------
# Phase 2: Niri Keybindings & Configuration Tests
# ------------------------------------------------------------------------------

test_case "T1.WM.6" "Niri: Module defines binds configuration in settings"
assert_file_exists "${NIRI_NIX}" "modules/features/desktop/niri.nix must exist"
assert_grep 'programs\.niri\s*=\s*\{' "${NIRI_NIX}" \
    "Niri module must configure programs.niri"
assert_grep 'binds\s*=\s*\{' "${NIRI_NIX}" \
    "Niri module must configure binds table"

test_case "T1.WM.7" "Niri: Super + D (Mod+D) bound to spawn ctos-shell-msg toggleCommandDeck"
assert_grep '"Mod\+D"\.action\s*=\s*actions\.spawn\s*"ctos-shell-msg"\s*"toggleCommandDeck"' "${NIRI_NIX}" \
    "Mod+D action must spawn ctos-shell-msg toggleCommandDeck"

test_case "T1.WM.8" "Niri: Duplicate or legacy Mod+Space launcher binding is strictly absent"
assert_not_grep '"Mod\+Space"' "${NIRI_NIX}" \
    "Mod+Space binding must not exist in niri.nix"

test_case "T1.WM.9" "Niri: Dead waybar layer rule is strictly absent"
assert_not_grep 'waybar' "${NIRI_NIX}" \
    "Dead waybar references must not exist in niri.nix"

test_case "T1.WM.10" "Niri: Generated KDL configuration validates cleanly via niri validate"
NIRI_KDL_STORE=$(nix eval --impure --raw --expr "
  let
    flake = builtins.getFlake (toString \"${PROJECT_ROOT}\");
    reze = flake.nixosConfigurations.Makima.config.home-manager.users.reze;
  in \"\${reze.xdg.configFile.\"niri-config\".source}\"
" 2>/dev/null)

if [[ -z "${NIRI_KDL_STORE}" || ! -f "${NIRI_KDL_STORE}" ]]; then
    test_skip "Niri generated config.kdl store path could not be resolved"
elif [[ -z "${NIRI_BIN}" ]]; then
    test_skip "niri binary not found for validation"
else
    VALIDATE_OUT=$("${NIRI_BIN}" validate --config "${NIRI_KDL_STORE}" 2>&1)
    VALIDATE_RET=$?
    assert_eq 0 "${VALIDATE_RET}" "niri validate must return 0"
    assert_match "config is valid" "${VALIDATE_OUT}" "niri validate must confirm config is valid"
fi

# ------------------------------------------------------------------------------
# Phase 3: Launcher Packaging & ctos-shell-msg IPC Tests
# ------------------------------------------------------------------------------

test_case "T1.WM.11" "IPC Packaging: ctos-shell derivation builds cleanly"
CTOS_OUT=$(nix build .#ctos-shell --no-link --print-out-paths 2>/dev/null)
assert_exit_code 0 test -n "${CTOS_OUT}"
assert_dir_exists "${CTOS_OUT}" "Derivation output directory must exist"

test_case "T1.WM.12" "IPC Packaging: ctos-shell-msg executable permissions are 0755/executable"
MSG_BIN="${CTOS_OUT}/bin/ctos-shell-msg"
assert_file_exists "${MSG_BIN}" "ctos-shell-msg binary must exist in bin/"
assert_exit_code 0 test -x "${MSG_BIN}"

test_case "T1.WM.13" "IPC Packaging: ctos-shell-msg specifies valid shell shebang"
FIRST_LINE=$(head -n 1 "${MSG_BIN}")
assert_match "^#\!.*bin/sh" "${FIRST_LINE}" "First line must be a valid #!/bin/sh shebang"

test_case "T1.WM.14" "IPC Packaging: ctos-shell-msg invokes quickshell ipc call ctos"
MSG_CONTENT=$(cat "${MSG_BIN}")
assert_match "quickshell ipc -p \".*share/ctos/shell\.qml\" call ctos \"\\\$@\"" "${MSG_CONTENT}" \
    "Wrapper must invoke quickshell ipc call ctos with argument forwarding"

test_case "T1.WM.15" "IPC Runtime Contract: shell.qml defines ctos target with toggleCommandDeck"
assert_file_exists "${SHELL_QML}" "shell/shell.qml must exist"
assert_grep 'target:\s*"ctos"' "${SHELL_QML}" "shell.qml must declare IpcHandler with target 'ctos'"
assert_grep 'function toggleCommandDeck\(\)' "${SHELL_QML}" \
    "shell.qml must declare toggleCommandDeck() in IpcHandler"

test_case "T1.WM.16" "IPC Smoke Execution: ctos-shell-msg executes safely without active display"
assert_exit_code 0 "${MSG_BIN}" --help
SMOKE_OUT=$("${MSG_BIN}" toggleCommandDeck 2>&1 || true)
assert_match "(No running instances|calling|called|success)" "${SMOKE_OUT}" \
    "ctos-shell-msg must communicate with quickshell ipc socket or report no running instances"

report_summary
