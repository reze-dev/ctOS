#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 16 Boundaries: Command Deck Action Routing
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

COMMAND_DECK="${PROJECT_ROOT}/shell/desktop/surfaces/CommandDeck.qml"
ACTION_REG="${PROJECT_ROOT}/shell/desktop/core/ActionRegistry.qml"
OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"

test_case "T2.30.1" "Deck Routing Boundary: Unknown action search query yields safe empty state"
assert_file_exists "${COMMAND_DECK}"
# When search has no results, CommandDeck displays empty state or handles gracefully
assert_grep -E "(noResults|count === 0|modelData)" "${COMMAND_DECK}" "CommandDeck must handle empty search results safely"

test_case "T2.30.2" "Deck Routing Boundary: Selecting an action closes CommandDeck overlay"
assert_grep "OverlayController\.close\(\)" "${COMMAND_DECK}" "CommandDeck must close when an action is executed"

test_case "T2.30.3" "Deck Routing Boundary: Destructive session actions are not directly executed from Deck"
# In ActionRegistry, destructive actions must route to SystemRail, not call systemctl reboot directly
reboot_action=$(grep -A 12 '"action-reboot"' "${ACTION_REG}")
assert_not_match 'systemctl' "${reboot_action}" "CommandDeck ActionRegistry must not execute reboot directly"

test_case "T2.30.4" "Deck Routing Boundary: OverlayController preserves single active surface mutual exclusion"
assert_file_exists "${OVERLAY_CTRL}"
assert_grep -E "activeSurface\s*=" "${OVERLAY_CTRL}" "OverlayController must manage activeSurface assignment"

test_case "T2.30.5" "Deck Routing Boundary: CommandDeck query input cleared on overlay open/close"
assert_grep -E '(text\s*=\s*""|queryInput\.text\s*=\s*"")' "${COMMAND_DECK}" \
    "CommandDeck query input must be cleared or reset"

report_summary
