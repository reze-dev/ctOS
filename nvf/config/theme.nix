{ pkgs, ... }: {
  config.vim = {
    extraPlugins = with pkgs.vimPlugins; {
      base46 = {
        package = pkgs.vimUtils.buildVimPlugin {
          name = "base46";
          src = pkgs.fetchFromGitHub {
            owner = "AvengeMedia";
            repo = "base46";
            rev = "83522e02c6c3b4ea901c4bffd9e0a5e0371c1fe6";
            hash = "sha256-kwDMC6rYzJYECmGnwn8JiAbffUq7hAXcUH6gPSkk2uI=";
          };
          doCheck = false;
        };
      };
      monoglow-nvim = {
        package = pkgs.vimUtils.buildVimPlugin {
          name = "monoglow.nvim";
          src = pkgs.fetchFromGitHub {
            owner = "wnkz";
            repo = "monoglow.nvim";
            rev = "a249b1f55bfe9171e2f8aff7acf140f78ca4b2bb";
            hash = "sha256-EIslqnOIOLfQ7e7L1FvwfVfel6h+UPFIUcSgvp8zf0E=";
          };
          doCheck = false;
        };
      };
    };
    luaConfigRC.monoglow = "vim.cmd.colorscheme('monoglow')";
  };
}
