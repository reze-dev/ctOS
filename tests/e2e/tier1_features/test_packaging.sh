#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 14: Nix Flake & Home Manager Packaging
# Source: ORIGINAL_REQUEST Acceptance Criteria, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

test_case "T1.14.1" "Nix Packaging: nix flake check --no-build passes"
assert_exit_code 0 nix flake check --no-build

test_case "T1.14.2" "Nix Packaging: nix eval .#ctos-shell.drvPath succeeds"
assert_exit_code 0 nix eval .#ctos-shell.drvPath

test_case "T1.14.3" "Nix Packaging: nix build .#ctos-shell builds cleanly"
assert_exit_code 0 nix build .#ctos-shell --no-link

test_case "T1.14.4" "Nix Packaging: Home Manager module evaluates with programs.ctOS.enable = true"
HM_EVAL_CMD=(
    nix eval --impure --expr '
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
    in hm.config.systemd.user.services.ctos.Service.ExecStart
    '
)
assert_exit_code 0 "${HM_EVAL_CMD[@]}"

test_case "T1.14.5" "Nix Packaging: Systemd user service starts shell.qml"
EXEC_START=$(nix eval --impure --expr '
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
  in hm.config.systemd.user.services.ctos.Service.ExecStart
')
assert_match "shell\.qml" "${EXEC_START}" "systemd service ExecStart must reference shell.qml"

report_summary
