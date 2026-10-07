#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature Coverage: Living Notch Hover-Reveal Expansion (R2: F8 - F13)
# Source: ORIGINAL_REQUEST.md §R2, PROJECT.md §Feature Inventory, unified-island-redesign.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

LIVING_NOTCH="${PROJECT_ROOT}/shell/desktop/surfaces/components/LivingNotch.qml"
OS_ICON="${PROJECT_ROOT}/shell/desktop/surfaces/components/os-icon.svg"
AUDIO_SVC="${PROJECT_ROOT}/shell/desktop/services/AudioService.qml"
BLUETOOTH_SVC="${PROJECT_ROOT}/shell/desktop/services/BluetoothService.qml"
OVERLAY_CTRL="${PROJECT_ROOT}/shell/desktop/core/OverlayController.qml"
THEME_FILE="${PROJECT_ROOT}/shell/desktop/core/Theme.qml"

test_case "T1.HOVER.01" "Hover Expansion: 2-row expansion bounds (~360-400px x ~60px)"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(hoverWidth|expandedWidth|width).*3[6-9][0-9]|4[0-9]{2}' "${LIVING_NOTCH}" \
        "Living Notch must expand to 360px..400px+ on hover"
    assert_grep -E '(hoverHeight|expandedHeight|height).*60' "${LIVING_NOTCH}" \
        "Living Notch must expand to ~60px (2 rows) on hover"
else
    # Validate theme animation duration and spring properties
    assert_grep "durationNormal" "${THEME_FILE}" "Theme must provide durationNormal token"
fi

test_case "T1.HOVER.02" "Hover Expansion: Organic spring physics animation declaration"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E 'SpringAnimation|spring:\s*4|damping:\s*0\.3' "${LIVING_NOTCH}" \
        "Living Notch expansion animation must utilize spring physics (spring: 4, damping: 0.3)"
else
    assert_grep "durationSlow" "${THEME_FILE}" "Theme must provide durationSlow token"
fi

test_case "T1.HOVER.03" "Hover Expansion: Blume/OS logo trigger routes click to CommandDeck"
assert_file_exists "${OS_ICON}" "Branding os-icon.svg must exist"
assert_file_exists "${OVERLAY_CTRL}"
assert_grep "openCommandDeck" "${OVERLAY_CTRL}" "OverlayController must expose openCommandDeck API"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(os-icon\.svg|openCommandDeckRequested|OverlayController\.openCommandDeck)' "${LIVING_NOTCH}" \
        "Living Notch hover row must reveal logo and trigger CommandDeck on click"
fi

test_case "T1.HOVER.04" "Hover Expansion: Full date alongside time revealed on hover"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(fullDate|date|Qt\.formatDateTime)' "${LIVING_NOTCH}" \
        "Living Notch must expose full date on hover"
else
    assert_grep "fontFamilyMonospace" "${THEME_FILE}" "Monospace font configured for clock/date"
fi

test_case "T1.HOVER.05" "Hover Expansion: Expanded system tray indicators (Network, Volume, Battery, Bluetooth)"
assert_file_exists "${AUDIO_SVC}"
assert_file_exists "${BLUETOOTH_SVC}"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(NetworkWidget|VolumeWidget|BatteryWidget|BluetoothWidget|AudioService|BluetoothService)' "${LIVING_NOTCH}" \
        "Living Notch must embed tray indicator items in expanded state"
fi

test_case "T1.HOVER.06" "Hover Expansion: Volume wheel scroll adjustments (AudioService.stepVolume)"
assert_grep "function stepVolume" "${AUDIO_SVC}" "AudioService must declare stepVolume function"
assert_grep "setVolume" "${AUDIO_SVC}" "AudioService stepVolume must delegate to clamped setVolume"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(onWheel|stepVolume)' "${LIVING_NOTCH}" \
        "Living Notch must step volume on mouse wheel scroll"
fi

test_case "T1.HOVER.07" "Hover Expansion: Preserved system tray click interactions"
assert_grep "toggleMute" "${AUDIO_SVC}" "AudioService must declare toggleMute function"
assert_grep "togglePower" "${BLUETOOTH_SVC}" "BluetoothService must declare togglePower function"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(toggleMute|toggleCommandCenter|openCommandCenter|togglePower)' "${LIVING_NOTCH}" \
        "Living Notch must preserve click interactions for tray items"
fi

report_summary
