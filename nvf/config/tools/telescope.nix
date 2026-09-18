{ pkgs, lib, ... }: {
  config.vim = {
    telescope.enable = true;

    extraPlugins = with pkgs.vimPlugins; {
      telescope-fzf-native-nvim = {
        package = telescope-fzf-native-nvim;
      };
      telescope-ui-select-nvim = {
        package = telescope-ui-select-nvim;
      };
    };

    luaConfigRC.telescope_config = ''
      local ok_telescope, telescope = pcall(require, "telescope")
      if ok_telescope then
        local ok_actions, actions = pcall(require, "telescope.actions")
        local mappings_i = {}
        local mappings_n = {}
        if ok_actions then
          mappings_i = {
            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,
            ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
            ["<C-x>"] = actions.delete_buffer,
            ["<Esc>"] = actions.close,
          }
          mappings_n = {
            ["q"] = actions.close,
            ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
          }
        end

        local ok_themes, themes = pcall(require, "telescope.themes")
        local ui_select_ext = ok_themes and { themes.get_dropdown() } or {}

        telescope.setup({
          defaults = {
            prompt_prefix = "   ",
            selection_caret = "  ",
            entry_prefix = "  ",
            initial_mode = "insert",
            selection_strategy = "reset",
            sorting_strategy = "ascending",
            layout_strategy = "horizontal",
            layout_config = {
              horizontal = {
                prompt_position = "top",
                preview_width = 0.55,
                results_width = 0.8,
              },
              vertical = {
                mirror = false,
              },
              width = 0.87,
              height = 0.80,
              preview_cutoff = 120,
            },
            path_display = { "truncate" },
            preview = {
              treesitter = false,
            },
            winblend = 0,
            border = {},
            borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
            color_devicons = true,
            set_env = { ["COLORTERM"] = "truecolor" },
            file_ignore_patterns = {
              "node_modules",
              ".git/",
              "target/",
              "vendor/",
              "__pycache__",
              "%.lock",
            },
            vimgrep_arguments = {
              "rg",
              "-L",
              "--color=never",
              "--no-heading",
              "--with-filename",
              "--line-number",
              "--column",
              "--smart-case",
            },
            mappings = {
              i = mappings_i,
              n = mappings_n,
            },
          },
          pickers = {
            find_files = {
              hidden = true,
              find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
            },
            buffers = {
              sort_mru = true,
              sort_lastused = true,
            },
            live_grep = {
              additional_args = { "--hidden" },
            },
          },
          extensions = {
            fzf = {
              fuzzy = true,
              override_generic_sorter = true,
              override_file_sorter = true,
              case_mode = "smart_case",
            },
            ["ui-select"] = ui_select_ext,
          },
        })

        pcall(telescope.load_extension, "fzf")
        pcall(telescope.load_extension, "ui-select")
      end
    '';

    keymaps = [
      {
        key = "<leader>ff";
        mode = "n";
        action = "<cmd>Telescope find_files<cr>";
        desc = "Find files";
      }
      {
        key = "<leader>fg";
        mode = "n";
        action = "<cmd>Telescope live_grep<cr>";
        desc = "Live grep";
      }
      {
        key = "<leader>fb";
        mode = "n";
        action = "<cmd>Telescope buffers<cr>";
        desc = "Find buffers";
      }
      {
        key = "<leader>fh";
        mode = "n";
        action = "<cmd>Telescope help_tags<cr>";
        desc = "Help tags";
      }
      {
        key = "<leader>fr";
        mode = "n";
        action = "<cmd>Telescope oldfiles<cr>";
        desc = "Recent files";
      }
      {
        key = "<leader>fd";
        mode = "n";
        action = "<cmd>Telescope diagnostics<cr>";
        desc = "Diagnostics";
      }
      {
        key = "<leader>fw";
        mode = "n";
        action = "<cmd>Telescope grep_string<cr>";
        desc = "Find word under cursor";
      }
      {
        key = "<leader>fk";
        mode = "n";
        action = "<cmd>Telescope keymaps<cr>";
        desc = "Keymaps";
      }
      {
        key = "<leader>fc";
        mode = "n";
        action = "<cmd>Telescope commands<cr>";
        desc = "Commands";
      }
      {
        key = "<leader>fm";
        mode = "n";
        action = "<cmd>Telescope marks<cr>";
        desc = "Marks";
      }
      {
        key = "<leader>fs";
        mode = "n";
        action = "<cmd>Telescope lsp_document_symbols<cr>";
        desc = "Document symbols";
      }
      {
        key = "<leader>fS";
        mode = "n";
        action = "<cmd>Telescope lsp_workspace_symbols<cr>";
        desc = "Workspace symbols";
      }
      {
        key = "<leader>gc";
        mode = "n";
        action = "<cmd>Telescope git_commits<cr>";
        desc = "Git commits";
      }
      {
        key = "<leader>gC";
        mode = "n";
        action = "<cmd>Telescope git_bcommits<cr>";
        desc = "Git buffer commits";
      }
      {
        key = "<leader>gt";
        mode = "n";
        action = "<cmd>Telescope git_status<cr>";
        desc = "Git status";
      }
      {
        key = "<leader><leader>";
        mode = "n";
        action = "<cmd>Telescope resume<cr>";
        desc = "Resume last search";
      }
    ];
  };
}
