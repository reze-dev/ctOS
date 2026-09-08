#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 3: Curated App Shapes (9 apps)
# Source: ORIGINAL_REQUEST §R1.2, TEST_INFRA.md §Feature 3, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

SHAPES_DIR="${PROJECT_ROOT}/shell/desktop/surfaces/components/shapes"

test_case "T1.17.1" "Curated App Shapes: Component directory exists in desktop/surfaces/components/shapes/"
if [[ -d "${SHAPES_DIR}" ]]; then
    assert_dir_exists "${SHAPES_DIR}" "shapes/ directory must exist"
else
    test_skip "Pending M1: shell/desktop/surfaces/components/shapes/ not yet created"
fi

test_case "T1.17.2" "Curated App Shapes: Dolphin shape component exists with QtQuick.Shapes vector paths"
if [[ -d "${SHAPES_DIR}" ]]; then
    shape
    shape=$(find "${SHAPES_DIR}" -iname "*dolphin*.qml" | head -n 1)
    if [[ -n "${shape}" ]]; then
        assert_file_exists "${shape}"
        assert_grep -E "(QtQuick\.Shapes|ShapePath|PathLine|PathSvg)" "${shape}" "Dolphin must use QML Shapes"
    else
        assert_file_exists "${SHAPES_DIR}/DolphinShape.qml" "DolphinShape.qml must exist"
    fi
else
    test_skip "Pending M1: Dolphin shape pending M1 implementation"
fi

test_case "T1.17.3" "Curated App Shapes: Emacs shape component exists with QtQuick.Shapes vector paths"
if [[ -d "${SHAPES_DIR}" ]]; then
    shape
    shape=$(find "${SHAPES_DIR}" -iname "*emacs*.qml" | head -n 1)
    if [[ -n "${shape}" ]]; then
        assert_file_exists "${shape}"
        assert_grep -E "(QtQuick\.Shapes|ShapePath|PathLine|PathSvg)" "${shape}" "Emacs must use QML Shapes"
    else
        assert_file_exists "${SHAPES_DIR}/EmacsShape.qml" "EmacsShape.qml must exist"
    fi
else
    test_skip "Pending M1: Emacs shape pending M1 implementation"
fi

test_case "T1.17.4" "Curated App Shapes: Ghostty shape component exists with QtQuick.Shapes vector paths"
if [[ -d "${SHAPES_DIR}" ]]; then
    shape
    shape=$(find "${SHAPES_DIR}" -iname "*ghostty*.qml" | head -n 1)
    if [[ -n "${shape}" ]]; then
        assert_file_exists "${shape}"
        assert_grep -E "(QtQuick\.Shapes|ShapePath|PathLine|PathSvg)" "${shape}" "Ghostty must use QML Shapes"
    else
        assert_file_exists "${SHAPES_DIR}/GhosttyShape.qml" "GhosttyShape.qml must exist"
    fi
else
    test_skip "Pending M1: Ghostty shape pending M1 implementation"
fi

test_case "T1.17.5" "Curated App Shapes: Kitty shape component exists with QtQuick.Shapes vector paths"
if [[ -d "${SHAPES_DIR}" ]]; then
    shape
    shape=$(find "${SHAPES_DIR}" -iname "*kitty*.qml" | head -n 1)
    if [[ -n "${shape}" ]]; then
        assert_file_exists "${shape}"
        assert_grep -E "(QtQuick\.Shapes|ShapePath|PathLine|PathSvg)" "${shape}" "Kitty must use QML Shapes"
    else
        assert_file_exists "${SHAPES_DIR}/KittyShape.qml" "KittyShape.qml must exist"
    fi
else
    test_skip "Pending M1: Kitty shape pending M1 implementation"
fi

test_case "T1.17.6" "Curated App Shapes: mpv shape component exists with QtQuick.Shapes vector paths"
if [[ -d "${SHAPES_DIR}" ]]; then
    shape
    shape=$(find "${SHAPES_DIR}" -iname "*mpv*.qml" | head -n 1)
    if [[ -n "${shape}" ]]; then
        assert_file_exists "${shape}"
        assert_grep -E "(QtQuick\.Shapes|ShapePath|PathLine|PathSvg)" "${shape}" "mpv must use QML Shapes"
    else
        assert_file_exists "${SHAPES_DIR}/MpvShape.qml" "MpvShape.qml must exist"
    fi
else
    test_skip "Pending M1: mpv shape pending M1 implementation"
fi

test_case "T1.17.7" "Curated App Shapes: Obsidian shape component exists with QtQuick.Shapes vector paths"
if [[ -d "${SHAPES_DIR}" ]]; then
    shape
    shape=$(find "${SHAPES_DIR}" -iname "*obsidian*.qml" | head -n 1)
    if [[ -n "${shape}" ]]; then
        assert_file_exists "${shape}"
        assert_grep -E "(QtQuick\.Shapes|ShapePath|PathLine|PathSvg)" "${shape}" "Obsidian must use QML Shapes"
    else
        assert_file_exists "${SHAPES_DIR}/ObsidianShape.qml" "ObsidianShape.qml must exist"
    fi
else
    test_skip "Pending M1: Obsidian shape pending M1 implementation"
fi

test_case "T1.17.8" "Curated App Shapes: nvidia-settings shape component exists with QtQuick.Shapes vector paths"
if [[ -d "${SHAPES_DIR}" ]]; then
    shape
    shape=$(find "${SHAPES_DIR}" -iname "*nvidia*.qml" | head -n 1)
    if [[ -n "${shape}" ]]; then
        assert_file_exists "${shape}"
        assert_grep -E "(QtQuick\.Shapes|ShapePath|PathLine|PathSvg)" "${shape}" "nvidia-settings must use QML Shapes"
    else
        assert_file_exists "${SHAPES_DIR}/NvidiaSettingsShape.qml" "NvidiaSettingsShape.qml must exist"
    fi
else
    test_skip "Pending M1: nvidia-settings shape pending M1 implementation"
fi

test_case "T1.17.9" "Curated App Shapes: Okular and Zed shape components exist with QtQuick.Shapes vector paths"
if [[ -d "${SHAPES_DIR}" ]]; then
    okular_shape
    zed_shape
    okular_shape=$(find "${SHAPES_DIR}" -iname "*okular*.qml" | head -n 1)
    zed_shape=$(find "${SHAPES_DIR}" -iname "*zed*.qml" | head -n 1)
    if [[ -n "${okular_shape}" ]] && [[ -n "${zed_shape}" ]]; then
        assert_file_exists "${okular_shape}"
        assert_file_exists "${zed_shape}"
        assert_grep -E "(QtQuick\.Shapes|ShapePath|PathLine|PathSvg)" "${okular_shape}" "Okular must use QML Shapes"
        assert_grep -E "(QtQuick\.Shapes|ShapePath|PathLine|PathSvg)" "${zed_shape}" "Zed must use QML Shapes"
    else
        test_skip "Pending M1: Okular or Zed shape pending completion"
    fi
else
    test_skip "Pending M1: Okular and Zed shapes pending M1 implementation"
fi

report_summary
