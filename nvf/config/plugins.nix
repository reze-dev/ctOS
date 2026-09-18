{ pkgs, ... }: {
  config.vim = {
    autocomplete = {
      nvim-cmp.enable = false;
      blink-cmp = {
        enable = true;
        friendly-snippets.enable = true;
        setupOpts = {
          keymap = {
            preset = "default";
            "<C-space>" = [
              "show"
              "show_documentation"
              "hide_documentation"
            ];
            "<C-e>" = [ "hide" ];
            "<CR>" = [
              "accept"
              "fallback"
            ];
            "<Tab>" = [
              "select_next"
              "snippet_forward"
              "fallback"
            ];
            "<S-Tab>" = [
              "select_prev"
              "snippet_backward"
              "fallback"
            ];
            "<C-j>" = [
              "select_next"
              "fallback"
            ];
            "<C-k>" = [
              "select_prev"
              "fallback"
            ];
            "<C-b>" = [
              "scroll_documentation_up"
              "fallback"
            ];
            "<C-f>" = [
              "scroll_documentation_down"
              "fallback"
            ];
          };
          appearance = {
            nerd_font_variant = "mono";
          };
          completion = {
            accept = {
              auto_brackets = {
                enabled = true;
              };
            };
            menu = {
              border = "rounded";
              winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None";
            };
            documentation = {
              auto_show = true;
              auto_show_delay_ms = 200;
              window = {
                border = "rounded";
                winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder";
              };
            };
            ghost_text = {
              enabled = true;
            };
          };
          signature = {
            enabled = true;
            window = {
              border = "rounded";
            };
          };
          fuzzy = {
            implementation = "prefer_rust";
          };
        };
      };
    };

    ui = {
      noice.enable = true;
      colorizer.enable = true;
      illuminate.enable = true;
      fastaction.enable = true;
    };

    statusline.lualine.enable = true;
    telescope.enable = true;
    filetree.neo-tree.enable = false; # We use oil-nvim instead
    binds.whichKey.enable = true;

    # Natively supported plugins mapped from your original config
    git.gitsigns.enable = true;
    tabline.nvimBufferline.enable = true;
    comments.comment-nvim.enable = true;
    notes.todo-comments.enable = true;
    navigation.harpoon.enable = true;
    utility.oil-nvim.enable = true;
    utility.motion.flash-nvim.enable = true;
    utility.motion.precognition.enable = true;
    binds.hardtime-nvim.enable = true;
    lsp.trouble.enable = true;

    extraPlugins = with pkgs.vimPlugins; {
      snacks-nvim = {
        package = snacks-nvim;
      };
      dressing-nvim = {
        package = dressing-nvim;
      };
      vim-tmux-navigator = {
        package = vim-tmux-navigator;
      };
      neotest = {
        package = neotest;
      };
      neotest-go = {
        package = neotest-go;
      };
      neotest-rust = {
        package = neotest-rust;
      };
      neotest-gtest = {
        package = neotest-gtest;
      };
      neotest-golang = {
        package = neotest-golang;
      };
      fixcursorhold-nvim = {
        package = FixCursorHold-nvim;
      };
      persistence-nvim = {
        package = persistence-nvim;
      };

      # Migrated plugins from lua config
      conform-nvim = {
        package = conform-nvim;
      };
      nvim-dap-ui = {
        package = nvim-dap-ui;
      };
      nvim-nio = {
        package = nvim-nio;
      };
      nvim-dap-virtual-text = {
        package = nvim-dap-virtual-text;
      };
      nvim-dap-go = {
        package = nvim-dap-go;
      };
      nvim-dap-python = {
        package = nvim-dap-python;
      };
      better-escape-nvim = {
        package = better-escape-nvim;
      };
      mini-ai = {
        package = mini-ai;
      };
      indent-blankline-nvim = {
        package = indent-blankline-nvim;
      };
      nvim-notify = {
        package = nvim-notify;
      };
      nvim-autopairs = {
        package = nvim-autopairs;
      };
      nvim-surround = {
        package = nvim-surround;
      };
      clangd_extensions-nvim = {
        package = clangd_extensions-nvim;
      };
      go-nvim = {
        package = go-nvim;
      };
      guihua-lua = {
        package = guihua-lua;
      };
      nvim-ts-context-commentstring = {
        package = nvim-ts-context-commentstring;
      };
      nvim-treesitter-textobjects = {
        package = nvim-treesitter-textobjects;
      };
      nvim-lint = {
        package = nvim-lint;
      };
      telescope-fzf-native-nvim = {
        package = telescope-fzf-native-nvim;
      };
      telescope-ui-select-nvim = {
        package = telescope-ui-select-nvim;
      };
      rose-pine = {
        package = rose-pine;
      };
      nvim-lspconfig = {
        package = nvim-lspconfig;
      };
    };
  };
}
