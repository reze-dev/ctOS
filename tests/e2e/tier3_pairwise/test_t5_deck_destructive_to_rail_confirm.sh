#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 15: Command Deck Destructive Action -> System Rail Confirmation
# Interaction: CommandDeck (F16) + SystemRail (F13)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

ACTION_REG="${PROJECT_ROOT}/shell/desktop/core/ActionRegistry.qml"
COMMAND_DECK="${PROJECT_ROOT}/shell/desktop/surfaces/CommandDeck.qml"
SYSTEM_RAIL="${PROJECT_ROOT}/shell/desktop/surfaces/SystemRail.qml"
OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"

test_case "T3.15" "Pairwise: CommandDeck destructive action activates System Rail confirmation view"
assert_file_exists "${ACTION_REG}"
assert_file_exists "${COMMAND_DECK}"
assert_file_exists "${OVERLAY_CTRL}"

if [[ -f "${SYSTEM_RAIL}" ]]; then
    # When action is executed from Deck, SystemRail must be opened in confirmation mode
    assert_grep -E "(openSystemRail|SystemRail)" "${ACTION_REG}" "ActionRegistry must route destructive actions to SystemRail"
    assert_grep -E "(confirmationAction|isConfirming)" "${SYSTEM_RAIL}" "SystemRail must support confirmation state"
else
    test_skip "Pending M2/M3: SystemRail confirmation view pending implementation"
fi

report_summary
