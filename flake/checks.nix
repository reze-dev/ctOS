# Flake-parts module: Nix-native checks via `nix flake check`
{ self, inputs, ... }:

{
  perSystem =
    { pkgs, system, ... }:
    let
      lib = inputs.nixpkgs.lib;
      northstar = import ../lib/core.nix { inherit lib; };

    in
    {
      checks = {

        # Verify lib functions behave correctly
        lib-unit-tests = pkgs.runCommand "check-lib-functions"
          {
            nativeBuildInputs = [ pkgs.nix pkgs.jq ];
            NIX_CONF_DIR = pkgs.writeTextDir "nix.conf" ''
              experimental-features = nix-command flakes pipe-operators
            '';
          }
          ''
            export NIX_STATE_DIR=$TMPDIR/nix
            export NIX_CACHE_DIR=$TMPDIR/nix-cache
            mkdir -p $NIX_STATE_DIR $NIX_CACHE_DIR

            echo "=== Testing lib functions ==="
            
            # Test: scanModules finds modules
            MODULE_COUNT=$(${pkgs.nix}/bin/nix eval --impure --expr '
              let
                lib = import ${inputs.nixpkgs} { system = "${system}"; };
                northstar = import ${../lib/core.nix} { inherit (lib) lib; };
              in builtins.length (northstar.scanModules ${../modules})
            ')
            echo "scanModules found $MODULE_COUNT modules"
            if [ "$MODULE_COUNT" -lt 1 ]; then
              echo "FAIL: scanModules returned 0 modules"
              exit 1
            fi

            # Test: discoverHosts finds example
            HOSTS=$(${pkgs.nix}/bin/nix eval --impure --json --expr '
              let
                lib = import ${inputs.nixpkgs} { system = "${system}"; };
                northstar = import ${../lib/core.nix} { inherit (lib) lib; };
              in northstar.discoverHosts ${../hosts}
            ')
            echo "discoverHosts found: $HOSTS"
            echo "$HOSTS" | jq -e 'index("example")' > /dev/null || {
              echo "FAIL: discoverHosts did not find example"
              exit 1
            }

            # Test: mkProfile produces correct attrs
            PROFILE_KEYS=$(${pkgs.nix}/bin/nix eval --impure --json --expr '
              let
                lib = import ${inputs.nixpkgs} { system = "${system}"; };
                northstar = import ${../lib/core.nix} { inherit (lib) lib; };
                profile = northstar.mkProfile ["boot" "ssh"];
              in builtins.attrNames profile.northstar.features
            ')
            echo "mkProfile keys: $PROFILE_KEYS"
            echo "$PROFILE_KEYS" | jq -e 'index("boot") and index("ssh")' > /dev/null || {
              echo "FAIL: mkProfile did not produce boot and ssh keys"
              exit 1
            }

            echo "=== All lib tests passed ==="
            touch $out
          '';

        # Verify the installer package builds
        installer-builds = self.packages.${system}.installer;
      };
    };
}
