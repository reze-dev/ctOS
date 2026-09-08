#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 1 Boundaries: Phosphor SVGs
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

ICON_DIR="${PROJECT_ROOT}/shell/desktop/assets/icons"
ICON_ROUTER="${PROJECT_ROOT}/shell/desktop/surfaces/components/CtosIcon.qml"

test_case "T2.15.1" "Phosphor SVG Boundary: Missing SVG asset falls back gracefully without crashing"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E "(fallbackIcon|fallback|status === Image\.Error|status === Image\.Null)" "${ICON_ROUTER}" \
        "CtosIcon must handle missing SVG assets gracefully"
else
    test_skip "Pending M1: CtosIcon fallback handling pending M1"
fi

test_case "T2.15.2" "Phosphor SVG Boundary: Path traversal in icon name (../) is rejected or sanitized"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_not_grep -E 'source:\s*".*\.\./' "${ICON_ROUTER}" "Icon router must not allow unvalidated path traversal"
else
    test_skip "Pending M1: Path traversal protection pending M1"
fi

test_case "T2.15.3" "Phosphor SVG Boundary: All bundled SVGs declare XML namespaces (xmlns)"
if [[ -d "${ICON_DIR}" ]] && [[ $(find "${ICON_DIR}" -name "*.svg" | wc -l) -gt 0 ]]; then
    invalid_svgs=0
    for svg in $(find "${ICON_DIR}" -name "*.svg"); do
        if ! grep -q 'xmlns="http://www.w3.org/2000/svg"' "${svg}"; then
            invalid_svgs=$((invalid_svgs + 1))
        fi
    done
    assert_eq "0" "${invalid_svgs}" "All SVGs must declare standard SVG XML namespace"
else
    test_skip "Pending M1: SVG bundle namespace check pending M1"
fi

test_case "T2.15.4" "Phosphor SVG Boundary: Vector viewBox preserves 1:1 aspect ratio"
if [[ -d "${ICON_DIR}" ]] && [[ $(find "${ICON_DIR}" -name "*.svg" | wc -l) -gt 0 ]]; then
    first_svg=$(find "${ICON_DIR}" -name "*.svg" | head -n 1)
    assert_grep -E 'viewBox="0 0 ([0-9]+) \1"' "${first_svg}" "SVG must have square 1:1 viewBox"
else
    test_skip "Pending M1: SVG viewBox check pending M1"
fi

test_case "T2.15.5" "Phosphor SVG Boundary: Zero non-ASCII binary payload in SVG asset files"
if [[ -d "${ICON_DIR}" ]] && [[ $(find "${ICON_DIR}" -name "*.svg" | wc -l) -gt 0 ]]; then
    non_text_count=0
    for svg in $(find "${ICON_DIR}" -name "*.svg"); do
        if file "${svg}" | grep -q "data"; then
            non_text_count=$((non_text_count + 1))
        fi
    done
    assert_eq "0" "${non_text_count}" "All SVGs must be pure UTF-8 text XML files"
else
    test_skip "Pending M1: SVG text format check pending M1"
fi

report_summary
