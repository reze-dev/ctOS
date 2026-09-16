#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

test_assert() {
    local desc="$1"
    local condition="$2"
    if eval "$condition"; then
        echo "  [PASS] $desc"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $desc"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== [TEST SUITE] Milestone 2 Greeter Visual & Style Polish Verification ==="

echo "--- Phase 1: QML Visual & Blur Invariants (MainLayout.qml) ---"
test_assert "M2.QML.01: MainLayout imports Qt5Compat.GraphicalEffects" \
    "grep -q 'import Qt5Compat.GraphicalEffects' shell/greeter/components/MainLayout.qml"

test_assert "M2.QML.02: backgroundImage has fillMode PreserveAspectCrop" \
    "grep -q 'fillMode: Image.PreserveAspectCrop' shell/greeter/components/MainLayout.qml"

test_assert "M2.QML.03: backgroundImage has visible: false" \
    "grep -q 'visible: false' shell/greeter/components/MainLayout.qml"

test_assert "M2.QML.04: GaussianBlur is present and sources backgroundImage" \
    "grep -q 'GaussianBlur {' shell/greeter/components/MainLayout.qml && grep -q 'source: backgroundImage' shell/greeter/components/MainLayout.qml"

test_assert "M2.QML.05: GaussianBlur radius is 48" \
    "grep -q 'radius: 48' shell/greeter/components/MainLayout.qml"

test_assert "M2.QML.06: GaussianBlur samples is 24" \
    "grep -q 'samples: 24' shell/greeter/components/MainLayout.qml"

test_assert "M2.QML.07: GaussianBlur cached is true" \
    "grep -q 'cached: true' shell/greeter/components/MainLayout.qml"

test_assert "M2.QML.08: Frosted tint Rectangle is present with #18000000" \
    "grep -q 'id: frostedTint' shell/greeter/components/MainLayout.qml && grep -q 'color: \"#18000000\"' shell/greeter/components/MainLayout.qml"

test_assert "M2.QML.09: qmllint passes on MainLayout.qml" \
    "qmllint -I /nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/lib/qt-6/qml -I /nix/store/10553j4116y6jllliqpg5kz7d35bblab-qtdeclarative-6.11.2/lib/qt-6/qml -I /nix/store/m1y5myv0v3aph5qgz05xa0m64s48vk52-qt5compat-6.11.2/lib/qt-6/qml -I shell shell/greeter/components/MainLayout.qml > /dev/null 2>&1"

test_assert "M2.QML.10: MainLayout.qml adheres to formatting rules" \
    "python3 tests/e2e/harness/qml_inspector.py check-format shell/greeter/components/MainLayout.qml > /dev/null 2>&1"


echo "--- Phase 2: Font Streamlining (Maple Mono) ---"
test_assert "M2.FONT.01: GeneralDto.qml fontFamily is Maple Mono" \
    "grep -q 'property string fontFamily: \"Maple Mono\"' shell/greeter/config/GeneralDto.qml"

test_assert "M2.FONT.02: shell/common/Theme.qml fontFamily is Maple Mono" \
    "grep -q 'property string fontFamily: \"Maple Mono\"' shell/common/Theme.qml"

test_assert "M2.FONT.03: qml_inspector reports GeneralDto.qml fontFamily == Maple Mono" \
    "python3 tests/e2e/harness/qml_inspector.py has-property shell/greeter/config/GeneralDto.qml fontFamily --type string > /dev/null 2>&1"

test_assert "M2.FONT.04: qml_inspector reports Theme.qml fontFamily == Maple Mono" \
    "python3 tests/e2e/harness/qml_inspector.py has-property shell/common/Theme.qml fontFamily --type string > /dev/null 2>&1"

test_assert "M2.FONT.05: Zero occurrences of JetBrainsMono in greeter & common QML" \
    "! grep -rq 'JetBrainsMono' shell/greeter/ shell/common/"


echo "--- Phase 3: Compositor & Cursor Enforcement ---"
test_assert "M2.CUR.01: Hyprland conf defines XCURSOR_THEME Bibata-Modern-Classic" \
    "grep -q 'env = XCURSOR_THEME,Bibata-Modern-Classic' shell/greeter/examples/greeter.hyprland.conf"

test_assert "M2.CUR.02: Hyprland conf defines XCURSOR_SIZE 24" \
    "grep -q 'env = XCURSOR_SIZE,24' shell/greeter/examples/greeter.hyprland.conf"

test_assert "M2.CUR.03: Hyprland conf defines HYPRCURSOR_THEME Bibata-Modern-Classic" \
    "grep -q 'env = HYPRCURSOR_THEME,Bibata-Modern-Classic' shell/greeter/examples/greeter.hyprland.conf"

test_assert "M2.CUR.04: Hyprland conf defines HYPRCURSOR_SIZE 24" \
    "grep -q 'env = HYPRCURSOR_SIZE,24' shell/greeter/examples/greeter.hyprland.conf"

test_assert "M2.CUR.05: Hyprland conf executes hyprctl setcursor Bibata-Modern-Classic 24" \
    "grep -q 'exec-once = hyprctl setcursor Bibata-Modern-Classic 24' shell/greeter/examples/greeter.hyprland.conf"

test_assert "M2.CUR.06: Niri kdl defines environment XCURSOR_THEME Bibata-Modern-Classic" \
    "grep -q 'XCURSOR_THEME \"Bibata-Modern-Classic\"' shell/greeter/examples/greeter.niri.kdl"

test_assert "M2.CUR.07: Niri kdl defines environment XCURSOR_SIZE 24" \
    "grep -q 'XCURSOR_SIZE \"24\"' shell/greeter/examples/greeter.niri.kdl"

test_assert "M2.CUR.08: Niri kdl defines cursor block xcursor-theme Bibata-Modern-Classic" \
    "grep -q 'xcursor-theme \"Bibata-Modern-Classic\"' shell/greeter/examples/greeter.niri.kdl"

test_assert "M2.CUR.09: Niri kdl defines cursor block xcursor-size 24" \
    "grep -q 'xcursor-size 24' shell/greeter/examples/greeter.niri.kdl"

test_assert "M2.CUR.10: Niri validate parses greeter.niri.kdl successfully" \
    "niri validate -c shell/greeter/examples/greeter.niri.kdl > /dev/null 2>&1"


echo "--- Phase 4: NixOS Greeter Module & README Synchronization ---"
test_assert "M2.NIX.01: greeter.nix exports XCURSOR_THEME Bibata-Modern-Classic" \
    "grep -q 'export XCURSOR_THEME=Bibata-Modern-Classic' modules/features/desktop/greeter.nix"

test_assert "M2.NIX.02: greeter.nix exports XCURSOR_SIZE 24" \
    "grep -q 'export XCURSOR_SIZE=24' modules/features/desktop/greeter.nix"

test_assert "M2.NIX.03: greeter.nix exports HYPRCURSOR_THEME Bibata-Modern-Classic" \
    "grep -q 'export HYPRCURSOR_THEME=Bibata-Modern-Classic' modules/features/desktop/greeter.nix"

test_assert "M2.NIX.04: greeter.nix exports HYPRCURSOR_SIZE 24" \
    "grep -q 'export HYPRCURSOR_SIZE=24' modules/features/desktop/greeter.nix"

test_assert "M2.NIX.05: greeter.nix exports XCURSOR_PATH with bibata-cursors" \
    "grep -q 'export XCURSOR_PATH=\"\${pkgs.bibata-cursors}/share/icons' modules/features/desktop/greeter.nix"

test_assert "M2.NIX.06: greeter.nix exports XDG_DATA_DIRS with bibata-cursors" \
    "grep -q 'export XDG_DATA_DIRS=\"\${pkgs.bibata-cursors}/share' modules/features/desktop/greeter.nix"

test_assert "M2.NIX.07: greeter.nix adds bibata-cursors and qt5compat to systemPackages" \
    "grep -q 'environment.systemPackages = \[ pkgs.bibata-cursors pkgs.kdePackages.qt5compat \];' modules/features/desktop/greeter.nix"

test_assert "M2.NIX.08: greeter.nix config.json defines fontFamily = Maple Mono" \
    "grep -q 'fontFamily = \"Maple Mono\";' modules/features/desktop/greeter.nix"

test_assert "M2.NIX.09: nix-instantiate --parse succeeds on greeter.nix" \
    "nix-instantiate --parse modules/features/desktop/greeter.nix > /dev/null 2>&1"

test_assert "M2.NIX.10: greeter.nix exports QML2_IMPORT_PATH with qt5compat" \
    "grep -q 'export QML2_IMPORT_PATH=\"\${pkgs.kdePackages.qt5compat}/lib/qt-6/qml' modules/features/desktop/greeter.nix"

test_assert "M2.DOC.01: README.md documents Maple Mono font" \
    "grep -q 'Maple Mono' shell/greeter/README.md"

test_assert "M2.DOC.02: README.md documents Bibata-Modern-Classic cursor" \
    "grep -q 'Bibata-Modern-Classic' shell/greeter/README.md"

test_assert "M2.DOC.03: README.md has zero JetBrainsMono occurrences" \
    "! grep -q 'JetBrainsMono' shell/greeter/README.md"


echo "--- Phase 5: Isolation & Git Constraints ---"
test_assert "M2.ISO.01: Tier 1 isolation tests pass" \
    "bash tests/e2e/tier1_features/test_greeter_isolation.sh > /dev/null 2>&1"

test_assert "M2.ISO.02: Tier 2 boundary tests pass" \
    "bash tests/e2e/tier2_boundaries/test_greeter_isolation_boundaries.sh > /dev/null 2>&1"

test_assert "M2.ISO.03: Tier 4 isolation audit passes" \
    "bash tests/e2e/tier4_real_world/test_greeter_isolation_audit.sh > /dev/null 2>&1"

test_assert "M2.GIT.01: Zero new commits made (HEAD remains config(hyprland): change gap thickness)" \
    "[ \"\$(git log -1 --format=%s)\" = 'config(hyprland): change gap thickness' ]"

test_assert "M2.GIT.02: Exactly 7 files modified for Milestone 2" \
    "[ \$(git status --porcelain | grep '^ M' | wc -l) -eq 7 ]"

echo ""
echo "========================================================"
echo "Milestone 2 Test Summary: Total: $((PASS + FAIL)) | Passed: $PASS | Failed: $FAIL"
echo "========================================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
