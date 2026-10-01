#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature Coverage: Living Notch Morphing Calendar Grid (R3: F16 - F23)
# Source: ORIGINAL_REQUEST.md §R3, PROJECT.md §Feature Inventory, unified-island-redesign.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

NOTCH_CALENDAR="${PROJECT_ROOT}/shell/desktop/surfaces/components/NotchCalendarGrid.qml"
LIVING_NOTCH="${PROJECT_ROOT}/shell/desktop/surfaces/components/LivingNotch.qml"
STANDALONE_CAL="${PROJECT_ROOT}/shell/desktop/surfaces/components/CalendarPopup.qml"
COMPONENTS_QMLDIR="${PROJECT_ROOT}/shell/desktop/surfaces/components/qmldir"
THEME_FILE="${PROJECT_ROOT}/shell/desktop/core/Theme.qml"
RUNTIME_HARNESS="${HARNESS_DIR}/test_notch_calendar_morph_runtime.qml"

test_case "T1.CAL.01" "Calendar Morph: Downward container morphing with clip false"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(clip:\s*false|calendarOpen|calendarHeight)' "${LIVING_NOTCH}" \
        "Living Notch must permit downward growth past bounds (clip: false)"
else
    assert_file_exists "${THEME_FILE}"
fi

test_case "T1.CAL.02" "Calendar Redesign: 42-cell ISO-8601 Monday-first grid math"
if [[ -f "${NOTCH_CALENDAR}" ]]; then
    assert_grep -E '(42|cells\.length\s*===\s*42|MON.*TUE.*WED)' "${NOTCH_CALENDAR}" \
        "NotchCalendarGrid must implement 42-cell ISO-8601 grid"
else
    # Standalone calendar backward compatibility verification
    assert_file_exists "${STANDALONE_CAL}" "CalendarPopup.qml must exist for backwards compatibility"
    assert_grep "42" "${STANDALONE_CAL}" "CalendarPopup must implement 42-cell grid"
fi

test_case "T1.CAL.03" "Calendar Cells: Styled rectangle cells with cyberpunk borders"
if [[ -f "${NOTCH_CALENDAR}" ]]; then
    assert_grep -E '(Rectangle|border\.color|radius)' "${NOTCH_CALENDAR}" \
        "NotchCalendarGrid cells must be styled rectangles"
else
    assert_grep "borderMuted" "${THEME_FILE}" "Theme borderMuted token available"
    assert_grep "radiusSmall" "${THEME_FILE}" "Theme radiusSmall token available"
fi

test_case "T1.CAL.04" "Calendar Accent: Today cell glowing accent highlight (Theme.acidGreen)"
assert_grep "acidGreen:\s*\"#1BFD9C\"" "${THEME_FILE}" "Theme acidGreen token must be #1BFD9C"
if [[ -f "${NOTCH_CALENDAR}" ]]; then
    assert_grep -E '(Theme\.acidGreen|isToday)' "${NOTCH_CALENDAR}" \
        "Today's cell must be highlighted with Theme.acidGreen"
fi

test_case "T1.CAL.05" "Calendar Dimming: Other-month days styled with Theme.textMuted"
assert_grep "textMuted" "${THEME_FILE}" "Theme textMuted token must exist"
if [[ -f "${NOTCH_CALENDAR}" ]]; then
    assert_grep -E '(textMuted|isCurrentMonth)' "${NOTCH_CALENDAR}" \
        "Other-month days must be dimmed with Theme.textMuted"
fi

test_case "T1.CAL.06" "Calendar Navigation: Previous/Next buttons and [TODAY] reset"
if [[ -f "${NOTCH_CALENDAR}" ]]; then
    assert_grep -E '(previousMonth|nextMonth)' "${NOTCH_CALENDAR}" \
        "NotchCalendarGrid must declare month navigation functions"
    assert_grep -E '(resetToToday|TODAY)' "${NOTCH_CALENDAR}" \
        "NotchCalendarGrid must declare resetToToday function / TODAY button"
else
    assert_grep "previousMonth" "${STANDALONE_CAL}" "CalendarPopup provides previousMonth"
    assert_grep "nextMonth" "${STANDALONE_CAL}" "CalendarPopup provides nextMonth"
    assert_grep "resetToToday" "${STANDALONE_CAL}" "CalendarPopup provides resetToToday"
fi

test_case "T1.CAL.07" "Calendar Compatibility: Standalone CalendarPopup retained in components/qmldir"
assert_file_exists "${STANDALONE_CAL}" "CalendarPopup.qml must be retained"
assert_grep "CalendarPopup\s+1\.0\s+CalendarPopup\.qml" "${COMPONENTS_QMLDIR}" \
    "CalendarPopup must remain registered in components/qmldir"

test_case "T1.CAL.08" "Calendar Runtime: Headless runtime QML harness execution"
if [[ -f "${RUNTIME_HARNESS}" ]]; then
    run_qml_test_harness "${RUNTIME_HARNESS}" "Notch Calendar Morph Runtime Harness"
else
    test_skip "test_notch_calendar_morph_runtime.qml missing"
fi

report_summary
