# Flake-parts module: development shell for contributors
{
  inputs,
  lib,
  ...
}:

{
  perSystem =
    { pkgs, system, ... }:
    let
      # Qt modules are pinned to the same Qt the shell builds against. Mixing
      # these with the host's Qt produces a plugin layout where qmllint and
      # qmltestrunner start, exit 0, and silently load nothing.
      qt6 = pkgs.qt6;

      qmlImports = lib.concatStringsSep ":" [
        "${qt6.qtdeclarative}/lib/qt-6/qml"
        "${qt6.qtshadertools}/lib/qt-6/qml"
        "${pkgs.quickshell}/lib/qt-6/qml"
      ];

      qtEnv = ''
        export QML2_IMPORT_PATH="${qmlImports}"
        export QT_PLUGIN_PATH="${qt6.qtbase}/lib/qt-6/plugins"
        export QT_QPA_PLATFORM=offscreen
        export QT_QUICK_BACKEND=software
      '';
    in
    {
      devShells.default = pkgs.mkShell {
        name = "ctos-dev";
        packages = with pkgs; [
          # Nix tooling
          inputs.determinate.packages.${system}.default
          nixfmt
          nil
          nix-diff

          # General
          git
          jq

          # QML tooling. qtdeclarative provides qml, qmlscene, qmllint and
          # qmltestrunner; qtshadertools carries the Qt Quick shader modules the
          # software renderer needs for headless tests.
          qt6.qtdeclarative
          qt6.qtshadertools
          quickshell
        ];

        shellHook = ''
          ${qtEnv}

          ctos-qmllint() {
            local fail=0
            while IFS= read -r f; do
              if ! qmllint --bare -I shell "$f"; then
                fail=1
              fi
            done < <(find shell/desktop shell/greeter shell/shell.qml shell/greeter.qml -name '*.qml' | sort)
            return $fail
          }

          export -f ctos-qmllint 2>/dev/null || true

          echo "❄️  ctOS development shell"
          echo ""
          echo "  nix flake check --impure   — run all checks"
          echo "  nix fmt                    — format all Nix files"
          echo "  ctos-qmllint               — lint every QML file in the shell"
          echo "  nix build .#ctos-shell     — build the shell package"
          echo ""
        '';
      };
    };
}
