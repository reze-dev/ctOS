#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 3 Boundaries: Curated App Shapes
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

ICON_ROUTER="${PROJECT_ROOT}/shell/desktop/surfaces/components/CtosIcon.qml"
SHAPES_DIR="${PROJECT_ROOT}/shell/desktop/surfaces/components/shapes"

test_case "T2.17.1" "Curated Shapes Boundary: Reverse-DNS prefix stripping (e.g. org.kde.dolphin -> dolphin)"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E "(\.toLowerCase|\.replace|strip|split)" "${ICON_ROUTER}" \
        "Router must normalize application identifiers by stripping reverse-DNS prefixes"
else
    test_skip "Pending M1: Identifier normalization pending M1"
fi

test_case "T2.17.2" "Curated Shapes Boundary: .desktop suffix stripping (e.g. ghostty.desktop -> ghostty)"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E '(\.replace\(/\.desktop/|replace\("\.desktop"|\.endsWith)' "${ICON_ROUTER}" \
        "Router must strip .desktop suffix"
else
    test_skip "Pending M1: .desktop suffix stripping pending M1"
fi

test_case "T2.17.3" "Curated Shapes Boundary: Case-insensitivity (e.g. GHOSTTY -> ghostty)"
if [[ -f "${ICON_ROUTER}" ]]; then
    assert_grep -E "(\.toLowerCase\(\)|toLowerCase)" "${ICON_ROUTER}" \
        "Router must lower-case identifiers before matching curated apps"
else
    test_skip "Pending M1: Case normalization pending M1"
fi

test_case "T2.17.4" "Curated Shapes Boundary: Scaling geometry uses size property (no fixed pixel bounds)"
if [[ -d "${SHAPES_DIR}" ]] && [[ $(find "${SHAPES_DIR}" -name "*.qml" | wc -l) -gt 0 ]]; then
    first_shape=$(find "${SHAPES_DIR}" -name "*.qml" | head -n 1)
    assert_grep -E "(scale|scaleX|scaleY|width:\s*root\.size|preferredWidth)" "${first_shape}" \
        "Shapes must scale proportionally with size"
else
    test_skip "Pending M1: Shape scaling check pending M1"
fi

test_case "T2.17.5" "Curated Shapes Boundary: Shapes contain zero external image file dependencies"
if [[ -d "${SHAPES_DIR}" ]] && [[ $(find "${SHAPES_DIR}" -name "*.qml" | wc -l) -gt 0 ]]; then
    assert_not_grep -i -E "(Image\s*\{|source:\s*\"[^\"]+\.(png|jpg|jpeg)\")" "${SHAPES_DIR}" \
        "Curated shapes must be pure procedural vector shapes, zero external bitmaps"
else
    test_skip "Pending M1: Procedural vector check pending M1"
fi

report_summary
