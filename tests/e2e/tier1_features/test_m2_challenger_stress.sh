#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Milestone 2: Empirical Challenger Stress Harness (R3, R4, R6)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DYNAMIC_ISLAND_HARNESS="${HARNESS_DIR}/test_m2_dynamic_island_challenger.qml"
AMBIENT_BAR_HARNESS="${HARNESS_DIR}/test_m2_ambient_bar_challenger.qml"

test_case "T1.CHAL.M2.1" "Dynamic Island: Full Lifecycle, States, 4s Auto-Collapse & Overlays"
if [[ -f "${DYNAMIC_ISLAND_HARNESS}" ]]; then
    run_qml_test_harness "${DYNAMIC_ISLAND_HARNESS}" "DynamicIsland Stress Harness" 30
else
    test_skip "DynamicIsland stress harness missing"
fi

test_case "T1.CHAL.M2.2" "Ambient Bar: Three Discrete Islands, Gaps, Centering & Branding"
if [[ -f "${AMBIENT_BAR_HARNESS}" ]]; then
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        output=$(QML_IMPORT_PATH="${PROJECT_ROOT}/shell" timeout 15 "${QUICKSHELL_BIN}" -p "${AMBIENT_BAR_HARNESS}" 2>&1)
        ret=$?
        if [[ "${ret}" -ne 0 ]]; then
            CURRENT_TEST_FAILED=1
            CURRENT_TEST_REASON="Quickshell AmbientBar harness exited with code ${ret}"
            echo "${output}"
        elif ! echo "${output}" | grep -q "ALL_CHECKS_PASSED\|SUCCESSFUL"; then
            CURRENT_TEST_FAILED=1
            CURRENT_TEST_REASON="AmbientBar harness did not report success"
            echo "${output}"
        else
            echo "${output}"
        fi
    else
        test_skip "Wayland compositor not detected for PanelWindow layer surface"
    fi
else
    test_skip "AmbientBar stress harness missing"
fi

report_summary
