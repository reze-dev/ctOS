#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 17: Reduced Motion + Icon Glitch Interaction
# Interaction: Settings (F4) + CtosIcon / Shapes (F4)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SETTINGS_FILE="${PROJECT_ROOT}/shell/desktop/core/Settings.qml"
ICON_ROUTER="${PROJECT_ROOT}/shell/desktop/surfaces/components/CtosIcon.qml"

test_case "T3.17" "Pairwise: Settings.reducedMotion suppresses icon glitch and scanline animations"
assert_file_exists "${SETTINGS_FILE}"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E "animate:\s*!Settings\.reducedMotion" "${ICON_ROUTER}" \
        "CtosIcon animate binding must invert Settings.reducedMotion"
else
    test_skip "Pending M1: CtosIcon.qml pending implementation"
fi

report_summary
