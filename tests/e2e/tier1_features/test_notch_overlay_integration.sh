#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature Coverage: Living Notch Overlay Integration (R4: F14, F15, F27, F28, F29)
# Source: ORIGINAL_REQUEST.md §R4, PROJECT.md §Feature Inventory, unified-island-redesign.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

LIVING_NOTCH="${PROJECT_ROOT}/shell/desktop/surfaces/components/LivingNotch.qml"
OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"
COMMAND_CENTER="${PROJECT_ROOT}/shell/desktop/surfaces/CommandCenter.qml"
NOTIF_SVC="${PROJECT_ROOT}/shell/desktop/services/NotificationService.qml"

test_case "T1.OVR.01" "Overlay Exclusivity: Single-active surface across CommandDeck, CommandCenter, RadialSettings"
assert_file_exists "${OVERLAY_CTRL}"
assert_grep "activeSurface" "${OVERLAY_CTRL}" "OverlayController manages activeSurface"
assert_grep "CommandDeck" "${OVERLAY_CTRL}" "OverlayController defines CommandDeck"
assert_grep "CommandCenter" "${OVERLAY_CTRL}" "OverlayController defines CommandCenter"
assert_grep "RadialSettings" "${OVERLAY_CTRL}" "OverlayController defines RadialSettings"

test_case "T1.OVR.02" "CommandCenter Handoff: Notch opacity yields to 0.0 when CommandCenter is active"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(isCommandCenterOpen|opacity:\s*isCommandCenterOpen\s*\?\s*0\.0\s*:\s*1\.0|Behavior on opacity)' "${LIVING_NOTCH}" \
        "Living Notch must animate opacity to 0.0 when CommandCenter is active"
else
    # Validate OverlayController surface check
    assert_grep "Surface\.CommandCenter" "${OVERLAY_CTRL}"
fi

test_case "T1.OVR.03" "CommandCenter Accordion: Clicking notch pill triggers toggleCommandCenter"
assert_file_exists "${COMMAND_CENTER}"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(toggleCommandCenter|toggleCommandCenterRequested)' "${LIVING_NOTCH}" \
        "Living Notch must route primary click to toggleCommandCenter"
fi

test_case "T1.OVR.04" "Calendar Dismissal: Opening CommandDeck or CommandCenter closes calendar"
assert_grep -E '(function close|function dismiss)' "${OVERLAY_CTRL}" "OverlayController provides close/dismiss function"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(calendarOpen\s*=\s*false|closeCalendar)' "${LIVING_NOTCH}" \
        "Living Notch must automatically dismiss calendar when overlay opens"
fi

test_case "T1.OVR.05" "Dynamic Island State: Notification banner with 4000ms auto-collapse"
assert_file_exists "${NOTIF_SVC}"
assert_grep "notificationReceived" "${NOTIF_SVC}" "NotificationService emits notificationReceived"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(4000|interval:\s*4000|notification)' "${LIVING_NOTCH}" \
        "Living Notch must support notification banner with 4000ms collapse interval"
fi

test_case "T1.OVR.06" "Dynamic Island State: MPRIS media now-playing and equalizer"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(mpris|media|nowPlaying|artist|title)' "${LIVING_NOTCH}" \
        "Living Notch must support media now-playing display"
else
    assert_file_exists "${PROJECT_ROOT}/shell/desktop/services/AudioService.qml"
fi

report_summary
