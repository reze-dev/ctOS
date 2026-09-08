#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 10: Clock Indicator
# Source: ORIGINAL_REQUEST §R2, interaction-spec.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"

test_case "T1.10.1" "Clock Indicator: Clock widget component exists in surfaces/components/"
if [[ -d "${DESKTOP_DIR}/surfaces" ]]; then
    local widget_found
    widget_found=$(find "${DESKTOP_DIR}/surfaces" -name "*Clock*.qml" 2>/dev/null | head -n 1)
    if [[ -n "${widget_found}" ]]; then
        assert_file_exists "${widget_found}"
    else
        assert_file_exists "${DESKTOP_DIR}/surfaces/components/ClockWidget.qml" "ClockWidget.qml must exist"
    fi
else
    assert_dir_exists "${DESKTOP_DIR}/surfaces"
fi

test_case "T1.10.2" "Clock Indicator: Uses Quickshell.SystemClock or native reactive timer"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(SystemClock|Timer|Qt\.formatDateTime)" "${DESKTOP_DIR}" "Clock must use native reactive clock or timer"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

test_case "T1.10.3" "Clock Indicator: Uses monospace typography token"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(fontFamily|monospace|Theme\.font)" "${DESKTOP_DIR}" "Clock must render with monospace font"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

test_case "T1.10.4" "Clock Indicator: Formats timestamp reliably (time and date)"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_grep -i "(hh|mm|formatDateTime|time|clock)" "${DESKTOP_DIR}" "Clock must format time representation"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

test_case "T1.10.5" "Clock Indicator: Zero external date subprocess polling"
if [[ -d "${DESKTOP_DIR}" ]]; then
    assert_not_grep "command.*date" "${DESKTOP_DIR}" "Clock must not spawn external date processes"
else
    assert_dir_exists "${DESKTOP_DIR}"
fi

report_summary
