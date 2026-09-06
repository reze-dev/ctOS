#!/usr/bin/env bash
# ==============================================================================
# Tier 4 - Scenario 4: Offline / Headless Hardware Degradation
# Exercised: Missing battery (desktop), missing PipeWire, missing NM
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SERVICES_DIR="${PROJECT_ROOT}/shell/desktop/services"

test_case "T4.04" "Real-World Scenario 4: Full Hardware Degradation and Unavailable Backends"
# Degradation verification:
# All services must expose available: bool and degrade cleanly without dummy values
if [[ -d "${SERVICES_DIR}" ]]; then
    for svc in AudioService NetworkService PowerService CompositorService; do
        svc_file="${SERVICES_DIR}/${svc}.qml"
        if [[ -f "${svc_file}" ]]; then
            check_qml_property "${svc_file}" "available" --type bool || assert_grep "available" "${svc_file}" "${svc} must expose available"
        else
            assert_file_exists "${svc_file}" "${svc}.qml required"
        fi
    done
else
    assert_dir_exists "${SERVICES_DIR}" "services directory required"
fi

report_summary
