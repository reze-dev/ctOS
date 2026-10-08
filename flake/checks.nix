# Flake-parts module: Nix-native checks via `nix flake check`
{ self, inputs, ... }:

{
  perSystem =
    { pkgs, system, ... }:
    let
      lib = inputs.nixpkgs.lib;
      ctos = import ../lib/core.nix { inherit lib; };

    in
    {
      checks = {

        ctos-package = self.packages.${system}.ctos-shell;

        # Verify lib functions behave correctly
        lib-unit-tests =
          pkgs.runCommand "check-lib-functions"
            {
              nativeBuildInputs = [
                pkgs.nix
                pkgs.jq
              ];
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
                  ctos = import ${../lib/core.nix} { inherit (lib) lib; };
                in builtins.length (ctos.scanModules ${../modules})
              ')
              echo "scanModules found $MODULE_COUNT modules"
              if [ "$MODULE_COUNT" -lt 1 ]; then
                echo "FAIL: scanModules returned 0 modules"
                exit 1
              fi

              # Test: discoverHosts finds hosts
              HOSTS=$(${pkgs.nix}/bin/nix eval --impure --json --expr '
                let
                  lib = import ${inputs.nixpkgs} { system = "${system}"; };
                  ctos = import ${../lib/core.nix} { inherit (lib) lib; };
                in ctos.discoverHosts ${../hosts}
              ')
              echo "discoverHosts found: $HOSTS"
              echo "$HOSTS" | jq -e 'length > 0' > /dev/null || {
                echo "FAIL: discoverHosts returned 0 hosts"
                exit 1
              }

              # Test: mkProfile produces correct attrs
              PROFILE_KEYS=$(${pkgs.nix}/bin/nix eval --impure --json --expr '
                let
                  lib = import ${inputs.nixpkgs} { system = "${system}"; };
                  ctos = import ${../lib/core.nix} { inherit (lib) lib; };
                  profile = ctos.mkProfile ["boot" "ssh"];
                in builtins.attrNames profile.ctos.features
              ')
              echo "mkProfile keys: $PROFILE_KEYS"
              echo "$PROFILE_KEYS" | jq -e 'index("boot") and index("ssh")' > /dev/null || {
                echo "FAIL: mkProfile did not produce boot and ssh keys"
                exit 1
              }

              echo "=== All lib tests passed ==="
              touch $out
            '';

        # Gate QML on hard errors.
        #
        # qmllint cannot be judged by exit code: it exits 0 even on a syntax
        # error, and only goes non-zero under --max-warnings. So diagnostics are
        # parsed from --json instead, and a file fails only on the categories
        # that mean "will not compile":
        #
        #   id == "syntax"   a parse error
        #   type == "error"  anything qmllint itself escalated
        #
        # Everything else is deliberately non-fatal. The tree carries a large
        # backlog of style and layout advice and failing on it would make the
        # gate useless as a regression signal.
        qml-lint =
          pkgs.runCommand "check-qml-lint"
            {
              nativeBuildInputs = [
                pkgs.qt6.qtdeclarative
                pkgs.qt6.qtshadertools
                pkgs.quickshell
                pkgs.jq
              ];
              QML2_IMPORT_PATH = lib.concatStringsSep ":" [
                "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml"
                "${pkgs.qt6.qtshadertools}/lib/qt-6/qml"
                "${pkgs.quickshell}/lib/qt-6/qml"
              ];
            }
            ''
              cp -R ${../shell} ./shell-src
              chmod -R u+w ./shell-src

              export QML_IMPORT_PATH="$QML2_IMPORT_PATH"
              export QML2_IMPORT_PATH
              export QT_QPA_PLATFORM=offscreen
              export QT_QUICK_BACKEND=software

              echo "=== Linting QML ==="

              mapfile -t FILES < <(find ./shell-src/desktop ./shell-src/greeter \
                                   ./shell-src/shell.qml ./shell-src/greeter.qml \
                                   -name '*.qml' | sort)

              echo "checking ''${#FILES[@]} files"

              qmllint --bare --ignore-settings --json report.json -I ./shell-src \
                "''${FILES[@]}" > /dev/null 2>&1 || true

              if [ ! -s report.json ]; then
                echo "FAIL: qmllint produced no report"
                exit 1
              fi

              # Surface every fatal diagnostic with its location.
              jq -r '
                .files[] as $f
                | $f.warnings[]?
                | select(.id == "syntax" or .type == "error")
                | "  \($f.filename):\(.line):\(.column) [\(.id)] \(.message)"
              ' report.json | while IFS= read -r line; do echo "$line"; done > fatal.txt

              FAILED=$(wc -l < fatal.txt)
              if [ "$FAILED" -ne 0 ]; then
                echo "FAIL: $FAILED fatal diagnostic(s)"
                cat fatal.txt
                exit 1
              fi

              # Advisory only. Type-level diagnostics are NOT available here:
              # QtQuick's qmldir resolves through `linktarget Qt6::qtquick2plugin`,
              # which qmllint cannot satisfy from a Nix sandbox, so every file
              # also carries import-resolution warnings. Those are expected and
              # are not a signal about the code. Parse checking still works, and
              # that is what this gate relies on.
              TOTAL=$(jq '[.files[].warnings[]?] | length' report.json)
              SYNTAX=$(jq '[.files[].warnings[]? | select(.id == "syntax")] | length' report.json)
              echo "  $TOTAL diagnostic(s), $SYNTAX of them parse errors"

              echo "=== QML lint passed (parse-level; type resolution unavailable in sandbox) ==="
              touch $out
            '';

        # Verify the installer package builds
      };
    };
}
