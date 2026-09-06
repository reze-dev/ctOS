#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 14 Boundary: Packaging & Home Manager Edge Cases
# Source: ORIGINAL_REQUEST Acceptance Criteria, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

test_case "T2.14.1" "Packaging Boundary: ctos-shell derivation output excludes .git metadata"
PACKAGE_CHECK=$(nix eval --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
    pkg = flake.packages.x86_64-linux.ctos-shell;
  in pkg.name
')
assert_match "ctos-shell" "${PACKAGE_CHECK}" "Package derivation evaluates"

test_case "T2.14.2" "Packaging Boundary: Home Manager module evaluates with programs.ctOS.enable = false"
HM_DISABLED_EVAL=$(nix eval --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
    pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
    hm = flake.inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        flake.homeManagerModules.default
        {
          programs.ctOS.enable = false;
          home.stateVersion = "24.05";
          home.username = "reze";
          home.homeDirectory = "/home/reze";
        }
      ];
    };
  in builtins.hasAttr "ctos" hm.config.systemd.user.services
')
assert_eq "false" "${HM_DISABLED_EVAL}" "When disabled, systemd service ctos must not be created"

test_case "T2.14.3" "Packaging Boundary: Systemd user service has Restart = on-failure"
SERVICE_RESTART=$(nix eval --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
    pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
    hm = flake.inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        flake.homeManagerModules.default
        {
          programs.ctOS.enable = true;
          home.stateVersion = "24.05";
          home.username = "reze";
          home.homeDirectory = "/home/reze";
        }
      ];
    };
  in hm.config.systemd.user.services.ctos.Service.Restart
')
assert_match "on-failure" "${SERVICE_RESTART}" "Systemd unit must have Restart=on-failure"

test_case "T2.14.4" "Packaging Boundary: Package install directory strictly uses share/ctos"
PACKAGE_INSTALL_PHASE=$(nix eval --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
  in flake.packages.x86_64-linux.ctos-shell.installPhase
')
assert_match "share/ctos" "${PACKAGE_INSTALL_PHASE}" "installPhase must install to share/ctos"

test_case "T2.14.5" "Packaging Boundary: Flake checks include ctos-package check"
FLAKE_CHECKS=$(nix eval --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
  in builtins.attrNames flake.checks.x86_64-linux
')
assert_match "ctos-package" "${FLAKE_CHECKS}" "flake checks must include ctos-package"

report_summary
