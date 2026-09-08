#!/usr/bin/env bash
# ==============================================================================
# Tier 4 - Scenario 5: Full Packaging & Home Manager Integration
# Exercised: Flake check, Nix build, HM evaluation, systemd service
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

test_case "T4.05" "Real-World Scenario 5: End-to-End Packaging and Evaluation Pipeline"
# Step 1: Flake check
assert_exit_code 0 nix flake check --no-build

# Step 2: Build package
assert_exit_code 0 nix build .#ctos-shell --no-link

# Step 3: Home Manager evaluation
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

report_summary
