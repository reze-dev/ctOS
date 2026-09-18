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
      rose-pine = {
        package = rose-pine;
      };
    };

    luaConfigRC.theme_setup = ''
      local ok_rp, rose_pine = pcall(require, "rose-pine")
      if ok_rp then
        rose_pine.setup({
          variant = "main",
          dark_variant = "main",
          dim_inactive_windows = false,
          extend_background_behind_borders = true,
          styles = {
            bold = true,
            italic = true,
            transparency = true,
          },
          highlight_groups = {
            TelescopeBorder = { fg = "highlight_high", bg = "none" },
            TelescopeNormal = { bg = "none" },
            TelescopePromptNormal = { bg = "base" },
            TelescopeResultsNormal = { fg = "subtle", bg = "none" },
            TelescopeSelection = { fg = "text", bg = "base" },
            TelescopeSelectionCaret = { fg = "rose", bg = "rose" },
            FloatBorder = { fg = "highlight_high", bg = "surface" },
            NormalFloat = { bg = "surface" },
            CursorLine = { bg = "highlight_low" },
            CursorLineNr = { fg = "gold" },
            StatusLine = { fg = "love", bg = "love", blend = 10 },
            StatusLineNC = { fg = "subtle", bg = "surface" },
            WhichKeyFloat = { bg = "surface" },
          },
        })
      end

      local ok_base46, base46 = pcall(require, "base46")
      if ok_base46 then
        base46.setup({
          transparency = true,
          set_background = true,
          term_colors = true,
          integrations = {
            defaults = true,
            syntax = true,
            treesitter = true,
            lsp = true,
            telescope = true,
            whichkey = true,
            gitsigns = true,
            bufferline = true,
            devicons = true,
            blink = true,
            statusline = false,
            neotest = true,
          },
        })
      end

      package.preload["core.theme"] = function()
        local base46_state_file = vim.fn.stdpath("state") .. "/base46-theme"
        return {
          base46_state_file = base46_state_file,
          read_base46_theme = function()
            if vim.fn.filereadable(base46_state_file) ~= 1 then return nil end
            local lines = vim.fn.readfile(base46_state_file)
            local theme = lines[1]
            return theme and theme ~= "" and theme or nil
          end,
          write_base46_theme = function(theme)
            vim.fn.mkdir(vim.fn.fnamemodify(base46_state_file, ":h"), "p")
            vim.fn.writefile({ theme }, base46_state_file)
          end,
        }
      end

      local theme_state = require("core.theme")
      local saved_theme = theme_state.read_base46_theme()

      if saved_theme then
        if saved_theme == "monoglow" or saved_theme == "rose-pine" then
          vim.cmd.colorscheme(saved_theme)
        else
          if ok_base46 then
            base46.load(saved_theme)
            vim.api.nvim_exec_autocmds("ColorScheme", {})
          else
            vim.cmd.colorscheme("monoglow")
          end
        end
      else
        vim.cmd.colorscheme("monoglow")
      end

      local function pick_theme()
        local themes = { "monoglow", "rose-pine" }
        for _, path in ipairs(vim.api.nvim_get_runtime_file("lua/base46/themes/*.lua", true)) do
          local name = vim.fn.fnamemodify(path, ":t:r")
          themes[#themes + 1] = name
        end
        table.sort(themes)

        vim.ui.select(themes, { prompt = "Select theme: " }, function(choice)
          if choice then
            require("core.theme").write_base46_theme(choice)
            if choice == "monoglow" or choice == "rose-pine" then
              vim.cmd.colorscheme(choice)
            else
              local ok, b46 = pcall(require, "base46")
              if ok then
                b46.load(choice)
                vim.api.nvim_exec_autocmds("ColorScheme", {})
              end
            end
            vim.notify("Theme: " .. choice, vim.log.levels.INFO)
          end
        end)
      end

      vim.keymap.set("n", "<leader>ut", pick_theme, { desc = "Themes: choose theme" })
      vim.api.nvim_create_user_command("NvChadTheme", pick_theme, { desc = "Choose colorscheme" })
      package.preload["base46-themes"] = function()
        return {
          pick = pick_theme,
        }
      end
    '';
  };
}
