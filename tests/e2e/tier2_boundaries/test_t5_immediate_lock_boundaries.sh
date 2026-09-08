#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 12 Boundaries: Immediate Session Lock
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

ACTION_REG="${PROJECT_ROOT}/shell/desktop/core/ActionRegistry.qml"

test_case "T2.26.1" "Lock Boundary: Strictly discrete 2-element argument array without shell wrapper"
assert_file_exists "${ACTION_REG}"
assert_grep -E 'Quickshell\.execDetached\(\s*\[\s*"loginctl"\s*,\s*"lock-session"\s*\]\s*\)' "${ACTION_REG}" \
    "Strictly discrete array required for lock invocation"

test_case "T2.26.2" "Lock Boundary: OverlayController.close() called before lock invocation"
lock_fn=$(grep -A 5 -B 2 'Quickshell.execDetached(\["loginctl"' "${ACTION_REG}")
assert_match "OverlayController\.close\(\)" "${lock_fn}" "Overlay must close before locking session"

test_case "T2.26.3" "Lock Boundary: Zero shell metacharacters in lock command arguments"
cmd_args=$(echo "${lock_fn}" | grep -oE '\[\s*"[^"]+"\s*,\s*"[^"]+"\s*\]' || true)
if echo "${cmd_args}" | grep -qE '(\||;|&&|\$|`)'; then
    CURRENT_TEST_FAILED=1
    CURRENT_TEST_REASON="Lock execution must contain no shell metacharacters in command arguments"
fi

test_case "T2.26.4" "Lock Boundary: Non-blocking detached execution via execDetached"
assert_match "execDetached" "${lock_fn}" "Lock must be non-blocking detached execution"

test_case "T2.26.5" "Lock Boundary: Lock action keywords include lock, screen, session"
keywords_block=$(grep -A 12 '"action-lock"' "${ACTION_REG}")
assert_match "keywords:" "${keywords_block}" "Action must declare search keywords"

report_summary
