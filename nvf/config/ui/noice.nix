{ pkgs, lib, ... }: {
  config.vim = {
    ui.noice = {
      enable = true;
      setupOpts = {
        lsp = {
          override = {
            "vim.lsp.util.convert_input_to_markdown_lines" = true;
            "vim.lsp.util.stylize_markdown" = true;
            "cmp.entry.get_documentation" = true;
          };
          hover = {
            enabled = true;
          };
          signature = {
            enabled = true;
          };
        };
        presets = {
          bottom_search = true;
          command_palette = true;
          long_message_to_split = true;
          inc_rename = true;
          lsp_doc_border = true;
        };
        routes = [
          {
            filter = {
              event = "msg_show";
              kind = "";
              find = "written";
            };
            opts = {
              skip = true;
            };
          }
        ];
      };
    };

    notify.nvim-notify = {
      enable = true;
      setupOpts = {
        stages = "fade_in_slide_out";
        timeout = 3000;
        max_height = lib.mkLuaInline "function() return math.floor(vim.o.lines * 0.75) end";
        max_width = lib.mkLuaInline "function() return math.floor(vim.o.columns * 0.75) end";
        on_open = lib.mkLuaInline "function(win) vim.api.nvim_win_set_config(win, { zindex = 100 }) end";
        render = "wrapped-compact";
        top_down = true;
      };
    };

    extraPlugins = with pkgs.vimPlugins; {
      dressing-nvim = {
        package = dressing-nvim;
        setup = "require('dressing').setup({})";
      };
    };

    keymaps = [
      {
        key = "<S-Enter>";
        mode = "c";
        action = "function() require('noice').redirect(vim.fn.getcmdline()) end";
        lua = true;
        desc = "Redirect cmdline";
      }
      {
        key = "<leader>snl";
        mode = "n";
        action = "function() require('noice').cmd('last') end";
        lua = true;
        desc = "Noice last message";
      }
      {
        key = "<leader>snh";
        mode = "n";
        action = "function() require('noice').cmd('history') end";
        lua = true;
        desc = "Noice history";
      }
      {
        key = "<leader>sna";
        mode = "n";
        action = "function() require('noice').cmd('all') end";
        lua = true;
        desc = "Noice all";
      }
      {
        key = "<leader>snd";
        mode = "n";
        action = "function() require('noice').cmd('dismiss') end";
        lua = true;
        desc = "Dismiss all";
      }
    ];
  };
}
