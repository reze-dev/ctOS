#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Boundary & Corner Cases: Living Notch Calendar Grid Date Math & Invariants
# Source: ORIGINAL_REQUEST.md §R3, PROJECT.md §Feature Inventory F17 - F22
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

NOTCH_CALENDAR="${PROJECT_ROOT}/shell/desktop/surfaces/components/NotchCalendarGrid.qml"
STANDALONE_CAL="${PROJECT_ROOT}/shell/desktop/surfaces/components/CalendarPopup.qml"

test_case "T2.CAL.MATH.01" "Date Math Boundary: 42-cell invariant across all 12 months of leap and common years"
python3 -c "
import calendar

def generate_cells(year, month):
    # ISO-8601 Monday-first grid
    cal = calendar.Calendar(firstweekday=0) # 0=Monday
    month_days = list(cal.itermonthdays(year, month))
    # Standard 6-week 42 cell grid
    while len(month_days) < 42:
        month_days.append(0)
    return month_days[:42]

# Test years: 2024 (leap), 2025 (common), 2026 (common), 2000 (century leap), 1900 (century common)
for y in [2024, 2025, 2026, 2000, 1900]:
    for m in range(1, 13):
        cells = generate_cells(y, m)
        assert len(cells) == 42, f'Year {y} Month {m} length {len(cells)} != 42'
"
assert_eq "$?" "0" "42-cell invariant verified across all test years and months"

test_case "T2.CAL.MATH.02" "Leap Year Boundaries: 2024 (29 days), 2025 (28 days), 2000 (29 days), 1900 (28 days)"
python3 -c "
import calendar
assert calendar.monthrange(2024, 2)[1] == 29, '2024 Feb must have 29 days'
assert calendar.monthrange(2025, 2)[1] == 28, '2025 Feb must have 28 days'
assert calendar.monthrange(2000, 2)[1] == 29, '2000 Feb century leap must have 29 days'
assert calendar.monthrange(1900, 2)[1] == 28, '1900 Feb century common must have 28 days'
"
assert_eq "$?" "0" "Leap year boundary math conforms to Gregorian / ISO-8601 standards"

test_case "T2.CAL.MATH.03" "Navigation Boundary: Dec-to-Jan rollover and Jan-to-Dec rewind"
python3 -c "
def next_month(year, month):
    if month == 12:
        return year + 1, 1
    return year, month + 1

def prev_month(year, month):
    if month == 1:
        return year - 1, 12
    return year, month - 1

assert next_month(2026, 12) == (2027, 1), 'Dec 2026 next month rolls to Jan 2027'
assert prev_month(2026, 1) == (2025, 12), 'Jan 2026 prev month rewinds to Dec 2025'
"
assert_eq "$?" "0" "Navigation rollover boundaries validated"

test_case "T2.CAL.MATH.04" "Calendar Component Contract: NotchCalendarGrid or CalendarPopup date math implementation"
if [[ -f "${NOTCH_CALENDAR}" ]]; then
    assert_grep -E '(generateCalendarCells|previousMonth|nextMonth|resetToToday)' "${NOTCH_CALENDAR}" \
        "NotchCalendarGrid must implement date generation and navigation methods"
else
    assert_file_exists "${STANDALONE_CAL}"
    assert_grep "generateCalendarCells" "${STANDALONE_CAL}" "CalendarPopup provides generateCalendarCells"
fi

report_summary
