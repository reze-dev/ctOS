#!/usr/bin/env bash
# ==============================================================================
# Tier 4 - Scenario 11: Cyberpunk App Launch Aesthetics
# Exercised: CommandDeck, CtosIcon, Curated Shapes (Ghostty, Zed), Shader Fallback
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

COMMAND_DECK="${PROJECT_ROOT}/shell/desktop/surfaces/CommandDeck.qml"
ICON_ROUTER="${PROJECT_ROOT}/shell/desktop/surfaces/components/CtosIcon.qml"
SHAPES_DIR="${PROJECT_ROOT}/shell/desktop/surfaces/components/shapes"

test_case "T4.11" "Real-World Scenario 11: Cyberpunk App Launch Aesthetics"
assert_file_exists "${COMMAND_DECK}"

if [[ -f "${ICON_ROUTER}" ]]; then
    # CtosIcon routes to Shapes or Shader Fallback
    assert_grep -E "(ColorOverlay|Theme\.acidGreen)" "${ICON_ROUTER}" "Shader fallback must tint uncurated apps"
    assert_dir_exists "${SHAPES_DIR}" "shapes/ directory required"
else
    test_skip "Pending M1: CtosIcon 3-tier aesthetic strategy pending M1"
fi

report_summary
