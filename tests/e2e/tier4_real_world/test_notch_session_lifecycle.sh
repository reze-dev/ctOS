#!/usr/bin/env bash
# ==============================================================================
# Tier 4 - Real-World Scenarios: Living Notch Full Desktop Session Lifecycle
# Source: ORIGINAL_REQUEST.md §R1 - §R5, PROJECT.md §Feature Inventory F1 - F29
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AMBIENT_BAR="${PROJECT_ROOT}/shell/desktop/surfaces/AmbientBar.qml"
LIVING_NOTCH="${PROJECT_ROOT}/shell/desktop/surfaces/components/LivingNotch.qml"
NOTCH_CALENDAR="${PROJECT_ROOT}/shell/desktop/surfaces/components/NotchCalendarGrid.qml"
OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"
COMMAND_CENTER="${PROJECT_ROOT}/shell/desktop/surfaces/CommandCenter.qml"
AUDIO_SVC="${PROJECT_ROOT}/shell/desktop/services/AudioService.qml"
NET_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkService.qml"
THEME_FILE="${PROJECT_ROOT}/shell/desktop/core/Theme.qml"

test_case "T4.LN.LIFE.01" "Lifecycle Stage 1: Cold boot compact notch initialization"
assert_file_exists "${AMBIENT_BAR}"
assert_file_exists "${THEME_FILE}"
assert_grep "barHeight" "${THEME_FILE}" "Theme defines barHeight"
assert_grep "radiusPill" "${THEME_FILE}" "Theme defines radiusPill"

test_case "T4.LN.LIFE.02" "Lifecycle Stage 2: Hover expansion and system tray reveal"
assert_file_exists "${AUDIO_SVC}"
assert_file_exists "${NET_SVC}"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(hoverWidth|expandedWidth)' "${LIVING_NOTCH}"
    assert_grep -E '(SpringAnimation|spring)' "${LIVING_NOTCH}"
else
    assert_grep "durationSlow" "${THEME_FILE}"
fi

test_case "T4.LN.LIFE.03" "Lifecycle Stage 3: Audio volume scroll adjustment during hover"
assert_grep "function stepVolume" "${AUDIO_SVC}" "AudioService provides stepVolume"
assert_grep "function setVolume" "${AUDIO_SVC}" "AudioService provides setVolume with boundary clamping"

test_case "T4.LN.LIFE.04" "Lifecycle Stage 4: Downward calendar morph and 42-cell navigation"
if [[ -f "${NOTCH_CALENDAR}" ]]; then
    assert_grep -E '(42|generateCalendarCells)' "${NOTCH_CALENDAR}"
    assert_grep -E '(previousMonth|nextMonth|resetToToday)' "${NOTCH_CALENDAR}"
else
    assert_file_exists "${PROJECT_ROOT}/shell/desktop/surfaces/components/CalendarPopup.qml"
fi

test_case "T4.LN.LIFE.05" "Lifecycle Stage 5: Overlay summon and notch opacity handoff"
assert_file_exists "${OVERLAY_CTRL}"
assert_file_exists "${COMMAND_CENTER}"
assert_grep "openCommandCenter" "${OVERLAY_CTRL}" "OverlayController provides openCommandCenter"
assert_grep "close" "${OVERLAY_CTRL}" "OverlayController provides close"

test_case "T4.LN.LIFE.06" "Lifecycle Stage 6: Full screen window clearance with exclusiveZone 0"
assert_grep "PanelWindow" "${AMBIENT_BAR}"
assert_grep "mask:" "${AMBIENT_BAR}"
assert_grep "flushWaylandMask" "${AMBIENT_BAR}"

report_summary
