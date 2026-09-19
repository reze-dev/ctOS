{ ... }: {
  config.vim = {
    statusline.lualine.enable = true;

    luaConfigRC.statusline_eviline = ''
      local lualine = require("lualine")

      local function hl(group, attr, fallback)
        local ok, value = pcall(vim.api.nvim_get_hl, 0, { name = group, link = true })
        if not ok or not value[attr] then
          return fallback
        end
        return string.format("#%06x", value[attr])
      end

      local function base46_palette()
        local ok, base46 = pcall(require, "base46")
        if not ok then
          return nil, nil
        end

        local theme_name = base46.current_theme
        if not theme_name and vim.g.colors_name then
          theme_name = vim.g.colors_name:match("^base46%-(.+)$")
        end

        local theme = theme_name and base46.theme_tables[theme_name]
        if not theme and theme_name and base46.get_builtin_theme then
          theme = base46.get_builtin_theme(theme_name)
        end

        if not theme then
          return nil, nil
        end
        return theme.base_30 or {}, theme.base_16 or {}
      end

      local function colors()
        local base30, base16 = base46_palette()
        if base30 then
          return {
            bg = base30.statusline_bg or base30.black or base16.base00 or "#202328",
            fg = base30.white or base16.base05 or "#bbc2cf",
            muted = base30.grey_fg or base16.base03 or "#5c6370",
            yellow = base30.yellow or base30.sun or base16.base0A or "#ECBE7B",
            cyan = base30.cyan or base30.teal or base16.base0C or "#008080",
            green = base30.green or base30.vibrant_green or base16.base0B or "#98be65",
            orange = base30.orange or base16.base09 or "#FF8800",
            violet = base30.purple or base30.dark_purple or base16.base0E or "#a9a1e1",
            magenta = base30.pink or base30.baby_pink or base30.purple or base16.base0E or "#c678dd",
            blue = base30.blue or base30.nord_blue or base16.base0D or "#51afef",
            red = base30.red or base16.base08 or "#ec5f67",
          }
        end

        return {
          bg = hl("StatusLine", "bg", hl("Normal", "bg", "#202328")),
          fg = hl("StatusLine", "fg", hl("Normal", "fg", "#bbc2cf")),
          muted = hl("Comment", "fg", "#5c6370"),
          yellow = hl("DiagnosticWarn", "fg", "#ECBE7B"),
          cyan = hl("DiagnosticInfo", "fg", "#008080"),
          green = hl("String", "fg", "#98be65"),
          orange = hl("Number", "fg", "#FF8800"),
          violet = hl("DiagnosticHint", "fg", "#a9a1e1"),
          magenta = hl("Keyword", "fg", "#c678dd"),
          blue = hl("Function", "fg", "#51afef"),
          red = hl("DiagnosticError", "fg", "#ec5f67"),
        }
      end

      local conditions = {
        buffer_not_empty = function()
          return vim.fn.empty(vim.fn.expand("%:t")) ~= 1
        end,
        hide_in_width = function()
          return vim.fn.winwidth(0) > 80
        end,
        check_git_workspace = function()
          local filepath = vim.fn.expand("%:p:h")
          local gitdir = vim.fn.finddir(".git", filepath .. ";")
          return gitdir and #gitdir > 0 and #gitdir < #filepath
        end,
      }

      local function mode_color()
        local c = colors()
        local mode_colors = {
          n = c.red,
          no = c.red,
          nov = c.red,
          noV = c.red,
          ["no\22"] = c.red,
          niI = c.red,
          niR = c.red,
          niV = c.red,
          nt = c.red,
          i = c.green,
          ic = c.yellow,
          ix = c.yellow,
          v = c.blue,
          V = c.blue,
          ["\22"] = c.blue,
          s = c.orange,
          S = c.orange,
          ["\19"] = c.orange,
          c = c.magenta,
          cv = c.red,
          ce = c.red,
          R = c.violet,
          Rc = c.violet,
          Rx = c.violet,
          Rv = c.violet,
          Rvc = c.violet,
          Rvx = c.violet,
          r = c.cyan,
          rm = c.cyan,
          ["r?"] = c.cyan,
          ["!"] = c.red,
          t = c.red,
        }
        return mode_colors[vim.fn.mode()] or c.red
      end

      local function lsp_name()
        local clients = vim.lsp.get_clients({ bufnr = 0 })
        if #clients == 0 then
          return "No Active Lsp"
        end

        local names = {}
        for _, client in ipairs(clients) do
          names[#names + 1] = client.name
        end
        return table.concat(names, ", ")
      end

      local function setup_eviline()
        local c = colors()
        local config = {
          options = {
            component_separators = "",
            section_separators = "",
            globalstatus = true,
            disabled_filetypes = {
              statusline = { "dashboard", "snacks_dashboard", "lazy" },
            },
            theme = {
              normal = { c = { fg = c.fg, bg = c.bg } },
              inactive = { c = { fg = c.fg, bg = c.bg } },
            },
            refresh = {
              statusline = 100,
            },
          },
          sections = {
            lualine_a = {},
            lualine_b = {},
            lualine_c = {},
            lualine_x = {},
            lualine_y = {},
            lualine_z = {},
          },
          inactive_sections = {
            lualine_a = {},
            lualine_b = {},
            lualine_c = {},
            lualine_x = {},
            lualine_y = {},
            lualine_z = {},
          },
        }

        local function ins_left(component)
          table.insert(config.sections.lualine_c, component)
        end

        local function ins_right(component)
          table.insert(config.sections.lualine_x, component)
        end

        ins_left({
          function()
            return "▊"
          end,
          color = function()
            return { fg = mode_color() }
          end,
          padding = { left = 0, right = 1 },
        })

        ins_left({
          function()
            return ""
          end,
          color = function()
            return { fg = mode_color(), gui = "bold" }
          end,
          padding = { right = 1 },
        })

        ins_left({
          "filesize",
          cond = conditions.buffer_not_empty,
          color = { fg = c.cyan, gui = "bold" },
        })

        ins_left({
          "filename",
          cond = conditions.buffer_not_empty,
          color = { fg = c.magenta, gui = "bold" },
          symbols = { modified = " ●", readonly = " 󰌾", unnamed = "[No Name]", newfile = "[New]" },
        })

        ins_left({ "location", color = { fg = c.blue, gui = "bold" } })
        ins_left({ "progress", color = { fg = c.violet, gui = "bold" } })

        ins_left({
          "diagnostics",
          sources = { "nvim_diagnostic" },
          symbols = { error = " ", warn = " ", info = " ", hint = "󰌵 " },
          diagnostics_color = {
            error = { fg = c.red },
            warn = { fg = c.yellow },
            info = { fg = c.cyan },
            hint = { fg = c.violet },
          },
        })

        ins_left({
          function()
            return "%="
          end,
        })

        ins_left({
          lsp_name,
          icon = " LSP:",
          cond = conditions.hide_in_width,
          color = { fg = c.green, gui = "bold" },
        })

        ins_right({
          "o:encoding",
          fmt = string.upper,
          cond = conditions.hide_in_width,
          color = { fg = c.yellow, gui = "bold" },
        })

        ins_right({
          "fileformat",
          fmt = string.upper,
          icons_enabled = false,
          cond = conditions.hide_in_width,
          color = { fg = c.cyan, gui = "bold" },
        })

        ins_right({
          "branch",
          icon = " ",
          cond = conditions.check_git_workspace,
          color = { fg = c.violet, gui = "bold" },
        })

        ins_right({
          "diff",
          symbols = { added = " ", modified = "󰝤 ", removed = " " },
          diff_color = {
            added = { fg = c.green },
            modified = { fg = c.orange },
            removed = { fg = c.red },
          },
          cond = conditions.hide_in_width,
        })

        ins_right({
          function()
            return "▊"
          end,
          color = function()
            return { fg = mode_color() }
          end,
          padding = { left = 1 },
        })

        lualine.setup(config)
      end

      setup_eviline()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("EvilineThemeRefresh", { clear = true }),
        callback = setup_eviline,
      })
    '';
  };
}
