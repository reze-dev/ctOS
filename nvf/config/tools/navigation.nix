{ pkgs, lib, ... }: {
  config.vim = {
    utility.oil-nvim = {
      enable = true;
      setupOpts = {
        default_file_explorer = true;
        columns = [
          "icon"
          "size"
        ];
        buf_options = {
          buflisted = false;
          bufhidden = "hide";
        };
        win_options = {
          wrap = false;
          signcolumn = "no";
          cursorcolumn = false;
          foldcolumn = "0";
          spell = false;
          list = false;
          conceallevel = 3;
          concealcursor = "nvic";
        };
        delete_to_trash = true;
        skip_confirm_for_simple_edits = true;
        prompt_save_on_select_new_entry = true;
        cleanup_delay_ms = 2000;
        lsp_file_methods = {
          timeout_ms = 1000;
          autosave_changes = false;
        };
        constrain_cursor = "editable";
        watch_for_changes = true;
        keymaps = {
          "g?" = "actions.show_help";
          "<CR>" = "actions.select";
          "<C-v>" = {
            "@1" = "actions.select";
            opts = {
              vertical = true;
            };
            desc = "Open in vsplit";
          };
          "<C-s>" = {
            "@1" = "actions.select";
            opts = {
              horizontal = true;
            };
            desc = "Open in hsplit";
          };
          "<C-t>" = {
            "@1" = "actions.select";
            opts = {
              tab = true;
            };
            desc = "Open in new tab";
          };
          "<C-p>" = "actions.preview";
          "<C-c>" = "actions.close";
          "<C-r>" = "actions.refresh";
          "-" = "actions.parent";
          "_" = "actions.open_cwd";
          "`" = "actions.cd";
          "~" = {
            "@1" = "actions.cd";
            opts = {
              scope = "tab";
            };
            desc = ":tcd to the directory";
          };
          "gs" = "actions.change_sort";
          "gx" = "actions.open_external";
          "g." = "actions.toggle_hidden";
          "g\\" = "actions.toggle_trash";
        };
        use_default_keymaps = false;
        view_options = {
          show_hidden = true;
          is_hidden_file = lib.mkLuaInline ''
            function(name, _)
              return vim.startswith(name, ".")
            end
          '';
          is_always_hidden = lib.mkLuaInline ''
            function(name, _)
              return name == ".." or name == ".git"
            end
          '';
          natural_order = true;
          case_insensitive = false;
          sort = [
            {
              "@1" = "type";
              "@2" = "asc";
            }
            {
              "@1" = "name";
              "@2" = "asc";
            }
          ];
        };
        float = {
          padding = 2;
          max_width = 90;
          max_height = 0;
          border = "rounded";
          win_options = {
            winblend = 0;
          };
        };
      };
    };

    navigation.harpoon = {
      enable = true;
      setupOpts = {
        settings = {
          save_on_toggle = true;
          sync_on_ui_close = true;
          key = lib.mkLuaInline ''
            function()
              return vim.uv.cwd()
            end
          '';
        };
      };
    };

    utility.motion = {
      flash-nvim.enable = true;
      precognition = {
        enable = true;
        setupOpts = {
          start_visible = false;
          show_blank = true;
        };
      };
    };

    binds.hardtime-nvim = {
      enable = true;
      setupOpts = {
        max_count = 3;
        disabled_filetypes = [
          "qf"
          "netrw"
          "NvimTree"
          "lazy"
          "mason"
          "oil"
          "snacks_dashboard"
          "dashboard"
          "trouble"
          "harpoon"
          "help"
          "undotree"
          "dapui_scopes"
          "dapui_breakpoints"
          "dapui_stacks"
          "dapui_watches"
          "dap-repl"
          "dapui_console"
        ];
        disabled_buftypes = [
          "nofile"
          "prompt"
          "quickfix"
          "terminal"
        ];
      };
    };

    extraPlugins = with pkgs.vimPlugins; {
      vim-tmux-navigator = {
        package = vim-tmux-navigator;
      };
    };

    globals = {
      tmux_navigator_no_mappings = 1;
      tmux_navigator_save_on_switch = 2;
      tmux_navigator_disable_when_zoomed = 1;
      tmux_navigator_preserve_zoom = 1;
    };

    keymaps = [
      # Oil
      {
        key = "<leader>e";
        mode = "n";
        action = "<cmd>Oil<cr>";
        desc = "Open file explorer (Oil)";
      }
      {
        key = "-";
        mode = "n";
        action = "<cmd>Oil<cr>";
        desc = "Open parent directory";
      }

      # Harpoon
      {
        key = "<leader>a";
        mode = "n";
        action = "function() require('harpoon'):list():add() end";
        lua = true;
        desc = "Harpoon: add file";
      }
      {
        key = "<C-e>";
        mode = "n";
        action = "function() local h = require('harpoon'); h.ui:toggle_quick_menu(h:list()) end";
        lua = true;
        desc = "Harpoon: toggle menu";
      }
      {
        key = "<leader>1";
        mode = "n";
        action = "function() require('harpoon'):list():select(1) end";
        lua = true;
        desc = "Harpoon: file 1";
      }
      {
        key = "<leader>2";
        mode = "n";
        action = "function() require('harpoon'):list():select(2) end";
        lua = true;
        desc = "Harpoon: file 2";
      }
      {
        key = "<leader>3";
        mode = "n";
        action = "function() require('harpoon'):list():select(3) end";
        lua = true;
        desc = "Harpoon: file 3";
      }
      {
        key = "<leader>4";
        mode = "n";
        action = "function() require('harpoon'):list():select(4) end";
        lua = true;
        desc = "Harpoon: file 4";
      }
      {
        key = "<leader>5";
        mode = "n";
        action = "function() require('harpoon'):list():select(5) end";
        lua = true;
        desc = "Harpoon: file 5";
      }
      {
        key = "[h";
        mode = "n";
        action = "function() require('harpoon'):list():prev() end";
        lua = true;
        desc = "Harpoon: previous file";
      }
      {
        key = "]h";
        mode = "n";
        action = "function() require('harpoon'):list():next() end";
        lua = true;
        desc = "Harpoon: next file";
      }

      # Flash
      {
        key = "s";
        mode = [
          "n"
          "x"
          "o"
        ];
        action = "function() require('flash').jump() end";
        lua = true;
        desc = "Flash jump";
      }
      {
        key = "S";
        mode = [
          "n"
          "x"
          "o"
        ];
        action = "function() require('flash').treesitter() end";
        lua = true;
        desc = "Flash treesitter";
      }
      {
        key = "r";
        mode = "o";
        action = "function() require('flash').remote() end";
        lua = true;
        desc = "Remote Flash";
      }
      {
        key = "R";
        mode = [
          "o"
          "x"
        ];
        action = "function() require('flash').treesitter_search() end";
        lua = true;
        desc = "Treesitter search";
      }
      {
        key = "<c-s>";
        mode = "c";
        action = "function() require('flash').toggle() end";
        lua = true;
        desc = "Toggle Flash search";
      }

      # Hardtime & Precognition toggles
      {
        key = "<leader>uh";
        mode = "n";
        action = "function() require('hardtime').toggle() end";
        lua = true;
        desc = "Toggle Hardtime (motion trainer)";
      }
      {
        key = "<leader>up";
        mode = "n";
        action = "function() require('precognition').toggle() end";
        lua = true;
        desc = "Toggle Precognition (motion guide)";
      }

      # Tmux Navigator
      {
        key = "<C-h>";
        mode = "n";
        action = "<cmd>TmuxNavigateLeft<cr>";
        desc = "Navigate left (tmux-aware)";
      }
      {
        key = "<C-j>";
        mode = "n";
        action = "<cmd>TmuxNavigateDown<cr>";
        desc = "Navigate down (tmux-aware)";
      }
      {
        key = "<C-k>";
        mode = "n";
        action = "<cmd>TmuxNavigateUp<cr>";
        desc = "Navigate up (tmux-aware)";
      }
      {
        key = "<C-l>";
        mode = "n";
        action = "<cmd>TmuxNavigateRight<cr>";
        desc = "Navigate right (tmux-aware)";
      }
    ];
  };
}
