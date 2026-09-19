{ ... }:
{
  imports = [
    # Core
    ./config/core/options.nix
    ./config/core/globals.nix
    ./config/core/keymaps.nix
    ./config/core/autocmds.nix

    # UI
    ./config/ui/theme.nix
    ./config/ui/statusline.nix
    ./config/ui/tabline.nix
    ./config/ui/noice.nix
    ./config/ui/visuals.nix

    # Editor
    ./config/editor/completion.nix
    ./config/editor/format.nix
    ./config/editor/lint.nix
    ./config/editor/comments.nix
    ./config/editor/editing.nix
    ./config/editor/whichkey.nix

    # Tools
    ./config/tools/tooling.nix
    ./config/tools/telescope.nix
    ./config/tools/navigation.nix
    ./config/tools/git.nix
    ./config/tools/debugger.nix
    ./config/tools/testing.nix

    # Languages
    ./config/languages/treesitter.nix
    ./config/languages/lsp.nix
    ./config/languages/languages.nix
  ];
}
