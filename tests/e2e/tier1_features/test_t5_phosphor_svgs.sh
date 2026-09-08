#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 1: Phosphor System SVGs
# Source: ORIGINAL_REQUEST §R1.1, TEST_INFRA.md §Feature 1, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

ICON_DIR="${PROJECT_ROOT}/shell/desktop/assets/icons"
NIX_PACKAGE="${PROJECT_ROOT}/shell/nix/package.nix"

test_case "T1.15.1" "Phosphor SVGs: Assets directory exists in desktop/assets/icons/"
if [[ -d "${ICON_DIR}" ]]; then
    assert_dir_exists "${ICON_DIR}" "Phosphor SVG directory must exist"
else
    test_skip "Pending M1: shell/desktop/assets/icons/ not yet created"
fi

test_case "T1.15.2" "Phosphor SVGs: Essential system SVGs present (battery, wifi, volume, mic, lock, reboot, power, logout)"
if [[ -d "${ICON_DIR}" ]]; then
    missing=0
    for icon in "battery" "wifi" "volume" "microphone" "lock" "reboot" "power" "logout"; do
        if ! ls "${ICON_DIR}" | grep -q "${icon}"; then
            missing=$((missing + 1))
        fi
    done
    assert_eq "0" "${missing}" "Essential system SVGs must be present in ${ICON_DIR}"
else
    test_skip "Pending M1: Phosphor SVG asset bundle pending implementation"
fi

test_case "T1.15.3" "Phosphor SVGs: Files contain valid vector SVG geometry (<svg, viewBox, <path)"
if [[ -d "${ICON_DIR}" ]] && [[ $(find "${ICON_DIR}" -name "*.svg" | wc -l) -gt 0 ]]; then
    first_svg=$(find "${ICON_DIR}" -name "*.svg" | head -n 1)
    assert_grep "<svg" "${first_svg}" "SVG must have <svg root element"
    assert_grep "viewBox=" "${first_svg}" "SVG must declare viewBox for scaling"
    assert_grep "<path" "${first_svg}" "SVG must contain vector path geometry"
else
    test_skip "Pending M1: SVG vector files not yet populated"
fi

test_case "T1.15.4" "Phosphor SVGs: Clean geometric linear styling without raster bitmaps"
if [[ -d "${ICON_DIR}" ]] && [[ $(find "${ICON_DIR}" -name "*.svg" | wc -l) -gt 0 ]]; then
    assert_not_grep -i "image/png" "${ICON_DIR}" "Phosphor SVGs must be pure vector without embedded PNG rasters"
    assert_not_grep -i "<image" "${ICON_DIR}" "Phosphor SVGs must not contain raster <image> elements"
else
    test_skip "Pending M1: Vector validation pending icon asset bundling"
fi

test_case "T1.15.5" "Phosphor SVGs: Nix packaging derivation packages desktop/assets/ to share/ctos"
if [[ -f "${NIX_PACKAGE}" ]]; then
    assert_grep "share/ctos" "${NIX_PACKAGE}" "package.nix must install shell to share/ctos"
    # Ensure package.nix copies entire directory recursively
    assert_grep 'cp -R \. "\$out/share/ctos/"' "${NIX_PACKAGE}" "package.nix must recursively copy shell folder to share/ctos"
else
    assert_file_exists "${NIX_PACKAGE}"
fi

report_summary
