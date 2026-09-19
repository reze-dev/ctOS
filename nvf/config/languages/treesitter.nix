{ ... }: {
  config.vim = {
    treesitter = {
      enable = true;
      autotagHtml = true;
      context.enable = false;
      textobjects = {
        enable = true;
        setupOpts = {
          select = {
            enable = true;
            lookahead = true;
            keymaps = {
              "af" = {
                query = "@function.outer";
                desc = "Around function";
              };
              "if" = {
                query = "@function.inner";
                desc = "Inside function";
              };
              "ac" = {
                query = "@class.outer";
                desc = "Around class";
              };
              "ic" = {
                query = "@class.inner";
                desc = "Inside class";
              };
              "aa" = {
                query = "@parameter.outer";
                desc = "Around argument";
              };
              "ia" = {
                query = "@parameter.inner";
                desc = "Inside argument";
              };
              "al" = {
                query = "@loop.outer";
                desc = "Around loop";
              };
              "il" = {
                query = "@loop.inner";
                desc = "Inside loop";
              };
              "ai" = {
                query = "@conditional.outer";
                desc = "Around conditional";
              };
              "ii" = {
                query = "@conditional.inner";
                desc = "Inside conditional";
              };
              "ab" = {
                query = "@block.outer";
                desc = "Around block";
              };
              "ib" = {
                query = "@block.inner";
                desc = "Inside block";
              };
            };
          };
          move = {
            enable = true;
            goto_next_start = {
              "]f" = {
                query = "@function.outer";
                desc = "Next function start";
              };
              "]c" = {
                query = "@class.outer";
                desc = "Next class start";
              };
              "]a" = {
                query = "@parameter.inner";
                desc = "Next argument";
              };
            };
            goto_next_end = {
              "]F" = {
                query = "@function.outer";
                desc = "Next function end";
              };
              "]C" = {
                query = "@class.outer";
                desc = "Next class end";
              };
            };
            goto_previous_start = {
              "[f" = {
                query = "@function.outer";
                desc = "Previous function start";
              };
              "[c" = {
                query = "@class.outer";
                desc = "Previous class start";
              };
              "[a" = {
                query = "@parameter.inner";
                desc = "Previous argument";
              };
            };
            goto_previous_end = {
              "[F" = {
                query = "@function.outer";
                desc = "Previous function end";
              };
              "[C" = {
                query = "@class.outer";
                desc = "Previous class end";
              };
            };
          };
          swap = {
            enable = true;
            swap_next = {
              "<leader>cx" = {
                query = "@parameter.inner";
                desc = "Swap with next parameter";
              };
            };
            swap_previous = {
              "<leader>cX" = {
                query = "@parameter.inner";
                desc = "Swap with previous parameter";
              };
            };
          };
        };
      };
    };
  };
}
