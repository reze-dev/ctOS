#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature R4: Audio Surveillance Feed Widget
# Requirements: ORIGINAL_REQUEST §R4, PROJECT.md
# Verifies AudioSurveillanceWidget.qml MPRIS integration, player priority resolution,
# surveillance formatting ([FREQ INTERCEPT] TITLE - ARTIST), animated frequency
# spectrum visualizer bars, and idle frequency scanning mode.
# ==============================================================================
set -u
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

WIDGET_FILE="${PROJECT_ROOT}/shell/desktop/surfaces/widgets/AudioSurveillanceWidget.qml"

# ------------------------------------------------------------------------------
# R4.01: File Existence & Basic Structure
# ------------------------------------------------------------------------------
test_case "R4.01" "Audio Surveillance: Widget file exists in desktop/surfaces/widgets/"
assert_file_exists "${WIDGET_FILE}" "shell/desktop/surfaces/widgets/AudioSurveillanceWidget.qml required"

# ------------------------------------------------------------------------------
# R4.02: Zero-Subprocess & DBus Purity (Quickshell.Services.Mpris)
# ------------------------------------------------------------------------------
test_case "R4.02" "Audio Surveillance: Pure DBus integration without spawning subprocesses"
if [[ -f "${WIDGET_FILE}" ]]; then
    assert_grep "import\s+Quickshell\.Services\.Mpris" "${WIDGET_FILE}" "Widget must import Quickshell.Services.Mpris"
    assert_not_grep "Process\s*\{" "${WIDGET_FILE}" "Widget must never spawn Process subprocesses"
    assert_not_grep "sh\s+-c" "${WIDGET_FILE}" "Widget must not invoke shell commands"
else
    assert_file_exists "${WIDGET_FILE}"
fi

# ------------------------------------------------------------------------------
# R4.03: Active Player Priority Resolution
# ------------------------------------------------------------------------------
test_case "R4.03" "Audio Surveillance: Resolves active player prioritizing Playing over Paused"
if [[ -f "${WIDGET_FILE}" ]]; then
    assert_grep "MprisPlaybackState\.Playing" "${WIDGET_FILE}" "Widget must prioritize playing state"
    assert_grep "MprisPlaybackState\.Paused" "${WIDGET_FILE}" "Widget must support paused state fallback"
    assert_qml_property "${WIDGET_FILE}" "activePlayer" --type var
    assert_qml_property "${WIDGET_FILE}" "hasMedia" --type bool
    assert_qml_property "${WIDGET_FILE}" "isPlaying" --type bool
else
    assert_file_exists "${WIDGET_FILE}"
fi

# ------------------------------------------------------------------------------
# R4.04: Surveillance Formatting Contract: [FREQ INTERCEPT] TITLE - ARTIST
# ------------------------------------------------------------------------------
test_case "R4.04" "Audio Surveillance: Formats track metadata as '[FREQ INTERCEPT] TITLE - ARTIST'"
if [[ -f "${WIDGET_FILE}" ]]; then
    assert_grep '"\[FREQ INTERCEPT\]\s*"' "${WIDGET_FILE}" "Widget must include '[FREQ INTERCEPT] ' prefix"
    assert_qml_property "${WIDGET_FILE}" "title" --type string
    assert_qml_property "${WIDGET_FILE}" "artist" --type string
    assert_qml_property "${WIDGET_FILE}" "interceptString" --type string
else
    assert_file_exists "${WIDGET_FILE}"
fi

# ------------------------------------------------------------------------------
# R4.05: Idle Frequency Scanning Fallback
# ------------------------------------------------------------------------------
test_case "R4.05" "Audio Surveillance: Idle state renders [FREQ SCAN] awaiting transmission"
if [[ -f "${WIDGET_FILE}" ]]; then
    assert_grep '"\[FREQ SCAN\]' "${WIDGET_FILE}" "Widget must format [FREQ SCAN] when idle"
    assert_grep 'AWAITING TRANSMISSION' "${WIDGET_FILE}" "Widget must display awaiting transmission message"
    assert_grep 'NO CARRIER' "${WIDGET_FILE}" "Widget must fallback to NO CARRIER title when no media"
else
    assert_file_exists "${WIDGET_FILE}"
fi

# ------------------------------------------------------------------------------
# R4.06: Frequency Spectrum Visualizer Bars
# ------------------------------------------------------------------------------
test_case "R4.06" "Audio Surveillance: Visualizer bars oscillate when playing & flatline when idle"
if [[ -f "${WIDGET_FILE}" ]]; then
    assert_grep "visualizerPhase" "${WIDGET_FILE}" "Widget must declare visualizerPhase animation"
    assert_grep "NumberAnimation\s*\{" "${WIDGET_FILE}" "Widget must use NumberAnimation for spectrum"
    assert_grep "Repeater\s*\{" "${WIDGET_FILE}" "Widget must render multi-bar audio visualizer via Repeater"
    assert_grep "model:\s*(12|16|20|24)" "${WIDGET_FILE}" "Visualizer must render 12 to 24 frequency bars"
else
    assert_file_exists "${WIDGET_FILE}"
fi

# ------------------------------------------------------------------------------
# R4.07: Pure DBus Control Methods
# ------------------------------------------------------------------------------
test_case "R4.07" "Audio Surveillance: Exposes safe DBus control methods (play, pause, togglePlaying)"
if [[ -f "${WIDGET_FILE}" ]]; then
    assert_qml_method "${WIDGET_FILE}" "play"
    assert_qml_method "${WIDGET_FILE}" "pause"
    assert_qml_method "${WIDGET_FILE}" "togglePlaying"
    assert_qml_method "${WIDGET_FILE}" "next"
    assert_qml_method "${WIDGET_FILE}" "previous"
else
    assert_file_exists "${WIDGET_FILE}"
fi

report_summary
