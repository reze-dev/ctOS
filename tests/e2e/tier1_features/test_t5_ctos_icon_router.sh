#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 6: Unified CtosIcon Router
# Source: ORIGINAL_REQUEST §AC, TEST_INFRA.md §Feature 6, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

ICON_ROUTER="${PROJECT_ROOT}/shell/desktop/surfaces/components/CtosIcon.qml"
QMLDIR="${PROJECT_ROOT}/shell/desktop/surfaces/components/qmldir"

test_case "T1.20.1" "CtosIcon Router: CtosIcon.qml exists in surfaces/components/"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_file_exists "${ICON_ROUTER}" "CtosIcon.qml must exist"
else
    test_skip "Pending M1: CtosIcon.qml not yet implemented"
fi

test_case "T1.20.2" "CtosIcon Router: Exposes name, size, color, active, destructive, and animate properties"
if [[ -f "${ICON_ROUTER}" ]]; then
    check_qml_property "${ICON_ROUTER}" "name" || assert_grep "name" "${ICON_ROUTER}" "name property required"
    check_qml_property "${ICON_ROUTER}" "size" || assert_grep "size" "${ICON_ROUTER}" "size property required"
    check_qml_property "${ICON_ROUTER}" "color" || assert_grep "color" "${ICON_ROUTER}" "color property required"
    check_qml_property "${ICON_ROUTER}" "active" || assert_grep "active" "${ICON_ROUTER}" "active property required"
    check_qml_property "${ICON_ROUTER}" "destructive" || assert_grep "destructive" "${ICON_ROUTER}" "destructive property required"
    check_qml_property "${ICON_ROUTER}" "animate" || assert_grep "animate" "${ICON_ROUTER}" "animate property required"
else
    test_skip "Pending M1: CtosIcon API properties pending M1 implementation"
fi

test_case "T1.20.3" "CtosIcon Router: Tier 1 routing logic for system control icons"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E "(\.svg|icons/|assets/icons)" "${ICON_ROUTER}" "Router must link system icons to SVG assets"
else
    test_skip "Pending M1: Tier 1 routing pending M1 implementation"
fi

test_case "T1.20.4" "CtosIcon Router: Tier 2 routing logic for 9 curated app shapes"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E "(dolphin|ghostty|kitty|emacs|mpv|obsidian|zed)" "${ICON_ROUTER}" "Router must match curated app identifiers"
else
    test_skip "Pending M1: Tier 2 routing pending M1 implementation"
fi

test_case "T1.20.5" "CtosIcon Router: Registered in surfaces/components/qmldir"
if [[ -f "${QMLDIR}" ]]; then
    if [[ -f "${ICON_ROUTER}" ]]; then
        assert_grep "CtosIcon" "${QMLDIR}" "CtosIcon must be registered in qmldir"
    else
        test_skip "Pending M1: CtosIcon registration pending file creation"
    fi
else
    assert_file_exists "${QMLDIR}"
fi

report_summary
