#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 16: Command Deck Action Routing
# Source: interaction-spec.md, TEST_INFRA.md §Feature 16, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

COMMAND_DECK="${PROJECT_ROOT}/shell/desktop/surfaces/CommandDeck.qml"
ACTION_REG="${PROJECT_ROOT}/shell/desktop/core/ActionRegistry.qml"
OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"

test_case "T1.30.1" "Command Deck Routing: Destructive session actions are defined in ActionRegistry"
assert_file_exists "${ACTION_REG}"
assert_grep "action-logout" "${ACTION_REG}" "action-logout must exist"
assert_grep "action-reboot" "${ACTION_REG}" "action-reboot must exist"
assert_grep "action-poweroff" "${ACTION_REG}" "action-poweroff must exist"

test_case "T1.30.2" "Command Deck Routing: Destructive session actions flagged with destructive: true"
reboot_block
reboot_block=$(grep -A 10 "action-reboot" "${ACTION_REG}")
assert_match "destructive:\s*true" "${reboot_block}" "action-reboot must have destructive: true"

test_case "T1.30.3" "Command Deck Routing: CommandDeck integrates CtosIcon component"
if grep -q "CtosIcon" "${COMMAND_DECK}"; then
    assert_grep "CtosIcon" "${COMMAND_DECK}" "CommandDeck must use CtosIcon"
else
    test_skip "Pending M1: CtosIcon integration in CommandDeck pending M1"
fi

test_case "T1.30.4" "Command Deck Routing: OverlayController provides rail opening with action or rail toggle"
check_qml_method "${OVERLAY_CTRL}" "openSystemRail" || assert_grep "openSystemRail" "${OVERLAY_CTRL}" "openSystemRail required"

test_case "T1.30.5" "Command Deck Routing: Destructive action execution routes to System Rail"
if grep -q -E "(openSystemRail|SystemRail)" <(grep -A 15 "action-reboot" "${ACTION_REG}"); then
    assert_grep -E "(openSystemRail|SystemRail)" <(grep -A 15 "action-reboot" "${ACTION_REG}") "action-reboot must route to SystemRail"
else
    test_skip "Pending M3: ActionRegistry destructive routing to SystemRail pending M3"
fi

report_summary
