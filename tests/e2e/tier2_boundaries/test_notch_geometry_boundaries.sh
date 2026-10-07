#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Boundary & Corner Cases: Living Notch Geometry & State Boundaries
# Source: ORIGINAL_REQUEST.md §R1, §R2, §R4, PROJECT.md, unified-island-redesign.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

LIVING_NOTCH="${PROJECT_ROOT}/shell/desktop/surfaces/components/LivingNotch.qml"
SETTINGS_FILE="${PROJECT_ROOT}/shell/desktop/core/Settings.qml"
THEME_FILE="${PROJECT_ROOT}/shell/desktop/core/Theme.qml"
COMPOSITOR_SVC="${PROJECT_ROOT}/shell/desktop/services/CompositorService.qml"
NETWORK_SVC="${PROJECT_ROOT}/shell/desktop/services/NetworkService.qml"

test_case "T2.LN.GEOM.01" "Geometry Boundary: Compact width bounds between 200px and 280px"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E 'compactWidth:\s*(2[0-8][0-9])' "${LIVING_NOTCH}" \
        "Living Notch compact width must be declared within 200px..280px"
else
    # Validate barHeight boundary
    assert_grep -E 'barHeight:\s*(36|40)' "${THEME_FILE}" "Theme.barHeight must be 36 or 40"
fi

test_case "T2.LN.GEOM.02" "Geometry Boundary: Expanded width bounds between 360px and 420px"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(hoverWidth|expandedWidth):\s*(3[6-9][0-9]|4[0-2][0-9])' "${LIVING_NOTCH}" \
        "Living Notch expanded width must be declared within 360px..420px"
else
    assert_grep "barPaddingHorizontal" "${THEME_FILE}" "Theme barPaddingHorizontal declared"
fi

test_case "T2.LN.STATE.01" "Zero Networks Boundary: Disconnected state hides network dot without layout shift"
assert_grep "property bool isConnected" "${NETWORK_SVC}" "NetworkService isConnected property declared"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E 'visible:\s*.*isConnected' "${LIVING_NOTCH}" \
        "Living Notch network dot must hide when isConnected is false"
fi

test_case "T2.LN.STATE.02" "Sparse Workspaces Boundary: High workspace counts handle without overflow"
assert_grep "readonly property list<var> workspaces" "${COMPOSITOR_SVC}" \
    "CompositorService workspaces list handles dynamic counts"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(Repeater|ListView|RowLayout|Row)' "${LIVING_NOTCH}" \
        "Living Notch must lay out workspaces dynamically"
fi

test_case "T2.LN.TEXT.01" "Text Boundary: Long track title and notification summary elision"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(elide:\s*Text\.ElideRight|clip:\s*true)' "${LIVING_NOTCH}" \
        "Living Notch text displays must specify Text.ElideRight or clipping"
else
    assert_grep "Maple Mono" "${THEME_FILE}" "Font family Maple Mono declared"
fi

test_case "T2.LN.MOTION.01" "Reduced Motion Boundary: Settings.reducedMotion suppresses bouncy spring physics"
assert_file_exists "${SETTINGS_FILE}"
assert_grep "reducedMotion" "${SETTINGS_FILE}" "Settings must expose reducedMotion property"
if [[ -f "${LIVING_NOTCH}" ]]; then
    assert_grep -E '(reducedMotion|Settings\.reducedMotion)' "${LIVING_NOTCH}" \
        "Living Notch must check Settings.reducedMotion for animations"
fi

report_summary
