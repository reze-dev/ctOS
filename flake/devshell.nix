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

        if [ "''${CTOS_INPUT:-0}" = "1" ]; then
          unset WLR_LIBINPUT_NO_DEVICES
        else
          export WLR_LIBINPUT_NO_DEVICES=1
        fi

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
          #
          # fontTools reads font internals directly -- cmap lookups, glyph
          # counts, family names. Determining which codepoint an icon font uses
          # for a given glyph otherwise means hand-parsing the cmap tables and
          # matching rendered bitmaps against upstream artwork, which is how four
          # near-identical neighbours got mistaken for the right glyph.
          python3
          python3Packages.pillow
          python3Packages.fonttools
          imagemagick

          # Synthetic input.
          #
          # The headless seat has no pointer device (see WLR_LIBINPUT_NO_DEVICES
          # in ctos-shot.sh), so swaymsg can move the cursor in sway's model but
          # no motion or button event ever reaches a client. Every hover and click
          # path therefore has to be faked -- by forcing _isHovered, or by calling
          # handlers directly -- and a real interaction bug can survive that. Two
          # did: a click gate unreachable from the state the pointer puts the
          # notch in, and icons sitting 2px below centre.
          #
          # ydotool creates a uinput device, which libinput picks up as a real
          # pointer, so events travel the same path as a physical mouse --
          # including the Region input mask, which is otherwise unverifiable.
          # wtype does the same for the keyboard, so Escape-to-dismiss can be
          # exercised rather than reasoned about.
          #
          # Both need write access to /dev/uinput, which is root:root 0600 by
          # default. See the note the shell prints below.
          ydotool
          wtype

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
          echo "  Synthetic input (needs writable /dev/uinput):"
          echo "    CTOS_INPUT=1 ctos-shot out.png   — keep input devices live"
          echo "    CTOS_KEEP=1 ctos-shot out.png   — leave the compositor up"
          echo "    then: swaymsg seat - cursor set X Y / ydotool click 0xC0"
          echo ""
          echo "  Headless compositor env is preset (sway + pixman)."
          echo ""

          # ydotool and wtype are installed, but they are useless without write
          # access to /dev/uinput, which is root:root 0600 on NixOS by default.
          # Say so once, with the fix, rather than letting a synthetic-input test
          # fail with a bare permission error.
          if [ -e /dev/uinput ] && ! ( : > /dev/uinput ) 2>/dev/null; then
            echo "  Synthetic input: /dev/uinput is present but not writable."
            echo "    CTOS_INPUT=1 plus ydotool/wtype will fail until you add:"
            echo ""
            echo "      services.udev.extraRules = \"SUBSYSTEM==\\\"misc\\\", KERNEL==\\\"uinput\\\", MODE=\\\"0660\\\", GROUP=\\\"input\\\", OPTIONS+=\\\"static_node=uinput\\\"\";"
            echo ""
            echo "    (reload with: sudo nixos-rebuild switch)"
            echo ""
          fi
        '';
      };
    };
}
