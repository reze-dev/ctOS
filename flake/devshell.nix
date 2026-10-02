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

      # Headless layer-shell rendering.
      #
      # The shell is wlr-layer-shell only, so verifying it visually needs a real
      # compositor -- Qt's offscreen platform cannot present a layer surface.
      # sway with WLR_BACKENDS=headless and the pixman renderer gives one with
      # no GPU and no X server, which is what makes this usable over SSH and in
      # CI. See shell/tools/README.md.
      headlessEnv = ''
        export WLR_BACKENDS=headless
        export WLR_RENDERER=pixman
        export WLR_LIBINPUT_NO_DEVICES=1
        export LIBGL_ALWAYS_SOFTWARE=1
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
          # qmltestrunner; qttools provides none of them. qtshadertools carries
          # the Qt Quick shader modules the software renderer needs.
          qt6.qtdeclarative
          qt6.qtshadertools
          quickshell

          # Headless compositor for layer-shell rendering, plus capture.
          sway
          grim
          slurp
          wayland-utils
          xwayland-satellite
          # swrast/llvmpipe, used when pixman is unavailable or when a shell
          # surface needs real GL.
          mesa

          # Image inspection: sample exact pixel values out of a render and
          # diff two of them. Pillow is what makes "is that actually #EB4ADF"
          # a checkable question.
          python3
          python3Packages.pillow
          imagemagick

          # Fonts. Theme.fontFamily is "Maple Mono"; without the same faces the
          # render does not match what the host draws.
          fontconfig
          maple-mono.truetype
          nerd-fonts.jetbrains-mono
          nerd-fonts.monaspace
          nerd-fonts.caskaydia-cove
          nerd-fonts.symbols-only

          # Session bus. Several services degrade to available=false without
          # one, which is worth exercising deliberately but makes unrelated
          # failures noisier.
          dbus

          opencode
        ];

        shellHook = ''
          ${qtEnv}
          ${headlessEnv}

          export PATH="$PWD/shell/tools:$PATH"

          ctos-qmllint() {
            local fail=0
            while IFS= read -r f; do
              qmllint --bare --ignore-settings -I shell "$f" || fail=1
            done < <(find shell/desktop shell/greeter shell/shell.qml shell/greeter.qml -name '*.qml' | sort)
            return $fail
          }

          ctos-shot() { "$PWD/shell/tools/ctos-shot.sh" "$@"; }
          ctos-pick() { python3 "$PWD/shell/tools/ctos-pick.py" "$@"; }

          echo "❄️  ctOS development shell"
          echo ""
          echo "  nix flake check --impure   — run all checks"
          echo "  nix fmt                    — format all Nix files"
          echo "  ctos-qmllint <file>        — lint a QML file"
          echo "  ctos-shot                  — render the shell headless and screenshot it"
          echo "  ctos-pick out.png          — dominant colours in a render"
          echo "  ctos-pick out.png --at X,Y — exact pixel value"
          echo ""
          echo "  Headless compositor env is preset (sway + pixman)."
          echo ""
        '';
      };
    };
}
