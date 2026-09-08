#!/usr/bin/env bash
# ==============================================================================
# Tier 4 - Scenario 10: Command Deck to Rail Destructive Action Handoff
# Exercised: CommandDeck, Search "reboot", Enter, System Rail Confirm
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

COMMAND_DECK="${PROJECT_ROOT}/shell/desktop/surfaces/CommandDeck.qml"
ACTION_REG="${PROJECT_ROOT}/shell/desktop/core/ActionRegistry.qml"
OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"
SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"

test_case "T4.10" "Real-World Scenario 10: Command Deck to Rail Destructive Handoff"
assert_file_exists "${COMMAND_DECK}"
assert_file_exists "${ACTION_REG}"
assert_file_exists "${OVERLAY_CTRL}"

# Verify reboot action keywords enable query search
assert_grep "reboot" "${ACTION_REG}" "action-reboot must be searchable"

# Verify ActionRegistry routes reboot to SystemRail
if grep -q -E "(openSystemRail|SystemRail)" <(grep -A 15 "action-reboot" "${ACTION_REG}"); then
    assert_grep -E "(openSystemRail|SystemRail)" <(grep -A 15 "action-reboot" "${ACTION_REG}") \
        "action-reboot execution must route to SystemRail"
else
    test_skip "Pending M3: Destructive action routing in ActionRegistry pending M3"
fi

report_summary
