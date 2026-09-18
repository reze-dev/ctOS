{ pkgs, ... }: {
  config.vim = {
    lsp.enable = true;
    treesitter.enable = true;
    languages = {
      enableFormat = true;
      enableTreesitter = true;
      enableDAP = true;
      clang.enable = true;
      rust = {
        enable = true;
        lsp.enable = false;
        dap.enable = false;
        extensions = {
          rustaceanvim.enable = true;
          crates-nvim.enable = true;
        };
      };
      go.enable = true;
      python.enable = true;
      lua.enable = true;
      html.enable = true;
      css.enable = true;
      typescript.enable = true;
      markdown.enable = true;
      nix.enable = true;
      bash.enable = true;
      json.enable = true;
      yaml.enable = true;
      toml.enable = true;
      docker.enable = true;
      cmake.enable = true;
      sql.enable = true;
    };
  };
}
