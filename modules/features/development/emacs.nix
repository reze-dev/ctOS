{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.northstar.features.emacs;

  # Build the isolated toolkit path exclusively for Emacs and Doom
  emacsTools =
    (lib.optionals cfg.doomEmacs.enable [
      pkgs.git
      pkgs.ripgrep
      pkgs.fd
      pkgs.findutils
      pkgs.coreutils
      pkgs.gnumake
      pkgs.cmake
      pkgs.libtool
      pkgs.sqlite
      pkgs.unzip
      pkgs.gnutar
      pkgs.gcc
      pkgs.fontconfig
      pkgs.zig
    ])
    ++ (lib.optionals cfg.lsp.enable cfg.lsp.servers)
    ++ (lib.optionals cfg.dap.enable cfg.dap.debuggers)
    ++ (lib.optionals cfg.formatters.enable cfg.formatters.tools)
    ++ cfg.extraPackages;

  emacsToolsBinPath = lib.makeBinPath emacsTools;

  wrappedEmacsPackage = pkgs.symlinkJoin {
    name = "emacs-isolated-${cfg.package.version or "custom"}";
    paths = [ cfg.package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in $out/bin/*; do
        if [ -f "$bin" ] && [ -x "$bin" ]; then
          wrapProgram "$bin" \
            --prefix PATH : "${emacsToolsBinPath}" \
            --set EMACS_ISOLATED_PATH "${emacsToolsBinPath}"
        fi
      done
    '';
  };

  # Helper CLI wrapper for `doom` binary that injects the isolated PATH
  doomWrapper = pkgs.writeShellScriptBin "doom" ''
    DOOM_BIN="$HOME/.config/emacs/bin/doom"
    if [ ! -f "$DOOM_BIN" ]; then
      echo "Doom Emacs is not installed at $DOOM_BIN."
      echo "To install Doom Emacs, run:"
      echo "  git clone ${cfg.doomEmacs.repoUrl} ~/.config/emacs"
      echo "  doom install"
      exit 1
    fi
    exec env PATH="${emacsToolsBinPath}:$PATH" EMACS_ISOLATED_PATH="${emacsToolsBinPath}" "$DOOM_BIN" "$@"
  '';
in
{
  options.northstar.features.emacs = {
    enable = lib.mkEnableOption "Self-contained Emacs development environment";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.emacs-pgtk;
      description = "Base Emacs package to wrap with isolated environment.";
    };

    daemon = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Emacs systemd user daemon service.";
      };
    };

    doomEmacs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Include Doom Emacs build and runtime dependencies in Emacs isolated PATH.";
      };

      repoUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://github.com/doomemacs/doomemacs";
        description = "Git repository URL for Doom Emacs.";
      };
    };

    lsp = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable language server protocol (LSP) suite isolated to Emacs.";
      };

      servers = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          nixd
          nil
          pyright
          rust-analyzer
          gopls
          clang-tools
          typescript-language-server
          vscode-langservers-extracted
          yaml-language-server
          marksman
          bash-language-server
          zls
          jdt-language-server
          taplo
          emacs-lsp-booster
        ];
        description = "List of LSP server packages included exclusively in Emacs PATH.";
      };
    };

    dap = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable DAP debuggers isolated to Emacs.";
      };

      debuggers = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          gdb
          lldb
          delve
          python3Packages.debugpy
        ];
        description = "List of debugger packages included exclusively in Emacs PATH.";
      };
    };

    formatters = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable code formatters isolated to Emacs.";
      };

      tools = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          nixfmt
          prettier
          ruff
          uv
          shfmt
          shellcheck
          rustfmt
          gofumpt
          taplo
        ];
        description = "List of code formatter and environment management tools included exclusively in Emacs PATH.";
      };
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages to expose exclusively to Emacs and Doom.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.emacs = lib.mkIf cfg.daemon.enable {
      enable = true;
      package = wrappedEmacsPackage;
    };

    environment.systemPackages = [
      wrappedEmacsPackage
    ]
    ++ lib.optional cfg.doomEmacs.enable doomWrapper;
  };
}
