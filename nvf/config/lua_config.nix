{ pkgs, ... }: {
  config.vim = {
    luaConfigRC.core_options = ''
      -- ─── System Environment & PATH ───────────────────────────────
      local home = vim.env.HOME or vim.fn.expand("~")
      local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
      local go_bin = home .. "/go/bin"
      local cargo_bin = home .. "/.cargo/bin"

      vim.env.PATH = mason_bin .. ":" .. go_bin .. ":" .. cargo_bin .. ":" .. (vim.env.PATH or "")

      local opt = vim.opt
      opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
      opt.fillchars = { eob = " ", fold = " ", foldopen = "v", foldsep = " ", foldclose = ">" }
      opt.shortmess:append("sI")
      opt.inccommand = "split"
      opt.jumpoptions = "view"
      opt.virtualedit = "block"
      opt.smoothscroll = true
      opt.completeopt = { "menu", "menuone", "noselect" }

      local undo_dir = vim.fn.stdpath("data") .. "/undo"
      opt.undodir = undo_dir
      pcall(vim.fn.mkdir, undo_dir, "p")

      vim.g.loaded_python3_provider = 0
      vim.g.loaded_ruby_provider = 0
      vim.g.loaded_perl_provider = 0
      vim.g.loaded_node_provider = 0
    '';
    luaConfigRC.core_keymaps = ''
      -- ─── Global Keymaps ───────────────────────────────────────────
      -- Plugin-specific keymaps live in their respective plugin files.
      local map = vim.keymap.set

      -- Better escape
      map("i", "jk", "<ESC>", { desc = "Exit insert mode" })

      -- Save & quit
      map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })
      map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
      map("n", "<leader>Q", "<cmd>qa!<cr>", { desc = "Force quit all" })

      -- Clear search highlights
      map("n", "<leader>nh", "<cmd>nohlsearch<cr>", { desc = "Clear search highlights" })

      -- Better window navigation (overridden by tmux-navigator when in tmux)
      map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
      map("n", "<C-j>", "<C-w>j", { desc = "Move to lower window" })
      map("n", "<C-k>", "<C-w>k", { desc = "Move to upper window" })
      map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

      -- Resize windows with arrows
      map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
      map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
      map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
      map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

      -- Buffer navigation
      map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
      map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
      map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Close buffer" })
      map("n", "<leader>bD", "<cmd>bdelete!<cr>", { desc = "Force close buffer" })

      -- Move lines up/down in visual mode
      map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
      map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

      -- Stay in visual mode when indenting
      map("v", "<", "<gv", { desc = "Indent left" })
      map("v", ">", ">gv", { desc = "Indent right" })

      -- Keep cursor centered when scrolling
      map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down (centered)" })
      map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up (centered)" })

      -- Keep search terms centered
      map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
      map("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })

      -- Join lines without moving cursor
      map("n", "J", "mzJ`z", { desc = "Join lines" })

      -- Paste without losing register content
      map("x", "<leader>p", [["_dP]], { desc = "Paste without overwriting register" })

      -- Delete without yanking (visual mode only, keeping normal <leader>d free for DAP)
      map("x", "<leader>d", [["_d]], { desc = "Delete without yanking" })

      -- Better terminal navigation
      map("t", "<C-h>", "<cmd>wincmd h<cr>", { desc = "Move to left window (terminal)" })
      map("t", "<C-j>", "<cmd>wincmd j<cr>", { desc = "Move to lower window (terminal)" })
      map("t", "<C-k>", "<cmd>wincmd k<cr>", { desc = "Move to upper window (terminal)" })
      map("t", "<C-l>", "<cmd>wincmd l<cr>", { desc = "Move to right window (terminal)" })
      map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

      -- Quickfix navigation
      map("n", "]q", "<cmd>cnext<cr>zz", { desc = "Next quickfix item" })
      map("n", "[q", "<cmd>cprev<cr>zz", { desc = "Previous quickfix item" })

      -- Select all
      map("n", "<C-a>", "gg<S-v>G", { desc = "Select all" })

      -- Package manager / configuration info
      map("n", "<leader>L", function()
        vim.notify("Configured declaratively via Nix / nvf flake", vim.log.levels.INFO, { title = "Package Manager" })
      end, { desc = "Open Lazy plugin manager / Nix info" })
    '';
    luaConfigRC.core_autocmds = ''
      -- ─── Autocommands ─────────────────────────────────────────────
      local augroup = vim.api.nvim_create_augroup
      local autocmd = vim.api.nvim_create_autocmd

      -- Highlight on yank
      autocmd("TextYankPost", {
        group = augroup("YankHighlight", { clear = true }),
        callback = function()
          vim.hl.on_yank({ higroup = "IncSearch", timeout = 200 })
        end,
      })

      -- Resize splits when window is resized
      autocmd("VimResized", {
        group = augroup("ResizeSplits", { clear = true }),
        callback = function()
          local current_tab = vim.fn.tabpagenr()
          vim.cmd("tabdo wincmd =")
          vim.cmd("tabnext " .. current_tab)
        end,
      })

      -- Go to last cursor position when opening a file
      autocmd("BufReadPost", {
        group = augroup("LastPosition", { clear = true }),
        callback = function(event)
          local exclude = { "gitcommit" }
          local buf = event.buf
          if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].lazyvim_last_loc then
            return
          end
          vim.b[buf].lazyvim_last_loc = true
          local mark = vim.api.nvim_buf_get_mark(buf, '"')
          local lcount = vim.api.nvim_buf_line_count(buf)
          if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
          end
        end,
      })

      -- Close certain filetypes with q
      autocmd("FileType", {
        group = augroup("CloseWithQ", { clear = true }),
        pattern = {
          "PlenaryTestPopup",
          "checkhealth",
          "dbout",
          "gitsigns.blame",
          "help",
          "lspinfo",
          "neotest-output",
          "neotest-output-panel",
          "neotest-summary",
          "notify",
          "qf",
          "spectre_panel",
          "startuptime",
          "tsplayground",
        },
        callback = function(event)
          vim.bo[event.buf].buflisted = false
          vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
        end,
      })

      -- Auto create directories when saving a file
      autocmd("BufWritePre", {
        group = augroup("AutoCreateDir", { clear = true }),
        callback = function(event)
          if event.match:match("^%w%w+:[\\/][\\/]") then
            return
          end
          local file = vim.uv.fs_realpath(event.match) or event.match
          vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
        end,
      })

      -- Remove trailing whitespace on save
      autocmd("BufWritePre", {
        group = augroup("TrimWhitespace", { clear = true }),
        pattern = "*",
        callback = function()
          local save_cursor = vim.fn.getpos(".")
          pcall(function()
            vim.cmd([[%s/\s\+$//e]])
          end)
          vim.fn.setpos(".", save_cursor)
        end,
      })

      -- Check if file changed when its window is focused
      autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
        group = augroup("Checktime", { clear = true }),
        callback = function()
          if vim.o.buftype ~= "nofile" then
            vim.cmd("checktime")
          end
        end,
      })

      -- Wrap and spell check in text filetypes
      autocmd("FileType", {
        group = augroup("WrapSpell", { clear = true }),
        pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
        callback = function()
          vim.opt_local.wrap = true
          vim.opt_local.spell = true
        end,
      })

      -- Fix conceallevel for json files
      autocmd("FileType", {
        group = augroup("JsonConceal", { clear = true }),
        pattern = { "json", "jsonc", "json5" },
        callback = function()
          vim.opt_local.conceallevel = 0
        end,
      })

    '';
    luaConfigRC.plugin_lualine_snacks = ''
      -- Snacks
      require("snacks").setup({
        -- ── Dashboard ──
        dashboard = {
          enabled = true,
          preset = {
            keys = {
              { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
              { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
              { icon = "󰱼 ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
              { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
              { icon = " ", key = "p", desc = "Projects", action = ":lua Snacks.picker.projects()" },
              { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },

              { icon = " ", key = "q", desc = "Quit", action = ":qa" },
            },
            header = [[
                                                                                  
                                                                                  
                                                                               
                 ████ ██████           █████      ██                     
                ███████████             █████                             
                █████████ ███████████████████ ███   ███████████   
               █████████  ███    █████████████ █████ ██████████████   
              █████████ ██████████ █████████ █████ █████ ████ █████   
            ███████████ ███    ███ █████████ █████ █████ ████ █████  
           ██████  █████████████████████ ████ █████ █████ ████ ██████ 
                                                                                 
                                                                                         
                                                                                  
                                                                                
                                                                                  
           ]],
          },
          sections = {
            { pane = 1, section = "header", padding = 2 },

            { pane = 2, section = "keys", gap = 1, padding = 1 },
          },
        },

        -- ── Notifier ──
        notifier = {
          enabled = true,
          timeout = 3000,
          style = "compact",
        },

        -- ── Quick file ── (fast file opening)
        quickfile = { enabled = true },

        -- ── Status column ──
        statuscolumn = { enabled = true },

        -- ── Words ── (highlight/navigate references)
        words = { enabled = true },

        -- ── Styles ──
        styles = {
          notification = {
            wo = { wrap = true },
          },
        },
      })

      vim.keymap.set("n", "<leader>un", function() Snacks.notifier.hide() end, { desc = "Dismiss all notifications" })
      vim.keymap.set("n", "<leader>gg", function() Snacks.lazygit() end, { desc = "Lazygit" })
      vim.keymap.set("n", "<leader>gl", function() Snacks.lazygit.log() end, { desc = "Lazygit log (cwd)" })
      vim.keymap.set({ "n", "t" }, "]]", function() Snacks.words.jump(vim.v.count1) end, { desc = "Next reference" })
      vim.keymap.set({ "n", "t" }, "[[", function() Snacks.words.jump(-vim.v.count1) end, { desc = "Previous reference" })

      -- Lualine
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

      local function setup()
        local c = colors()
        local config = {
          options = {
            component_separators = "",
            section_separators = "",
            globalstatus = true,
            disabled_filetypes = {
              statusline = { "dashboard", "snacks_dashboard", "lazy", "mason" },
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

      setup()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("EvilineThemeRefresh", { clear = true }),
        callback = setup,
      })

    '';
    luaConfigRC.plugin_ui = ''
      -- ============================================================================
      -- Migrated Standalone UI Configurations
      -- Extracted from lua/plugins/ui.lua
      -- ============================================================================

      -- 1. Web Devicons (dependency for UI icons)
      pcall(function()
        require("nvim-web-devicons").setup({})
      end)

      -- 2. Indent Blankline (lukas-reineke/indent-blankline.nvim)
      pcall(function()
        require("ibl").setup({
          indent = {
            char = "│",
            tab_char = "│",
          },
          scope = {
            show_start = false,
            show_end = false,
            include = {
              node_type = {
                ["*"] = {
                  "argument_list",
                  "arguments",
                  "assignment_statement",
                  "block",
                  "chunk",
                  "class",
                  "do_block",
                  "element",
                  "except",
                  "for",
                  "function",
                  "if_statement",
                  "method",
                  "object",
                  "return_statement",
                  "table",
                  "try",
                  "while",
                },
              },
            },
          },
          exclude = {
            filetypes = {
              "help",
              "dashboard",
              "snacks_dashboard",
              "lazy",
              "mason",
              "notify",
              "oil",
              "toggleterm",
            },
          },
        })
      end)

      -- 3. Notify (rcarriga/nvim-notify)
      pcall(function()
        local notify = require("notify")
        notify.setup({
          stages = "fade_in_slide_out",
          timeout = 3000,
          max_height = function()
            return math.floor(vim.o.lines * 0.75)
          end,
          max_width = function()
            return math.floor(vim.o.columns * 0.75)
          end,
          on_open = function(win)
            vim.api.nvim_win_set_config(win, { zindex = 100 })
          end,
          render = "wrapped-compact",
          top_down = true,
        })
        vim.notify = notify
      end)

      -- 4. Noice (folke/noice.nvim)
      pcall(function()
        require("noice").setup({
          lsp = {
            override = {
              ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
              ["vim.lsp.util.stylize_markdown"] = true,
              ["cmp.entry.get_documentation"] = true,
            },
            hover = { enabled = true },
            signature = { enabled = true },
          },
          presets = {
            bottom_search = true,
            command_palette = true,
            long_message_to_split = true,
            inc_rename = true,
            lsp_doc_border = true,
          },
          routes = {
            -- Hide "written" messages
            {
              filter = {
                event = "msg_show",
                kind = "",
                find = "written",
              },
              opts = { skip = true },
            },
          },
        })

        -- Noice keymaps
        vim.keymap.set("c", "<S-Enter>", function()
          require("noice").redirect(vim.fn.getcmdline())
        end, { desc = "Redirect cmdline" })
        vim.keymap.set("n", "<leader>snl", function() require("noice").cmd("last") end, { desc = "Noice last message" })
        vim.keymap.set("n", "<leader>snh", function() require("noice").cmd("history") end, { desc = "Noice history" })
        vim.keymap.set("n", "<leader>sna", function() require("noice").cmd("all") end, { desc = "Noice all" })
        vim.keymap.set("n", "<leader>snd", function() require("noice").cmd("dismiss") end, { desc = "Dismiss all" })
      end)

      -- 5. Dressing (stevearc/dressing.nvim)
      pcall(function()
        require("dressing").setup({})
      end)

      -- 6. Illuminate (RRethy/vim-illuminate)
      pcall(function()
        require("illuminate").configure({
          delay = 200,
          large_file_cutoff = 2000,
          large_file_overrides = {
            providers = { "lsp" },
          },
          filetypes_denylist = {
            "oil",
            "dashboard",
            "snacks_dashboard",
            "lazy",
            "mason",
            "TelescopePrompt",
          },
        })
      end)

      -- 7. Colorizer (NvChad/nvim-colorizer.lua)
      pcall(function()
        require("colorizer").setup({
          filetypes = { "*" },
          user_default_options = {
            RGB = true,
            RRGGBB = true,
            names = false,
            RRGGBBAA = true,
            AARRGGBB = true,
            rgb_fn = true,
            hsl_fn = true,
            css = true,
            css_fn = true,
            mode = "background",
            tailwind = false,
            virtualtext = "■",
            always_update = false,
          },
        })
      end)

    '';
    luaConfigRC.plugin_remaining = ''
      local function safe_setup(plugin, setup_fn)
        local ok, m = pcall(require, plugin)
        if not ok then
          vim.notify("Failed to load " .. plugin, vim.log.levels.WARN)
          return
        end
        setup_fn(m)
      end

      -- ─── Conform — Autoformatter ──────────────────────────────────
      safe_setup("conform", function(conform)
        conform.setup({
          formatters_by_ft = {
            c = { "clang-format" },
            cpp = { "clang-format" },
            rust = { "rustfmt" },
            go = { "goimports", "gofumpt" },
            lua = { "stylua" },
            python = { "ruff_format", "ruff_organize_imports" },
            toml = { "taplo" },
            javascript = { "prettier" },
            typescript = { "prettier" },
            javascriptreact = { "prettier" },
            typescriptreact = { "prettier" },
            html = { "prettier" },
            css = { "prettier" },
            scss = { "prettier" },
            json = { "prettier" },
            jsonc = { "prettier" },
            yaml = { "prettier" },
            markdown = { "prettier" },
            graphql = { "prettier" },
            nix = { "nixfmt" },
            fish = { "fish_indent" },
            sh = { "shfmt" },
            bash = { "shfmt" },
            ["_"] = { "trim_whitespace" },
          },
          format_on_save = function(bufnr)
            if vim.b[bufnr].disable_autoformat or vim.g.disable_autoformat then
              return
            end
            return {
              timeout_ms = 500,
              lsp_format = "fallback",
            }
          end,
          formatters = {
            shfmt = {
              prepend_args = { "-i", "2" },
            },
            stylua = {
              prepend_args = { "--indent-type", "Spaces", "--indent-width", "2" },
            },
            ["clang-format"] = {
              prepend_args = { "-fallback-style=LLVM" },
            },
          },
        })

        vim.keymap.set({ "n", "v" }, "<leader>cf", function()
          conform.format({
            async = false,
            timeout_ms = 3000,
            lsp_format = "fallback",
          })
        end, { desc = "Format buffer/selection" })

        vim.api.nvim_create_user_command("FormatToggle", function()
          vim.g.disable_autoformat = not vim.g.disable_autoformat
          local state = vim.g.disable_autoformat and "disabled" or "enabled"
          vim.notify("Autoformat " .. state, vim.log.levels.INFO)
        end, { desc = "Toggle autoformat on save" })

        vim.api.nvim_create_user_command("FormatToggleBuf", function()
          vim.b.disable_autoformat = not vim.b.disable_autoformat
          local state = vim.b.disable_autoformat and "disabled" or "enabled"
          vim.notify("Autoformat (buffer) " .. state, vim.log.levels.INFO)
        end, { desc = "Toggle autoformat on save (buffer)" })
      end)

      -- ─── DAP — Debug Adapter Protocol ─────────────────────────────
      safe_setup("dap", function(dap)
        -- Signs
        vim.fn.sign_define("DapBreakpoint", { text = " ", texthl = "DiagnosticError", linehl = "", numhl = "" })
        vim.fn.sign_define("DapBreakpointCondition", { text = " ", texthl = "DiagnosticWarn", linehl = "", numhl = "" })
        vim.fn.sign_define("DapBreakpointRejected", { text = " ", texthl = "DiagnosticError", linehl = "", numhl = "" })
        vim.fn.sign_define("DapLogPoint", { text = " ", texthl = "DiagnosticInfo", linehl = "", numhl = "" })
        vim.fn.sign_define("DapStopped", { text = "▶ ", texthl = "DiagnosticOk", linehl = "DapStoppedLine", numhl = "" })
        vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })

        -- DAP UI
        local ok_dapui, dapui = pcall(require, "dapui")
        if ok_dapui then
          dapui.setup({
            icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
            layouts = {
              {
                elements = {
                  { id = "scopes", size = 0.35 },
                  { id = "breakpoints", size = 0.15 },
                  { id = "stacks", size = 0.25 },
                  { id = "watches", size = 0.25 },
                },
                size = 40,
                position = "left",
              },
              {
                elements = {
                  { id = "repl", size = 0.5 },
                  { id = "console", size = 0.5 },
                },
                size = 0.25,
                position = "bottom",
              },
            },
            floating = {
              border = "rounded",
              mappings = {
                close = { "q", "<Esc>" },
              },
            },
          })

          dap.listeners.after.event_initialized["dapui_config"] = function()
            pcall(function() dapui.open({}) end)
          end
          dap.listeners.before.event_terminated["dapui_config"] = function()
            pcall(function() dapui.close({}) end)
          end
          dap.listeners.before.event_exited["dapui_config"] = function()
            pcall(function() dapui.close({}) end)
          end

          vim.keymap.set("n", "<leader>du", function() dapui.toggle({}) end, { desc = "DAP: toggle UI" })
          vim.keymap.set({ "n", "v" }, "<leader>de", function() dapui.eval() end, { desc = "DAP: eval" })
        end

        -- DAP Virtual Text
        local ok_dap_vt, dap_vt = pcall(require, "nvim-dap-virtual-text")
        if ok_dap_vt then
          dap_vt.setup({
            enabled = true,
            enabled_commands = true,
            highlight_changed_variables = true,
            highlight_new_as_changed = false,
            show_stop_reason = true,
            commented = false,
            only_first_definition = true,
            all_references = false,
            clear_on_continue = false,
            display_callback = function(variable, buf, stackframe, node, options)
              if options.virt_text_pos == "inline" then
                return " = " .. variable.value
              else
                return variable.name .. " = " .. variable.value
              end
            end,
            virt_text_pos = "eol",
            all_frames = false,
            virt_lines = false,
            virt_text_win_col = nil,
          })
        end

        -- DAP Go
        local ok_dap_go, dap_go = pcall(require, "dap-go")
        if ok_dap_go then
          dap_go.setup({})
        end

        -- DAP Python
        local ok_dap_py, dap_py = pcall(require, "dap-python")
        if ok_dap_py then
          local debugpy_path = vim.fn.exepath("python3")
          dap_py.setup(debugpy_path)
        end

        -- Keymaps
        local map = vim.keymap.set
        map("n", "<leader>db", function() dap.toggle_breakpoint() end, { desc = "DAP: toggle breakpoint" })
        map("n", "<leader>dB", function() dap.set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, { desc = "DAP: conditional breakpoint" })
        map("n", "<leader>dc", function() dap.continue() end, { desc = "DAP: continue" })
        map("n", "<leader>dC", function() dap.run_to_cursor() end, { desc = "DAP: run to cursor" })
        map("n", "<leader>di", function() dap.step_into() end, { desc = "DAP: step into" })
        map("n", "<leader>do", function() dap.step_over() end, { desc = "DAP: step over" })
        map("n", "<leader>dO", function() dap.step_out() end, { desc = "DAP: step out" })
        map("n", "<leader>dp", function() dap.pause() end, { desc = "DAP: pause" })
        map("n", "<leader>dr", function() dap.restart() end, { desc = "DAP: restart" })
        map("n", "<leader>dl", function() dap.run_last() end, { desc = "DAP: run last" })
        map("n", "<leader>dt", function() dap.terminate() end, { desc = "DAP: terminate" })
        map("n", "<leader>dw", function() require("dap.ui.widgets").hover() end, { desc = "DAP: widgets" })

        -- CodeLLDB Discovery & Adapter
        local mason_path = vim.fn.stdpath("data") .. "/mason/packages/codelldb"
        local codelldb_mason = mason_path .. "/extension/adapter/codelldb"
        local codelldb_cmd = "codelldb"

        if vim.fn.filereadable(codelldb_mason) == 1 or vim.fn.executable(codelldb_mason) == 1 then
          codelldb_cmd = codelldb_mason
        elseif vim.fn.executable("codelldb") == 1 then
          codelldb_cmd = vim.fn.exepath("codelldb")
        end

        dap.adapters.codelldb = {
          type = "server",
          port = "''${port}",
          executable = {
            command = codelldb_cmd,
            args = { "--port", "''${port}" },
          },
        }
        dap.adapters.lldb = dap.adapters.codelldb

        local function get_binary()
          local cwd = vim.fn.getcwd()
          local candidates = {}
          local seen = {}

          local search_dirs = {
            "target/debug", "target/release", "build", "build/bin",
            "bin", "out", "cmake-build-debug", "cmake-build-release",
          }
          local ignored_exts = {
            o = true, a = true, so = true, dylib = true, dll = true,
            d = true, rlib = true, rmeta = true, pdb = true,
            txt = true, log = true, cmake = true, json = true,
            ninja = true, lock = true,
          }
          local ignored_script_exts = {
            sh = true, bash = true, zsh = true, lua = true, py = true,
            pl = true, rb = true, js = true, ts = true, md = true,
          }

          for _, dir in ipairs(search_dirs) do
            local full_dir = cwd .. "/" .. dir
            if vim.fn.isdirectory(full_dir) == 1 then
              local files = vim.fn.glob(full_dir .. "/*", false, true)
              for _, file in ipairs(files) do
                if vim.fn.isdirectory(file) == 0 and vim.fn.executable(file) == 1 then
                  local ext = vim.fn.fnamemodify(file, ":e"):lower()
                  if not ignored_exts[ext] and not ignored_script_exts[ext] and not seen[file] then
                    seen[file] = true
                    table.insert(candidates, file)
                  end
                end
              end
            end
          end

          local root_files = vim.fn.glob(cwd .. "/*", false, true)
          for _, file in ipairs(root_files) do
            if vim.fn.isdirectory(file) == 0 and vim.fn.executable(file) == 1 then
              local ext = vim.fn.fnamemodify(file, ":e"):lower()
              if not ignored_exts[ext] and not ignored_script_exts[ext] and not file:match("/%.") and not seen[file] then
                seen[file] = true
                table.insert(candidates, file)
              end
            end
          end

          local co = coroutine.running()
          if co and #candidates > 0 then
            local items = {}
            for _, c in ipairs(candidates) do
              table.insert(items, c)
            end
            table.insert(items, "Manually enter path...")

            vim.ui.select(items, {
              prompt = "Select executable: ",
              format_item = function(item)
                if item == "Manually enter path..." then
                  return item
                end
                return vim.fn.fnamemodify(item, ":.")
              end,
            }, function(choice)
              if not choice then
                coroutine.resume(co, dap.ABORT)
              elseif choice == "Manually enter path..." then
                local manual = vim.fn.input("Path to executable: ", cwd .. "/", "file")
                coroutine.resume(co, manual ~= "" and manual or dap.ABORT)
              else
                coroutine.resume(co, choice)
              end
            end)
            return coroutine.yield()
          elseif #candidates == 1 and not co then
            return candidates[1]
          else
            local input = vim.fn.input("Path to executable: ", cwd .. "/", "file")
            if input == "" then
              return dap.ABORT or nil
            end
            return input
          end
        end

        local codelldb_configurations = {
          {
            name = "Launch Binary (Smart Picker)",
            type = "codelldb",
            request = "launch",
            program = get_binary,
            cwd = "''${workspaceFolder}",
            stopOnEntry = false,
            args = {},
          },
          {
            name = "Launch Binary with Arguments",
            type = "codelldb",
            request = "launch",
            program = get_binary,
            cwd = "''${workspaceFolder}",
            stopOnEntry = false,
            args = function()
              local args_str = vim.fn.input("Arguments: ")
              if args_str == "" then
                return {}
              end
              return vim.split(args_str, "%s+", { trimempty = true })
            end,
          },
          {
            name = "Attach to Process",
            type = "codelldb",
            request = "attach",
            pid = function()
              return require("dap.utils").pick_process()
            end,
            cwd = "''${workspaceFolder}",
          },
          {
            name = "Load Core Dump",
            type = "codelldb",
            request = "attach",
            program = get_binary,
            coreDumpPath = function()
              local core_path = vim.fn.input("Path to core dump: ", vim.fn.getcwd() .. "/", "file")
              return core_path ~= "" and core_path or nil
            end,
            cwd = "''${workspaceFolder}",
          },
        }

        dap.configurations.cpp = codelldb_configurations
        dap.configurations.c = codelldb_configurations
        dap.configurations.rust = codelldb_configurations

        -- Delve (Go)
        local dlv_path = "dlv"
        local mason_dlv = vim.fn.stdpath("data") .. "/mason/packages/delve/dlv"
        if vim.fn.filereadable(mason_dlv) == 1 or vim.fn.executable(mason_dlv) == 1 then
          dlv_path = mason_dlv
        elseif vim.fn.executable("dlv") == 1 then
          dlv_path = vim.fn.exepath("dlv")
        end

        dap.adapters.delve = {
          type = "server",
          port = "''${port}",
          executable = {
            command = dlv_path,
            args = { "dap", "-l", "127.0.0.1:''${port}" },
          },
        }
        dap.adapters.go = dap.adapters.delve

        dap.configurations.go = {
          {
            type = "delve",
            name = "Debug (Smart Picker / Current File)",
            request = "launch",
            program = "''${file}",
          },
          {
            type = "delve",
            name = "Debug Package",
            request = "launch",
            program = "''${fileDirname}",
          },
          {
            type = "delve",
            name = "Debug with Arguments",
            request = "launch",
            program = "''${file}",
            args = function()
              local args_str = vim.fn.input("Arguments: ")
              if args_str == "" then
                return {}
              end
              return vim.split(args_str, "%s+", { trimempty = true })
            end,
          },
          {
            type = "delve",
            name = "Debug Test",
            request = "launch",
            mode = "test",
            program = "''${file}",
          },
          {
            type = "delve",
            name = "Debug Test (Package)",
            request = "launch",
            mode = "test",
            program = "./''${relativeFileDirname}",
          },
          {
            type = "delve",
            name = "Attach to Process",
            request = "attach",
            mode = "local",
            processId = function()
              return require("dap.utils").pick_process()
            end,
          },
        }
      end)

      -- ─── Colorscheme (rose-pine & monoglow) ───────────────────────
      safe_setup("rose-pine", function(rose_pine)
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
      end)

      -- ─── LSP Configuration & Keymaps ─────────────────────────────
      vim.diagnostic.config({
        underline = true,
        update_in_insert = false,
        virtual_text = {
          spacing = 4,
          source = "if_many",
          prefix = "●",
        },
        severity_sort = true,
        float = {
          focusable = true,
          style = "minimal",
          border = "rounded",
          source = true,
          header = "",
          prefix = "",
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.HINT] = "󰌵 ",
            [vim.diagnostic.severity.INFO] = " ",
          },
        },
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
        callback = function(ev)
          local bufnr = ev.buf
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          if not client then
            return
          end

          local map = function(keys, func, desc, mode)
            mode = mode or "n"
            vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
          end

          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gD", vim.lsp.buf.declaration, "Go to declaration")
          map("gr", vim.lsp.buf.references, "Go to references")
          map("gi", vim.lsp.buf.implementation, "Go to implementation")
          map("<leader>D", vim.lsp.buf.type_definition, "Type definition")
          map("<leader>li", vim.lsp.buf.incoming_calls, "Incoming calls")
          map("<leader>lo", vim.lsp.buf.outgoing_calls, "Outgoing calls")

          map("K", vim.lsp.buf.hover, "Hover documentation")
          map("<C-S-k>", vim.lsp.buf.signature_help, "Signature help")
          map("<C-S-k>", vim.lsp.buf.signature_help, "Signature help", "i")

          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action", "v")
          map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")

          map("<leader>ld", vim.diagnostic.open_float, "Line diagnostics")
          map("[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "Previous diagnostic")
          map("]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "Next diagnostic")
          map("[e", function() vim.diagnostic.jump({ count = -1, float = true, severity = vim.diagnostic.severity.ERROR }) end, "Previous error")
          map("]e", function() vim.diagnostic.jump({ count = 1, float = true, severity = vim.diagnostic.severity.ERROR }) end, "Next error")

          map("<leader>lwa", vim.lsp.buf.add_workspace_folder, "Add workspace folder")
          map("<leader>lwr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder")
          map("<leader>lwl", function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
          end, "List workspace folders")

          if client:supports_method("textDocument/inlayHint", bufnr) then
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
            map("<leader>lh", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
            end, "Toggle inlay hints")
          end

          if client:supports_method("textDocument/codeLens", bufnr) then
            map("<leader>ll", vim.lsp.codelens.run, "Run codelens")
            map("<leader>lL", vim.lsp.codelens.refresh, "Refresh codelens")
          end

          if client:supports_method("textDocument/documentHighlight", bufnr) then
            local group = vim.api.nvim_create_augroup("LspDocumentHighlight", { clear = false })
            vim.api.nvim_clear_autocmds({ group = group, buffer = bufnr })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              group = group,
              buffer = bufnr,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
              group = group,
              buffer = bufnr,
              callback = vim.lsp.buf.clear_references,
            })
          end
        end,
      })

      -- ─── Bufferline — Tab/Buffer Line ─────────────────────────────
      safe_setup("bufferline", function(bufferline)
        bufferline.setup({
          options = {
            mode = "buffers",
            themable = true,
            numbers = "none",
            close_command = "bdelete! %d",
            right_mouse_command = "bdelete! %d",
            left_mouse_command = "buffer %d",
            middle_mouse_command = nil,
            indicator = {
              icon = "▎",
              style = "icon",
            },
            buffer_close_icon = "󰅖",
            modified_icon = "●",
            close_icon = "",
            left_trunc_marker = "",
            right_trunc_marker = "",
            max_name_length = 30,
            max_prefix_length = 30,
            truncate_names = true,
            tab_size = 21,
            diagnostics = "nvim_lsp",
            diagnostics_update_in_insert = false,
            diagnostics_indicator = function(count, level)
              local icon = level:match("error") and " " or " "
              return " " .. icon .. count
            end,
            offsets = {
              {
                filetype = "oil",
                text = "  File Explorer",
                highlight = "Directory",
                text_align = "left",
                separator = true,
              },
            },
            color_icons = true,
            show_buffer_icons = true,
            show_buffer_close_icons = true,
            show_close_icon = false,
            show_tab_indicators = true,
            show_duplicate_prefix = true,
            persist_buffer_sort = true,
            separator_style = "thin",
            enforce_regular_tabs = false,
            always_show_bufferline = true,
            hover = {
              enabled = true,
              delay = 200,
              reveal = { "close" },
            },
          },
        })

        vim.keymap.set("n", "<leader>bp", "<cmd>BufferLineTogglePin<cr>", { desc = "Pin buffer" })
        vim.keymap.set("n", "<leader>bx", "<cmd>BufferLineCloseOthers<cr>", { desc = "Close other buffers" })
        vim.keymap.set("n", "<leader>br", "<cmd>BufferLineCloseRight<cr>", { desc = "Close buffers to the right" })
        vim.keymap.set("n", "<leader>bl", "<cmd>BufferLineCloseLeft<cr>", { desc = "Close buffers to the left" })
        vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous buffer" })
        vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
        vim.keymap.set("n", "[b", "<cmd>BufferLineCyclePrev<cr>", { desc = "Previous buffer" })
        vim.keymap.set("n", "]b", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
      end)


      -- ─── Extra Editing Plugins ────────────────────────────────────
      safe_setup("nvim-autopairs", function(autopairs)
        autopairs.setup({
          check_ts = true,
          ts_config = {
            lua = { "string", "source" },
            javascript = { "string", "template_string" },
            java = false,
          },
          disable_filetype = { "TelescopePrompt", "spectre_panel" },
          fast_wrap = {
            map = "<M-e>",
            chars = { "{", "[", "(", '"', "'" },
            pattern = [=[[%'%"%>%]%)%}%,]]=],
            end_key = "$",
            before_key = "h",
            after_key = "l",
            cursor_pos_before = true,
            keys = "qwertyuiopzxcvbnmasdfghjkl",
            manual_position = true,
            highlight = "Search",
            highlight_grey = "Comment",
          },
        })
      end)

      safe_setup("nvim-surround", function(surround)
        surround.setup({})
      end)

      safe_setup("trouble", function(trouble)
        trouble.setup({
          use_diagnostic_signs = true,
        })

        vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics (Trouble)" })
        vim.keymap.set("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer diagnostics (Trouble)" })
        vim.keymap.set("n", "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>", { desc = "Symbols (Trouble)" })
        vim.keymap.set("n", "<leader>xl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", { desc = "LSP references (Trouble)" })
        vim.keymap.set("n", "<leader>xL", "<cmd>Trouble loclist toggle<cr>", { desc = "Location list (Trouble)" })
        vim.keymap.set("n", "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix list (Trouble)" })
      end)

      safe_setup("mini.ai", function(ai)
        ai.setup({
          n_lines = 500,
          custom_textobjects = {
            o = ai.gen_spec.treesitter({
              a = { "@block.outer", "@conditional.outer", "@loop.outer" },
              i = { "@block.inner", "@conditional.inner", "@loop.inner" },
            }, {}),
            f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }, {}),
            c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }, {}),
          },
        })
      end)

      safe_setup("better_escape", function(be)
        be.setup({
          timeout = 200,
          default_mappings = false,
          mappings = {
            i = {
              j = { k = "<Esc>" },
            },
            c = {
              j = { k = "<Esc>" },
            },
          },
        })
      end)

      safe_setup("persistence", function(persistence)
        persistence.setup({
          options = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp" },
        })

        vim.keymap.set("n", "<leader>qs", function() persistence.load() end, { desc = "Restore session" })
        vim.keymap.set("n", "<leader>ql", function() persistence.load({ last = true }) end, { desc = "Restore last session" })
        vim.keymap.set("n", "<leader>qd", function() persistence.stop() end, { desc = "Don't save current session" })
      end)


      -- ─── Git Integration ──────────────────────────────────────────
      safe_setup("gitsigns", function(gitsigns)
        gitsigns.setup({
          signs = {
            add = { text = "▎" },
            change = { text = "▎" },
            delete = { text = "" },
            topdelete = { text = "" },
            changedelete = { text = "▎" },
            untracked = { text = "▎" },
          },
          signs_staged = {
            add = { text = "▎" },
            change = { text = "▎" },
            delete = { text = "" },
            topdelete = { text = "" },
            changedelete = { text = "▎" },
          },
          current_line_blame = false,
          current_line_blame_opts = {
            virt_text = true,
            virt_text_pos = "eol",
            delay = 500,
            ignore_whitespace = false,
          },
          current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",
          preview_config = {
            border = "rounded",
            style = "minimal",
            relative = "cursor",
            row = 0,
            col = 1,
          },
          on_attach = function(bufnr)
            local gs = package.loaded.gitsigns

            local function map(mode, l, r, opts)
              opts = opts or {}
              opts.buffer = bufnr
              vim.keymap.set(mode, l, r, opts)
            end

            -- Navigation
            map("n", "]g", function()
              if vim.wo.diff then
                vim.cmd.normal({ "]c", bang = true })
              else
                gs.nav_hunk("next")
              end
            end, { desc = "Next git hunk" })

            map("n", "[g", function()
              if vim.wo.diff then
                vim.cmd.normal({ "[c", bang = true })
              else
                gs.nav_hunk("prev")
              end
            end, { desc = "Previous git hunk" })

            -- Actions
            map("n", "<leader>gs", gs.stage_hunk, { desc = "Git: stage hunk" })
            map("n", "<leader>gr", gs.reset_hunk, { desc = "Git: reset hunk" })
            map("v", "<leader>gs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, { desc = "Git: stage hunk" })
            map("v", "<leader>gr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, { desc = "Git: reset hunk" })
            map("n", "<leader>gS", gs.stage_buffer, { desc = "Git: stage buffer" })
            map("n", "<leader>gR", gs.reset_buffer, { desc = "Git: reset buffer" })
            map("n", "<leader>gu", gs.undo_stage_hunk, { desc = "Git: undo stage hunk" })
            map("n", "<leader>gp", gs.preview_hunk, { desc = "Git: preview hunk" })
            map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, { desc = "Git: blame line" })
            map("n", "<leader>gB", gs.toggle_current_line_blame, { desc = "Git: toggle line blame" })
            map("n", "<leader>gd", gs.diffthis, { desc = "Git: diff this" })
            map("n", "<leader>gD", function() gs.diffthis("~") end, { desc = "Git: diff this ~" })

            -- Text object
            map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<cr>", { desc = "Select git hunk" })
          end,
        })
      end)


      -- ─── Harpoon 2 — Fast File Switching ──────────────────────────
      safe_setup("harpoon", function(harpoon)
        harpoon:setup({
          settings = {
            save_on_toggle = true,
            sync_on_ui_close = true,
            key = function()
              return vim.uv.cwd()
            end,
          },
        })

        vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end, { desc = "Harpoon: add file" })
        vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Harpoon: toggle menu" })
        vim.keymap.set("n", "<leader>1", function() harpoon:list():select(1) end, { desc = "Harpoon: file 1" })
        vim.keymap.set("n", "<leader>2", function() harpoon:list():select(2) end, { desc = "Harpoon: file 2" })
        vim.keymap.set("n", "<leader>3", function() harpoon:list():select(3) end, { desc = "Harpoon: file 3" })
        vim.keymap.set("n", "<leader>4", function() harpoon:list():select(4) end, { desc = "Harpoon: file 4" })
        vim.keymap.set("n", "<leader>5", function() harpoon:list():select(5) end, { desc = "Harpoon: file 5" })
        vim.keymap.set("n", "[h", function() harpoon:list():prev() end, { desc = "Harpoon: previous file" })
        vim.keymap.set("n", "]h", function() harpoon:list():next() end, { desc = "Harpoon: next file" })
      end)


      -- ─── Motion Training & Navigation Tools ───────────────────────────
      safe_setup("hardtime", function(hardtime)
        hardtime.setup({
          max_count = 3,
          disabled_filetypes = {
            "qf", "netrw", "NvimTree", "lazy", "mason", "oil",
            "snacks_dashboard", "dashboard", "trouble", "harpoon",
            "help", "undotree", "dapui_scopes", "dapui_breakpoints",
            "dapui_stacks", "dapui_watches", "dap-repl", "dapui_console",
          },
          disabled_buftypes = { "nofile", "prompt", "quickfix", "terminal" },
        })
        
        vim.keymap.set("n", "<leader>uh", function() hardtime.toggle() end, { desc = "Toggle Hardtime (motion trainer)" })
      end)

      safe_setup("precognition", function(precognition)
        precognition.setup({
          start_visible = false,
          show_blank = true,
        })

        vim.keymap.set("n", "<leader>up", function() precognition.toggle() end, { desc = "Toggle Precognition (motion guide)" })
      end)

      safe_setup("flash", function(flash)
        flash.setup({})

        vim.keymap.set({ "n", "x", "o" }, "s", function() flash.jump() end, { desc = "Flash jump" })
        vim.keymap.set({ "n", "x", "o" }, "S", function() flash.treesitter() end, { desc = "Flash treesitter" })
        vim.keymap.set("o", "r", function() flash.remote() end, { desc = "Remote Flash" })
        vim.keymap.set({ "o", "x" }, "R", function() flash.treesitter_search() end, { desc = "Treesitter search" })
        vim.keymap.set("c", "<c-s>", function() flash.toggle() end, { desc = "Toggle Flash search" })
      end)


      -- ─── Oil — File Explorer as a Buffer ──────────────────────────
      safe_setup("oil", function(oil)
        oil.setup({
          default_file_explorer = true,
          columns = {
            "icon",
            "size",
          },
          buf_options = {
            buflisted = false,
            bufhidden = "hide",
          },
          win_options = {
            wrap = false,
            signcolumn = "no",
            cursorcolumn = false,
            foldcolumn = "0",
            spell = false,
            list = false,
            conceallevel = 3,
            concealcursor = "nvic",
          },
          delete_to_trash = true,
          skip_confirm_for_simple_edits = true,
          prompt_save_on_select_new_entry = true,
          cleanup_delay_ms = 2000,
          lsp_file_methods = {
            timeout_ms = 1000,
            autosave_changes = false,
          },
          constrain_cursor = "editable",
          watch_for_changes = true,
          keymaps = {
            ["g?"] = "actions.show_help",
            ["<CR>"] = "actions.select",
            ["<C-v>"] = { "actions.select", opts = { vertical = true }, desc = "Open in vsplit" },
            ["<C-s>"] = { "actions.select", opts = { horizontal = true }, desc = "Open in hsplit" },
            ["<C-t>"] = { "actions.select", opts = { tab = true }, desc = "Open in new tab" },
            ["<C-p>"] = "actions.preview",
            ["<C-c>"] = "actions.close",
            ["<C-r>"] = "actions.refresh",
            ["-"] = "actions.parent",
            ["_"] = "actions.open_cwd",
            ["`"] = "actions.cd",
            ["~"] = { "actions.cd", opts = { scope = "tab" }, desc = ":tcd to the directory" },
            ["gs"] = "actions.change_sort",
            ["gx"] = "actions.open_external",
            ["g."] = "actions.toggle_hidden",
            ["g\\"] = "actions.toggle_trash",
          },
          use_default_keymaps = false,
          view_options = {
            show_hidden = true,
            is_hidden_file = function(name, _)
              return vim.startswith(name, ".")
            end,
            is_always_hidden = function(name, _)
              return name == ".." or name == ".git"
            end,
            natural_order = true,
            case_insensitive = false,
            sort = {
              { "type", "asc" },
              { "name", "asc" },
            },
          },
          float = {
            padding = 2,
            max_width = 90,
            max_height = 0,
            border = "rounded",
            win_options = {
              winblend = 0,
            },
          },
        })

        vim.keymap.set("n", "<leader>e", "<cmd>Oil<cr>", { desc = "Open file explorer (Oil)" })
        vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory" })
      end)


      -- ─── Testing — one workflow for Go, Rust, and C++ projects ────────
      safe_setup("neotest", function(neotest)
        local adapters = {}

        -- Go Adapter
        local ok_golang, neotest_golang = pcall(require, "neotest-golang")
        if ok_golang then
          table.insert(
            adapters,
            neotest_golang({
              runner = "go",
              go_test_args = { "-v", "-race", "-count=1" },
              dap_go_opts = {},
            })
          )
        else
          local ok_go, neotest_go = pcall(require, "neotest-go")
          if ok_go then
            table.insert(
              adapters,
              neotest_go({
                experimental = { test_table = true },
                args = { "-race", "-v", "-count=1" },
              })
            )
          end
        end

        -- Rust Adapter
        local ok_rustacean, rustacean_neotest = pcall(require, "rustaceanvim.neotest")
        if ok_rustacean then
          table.insert(adapters, rustacean_neotest)
        else
          local ok_rust, neotest_rust = pcall(require, "neotest-rust")
          if ok_rust then
            table.insert(
              adapters,
              neotest_rust({
                args = { "--no-capture" },
                dap_adapter = "codelldb",
              })
            )
          end
        end

        -- C++ Adapter
        local ok_gtest, neotest_gtest = pcall(require, "neotest-gtest")
        if ok_gtest then
          if type(neotest_gtest) == "function" then
            table.insert(adapters, neotest_gtest({}))
          elseif type(neotest_gtest.setup) == "function" then
            table.insert(adapters, neotest_gtest.setup({}))
          else
            table.insert(adapters, neotest_gtest)
          end
        end

        neotest.setup({
          adapters = adapters,
          status = { virtual_text = true, signs = true },
          output = { open_on_run = true },
          output_panel = { open_on_run = false },
          quickfix = { open = false },
        })

        vim.keymap.set("n", "<leader>tt", function() neotest.run.run() end, { desc = "Test: run nearest" })
        vim.keymap.set("n", "<leader>tf", function() neotest.run.run(vim.fn.expand("%")) end, { desc = "Test: run current file" })
        vim.keymap.set("n", "<leader>ta", function() neotest.run.run(vim.fn.getcwd()) end, { desc = "Test: run all (project)" })
        vim.keymap.set("n", "<leader>tw", function() neotest.watch.toggle() end, { desc = "Test: toggle watch mode" })
        vim.keymap.set("n", "<leader>td", function() neotest.run.run({ strategy = "dap" }) end, { desc = "Test: debug nearest (DAP)" })
        vim.keymap.set("n", "<leader>ts", function() neotest.summary.toggle() end, { desc = "Test: toggle summary" })
        vim.keymap.set("n", "<leader>to", function() neotest.output.open({ enter = true }) end, { desc = "Test: open output window" })
        vim.keymap.set("n", "<leader>tO", function() neotest.output_panel.toggle() end, { desc = "Test: toggle output panel" })
        vim.keymap.set("n", "<leader>tS", function() neotest.run.stop() end, { desc = "Test: stop running test" })
        vim.keymap.set("n", "]T", function() neotest.jump.next({ status = "failed" }) end, { desc = "Test: jump next failed" })
        vim.keymap.set("n", "[T", function() neotest.jump.prev({ status = "failed" }) end, { desc = "Test: jump previous failed" })
      end)


      -- ─── Vim-Tmux Navigator ───────────────────────────────────────
      -- Init (runs before loaded typically, so doing it first)
      vim.g.tmux_navigator_no_mappings = 1
      vim.g.tmux_navigator_save_on_switch = 2
      vim.g.tmux_navigator_disable_when_zoomed = 1
      vim.g.tmux_navigator_preserve_zoom = 1

      vim.keymap.set("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>", { desc = "Navigate left (tmux-aware)" })
      vim.keymap.set("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>", { desc = "Navigate down (tmux-aware)" })
      vim.keymap.set("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>", { desc = "Navigate up (tmux-aware)" })
      vim.keymap.set("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>", { desc = "Navigate right (tmux-aware)" })


      -- ─── TODO Comments ────────────────────────────────────────────
      safe_setup("todo-comments", function(todo)
        todo.setup({
          signs = true,
          sign_priority = 8,
          keywords = {
            FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
            TODO = { icon = " ", color = "info" },
            HACK = { icon = " ", color = "warning" },
            WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
            PERF = { icon = "󰅒 ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
            NOTE = { icon = "󰍨 ", color = "hint", alt = { "INFO" } },
            TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
          },
          merge_keywords = true,
          highlight = {
            multiline = true,
            multiline_pattern = "^.",
            multiline_context = 10,
            before = "",
            keyword = "wide",
            after = "fg",
            pattern = [[.*<(KEYWORDS)\s*:]],
            comments_only = true,
            max_line_len = 400,
            exclude = {},
          },
          search = {
            command = "rg",
            args = {
              "--color=never",
              "--no-heading",
              "--with-filename",
              "--line-number",
              "--column",
            },
            pattern = [[\b(KEYWORDS):]],
          },
        })

        vim.keymap.set("n", "]t", function() todo.jump_next() end, { desc = "Next TODO" })
        vim.keymap.set("n", "[t", function() todo.jump_prev() end, { desc = "Previous TODO" })
        vim.keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<cr>", { desc = "Find TODOs" })
        vim.keymap.set("n", "<leader>fT", "<cmd>TodoTelescope keywords=TODO,FIX,FIXME<cr>", { desc = "Find TODO/FIX/FIXME" })
      end)

      -- ─── Clangd Extensions ──────────────────────────────────────────
      safe_setup("clangd_extensions", function(clangd_ext)
        clangd_ext.setup({
          inlay_hints = {
            inline = false,
            only_current_line = false,
            only_current_line_autocmd = { "CursorHold" },
            show_parameter_hints = true,
            parameter_hints_prefix = "<- ",
            other_hints_prefix = "=> ",
            max_len_align = false,
            max_len_align_padding = 1,
            right_align = false,
            right_align_padding = 7,
            highlight = "Comment",
            priority = 100,
          },
          ast = {
            role_icons = {
              type = "🄣",
              declaration = "🄓",
              expression = "🄔",
              statement = ";",
              specifier = "🄢",
              ["template argument"] = "🆃",
            },
            kind_icons = {
              Compound = "🄲",
              Recovery = "🅁",
              TranslationUnit = "🅄",
              PackExpansion = "🄿",
              TemplateTypeParm = "🅃",
              TemplateTemplateParm = "🅃",
              TemplateParamObject = "🅃",
            },
            highlights = {
              detail = "Comment",
            },
          },
          memory_usage = {
            border = "rounded",
          },
          symbol_info = {
            border = "rounded",
          },
          type_hierarchy = {
            border = "rounded",
          },
        })

        vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("ClangdKeymaps", { clear = true }),
          pattern = { "c", "cpp", "objc", "objcpp", "cuda" },
          callback = function(event)
            local map = function(keys, func, desc)
              vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "Clangd: " .. desc })
            end

            map("<leader>ch", "<cmd>ClangdSwitchSourceHeader<cr>", "Switch source/header")
            map("<leader>ct", "<cmd>ClangdTypeHierarchy<cr>", "Type hierarchy")
            map("<leader>cm", "<cmd>ClangdMemoryUsage<cr>", "Memory usage")
            map("<leader>cs", "<cmd>ClangdSymbolInfo<cr>", "Symbol info")
            map("<leader>cA", "<cmd>ClangdAST<cr>", "View AST")
          end,
        })
      end)

      -- ─── Go.nvim ────────────────────────────────────────────────────
      safe_setup("go", function(go)
        go.setup({
          lsp_cfg = false,
          lsp_on_attach = false,
          gofmt = "gofumpt",
          goimports = "gopls",
          linter = "golangci-lint",
          test_runner = "go",
          run_in_floaterm = true,
          floaterm = {
            position = "bottom",
            width = 0.98,
            height = 0.35,
          },
          dap_debug = true,
          dap_debug_gui = true,
          tag_transform = "snakecase",
          tag_options = "json=omitempty",
          verbose = false,
          log_path = vim.fn.stdpath("cache") .. "/gonvim.log",
          icons = { breakpoint = "🔴", currentpos = "🏃" },
        })

        vim.api.nvim_create_autocmd("FileType", {
          pattern = { "go" },
          callback = function(event)
            local map = function(keys, func, desc)
              vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "Go: " .. desc })
            end

            map("<leader>Gt", "<cmd>GoTest<cr>", "Run tests")
            map("<leader>Gf", "<cmd>GoTestFunc<cr>", "Test function")
            map("<leader>Gc", "<cmd>GoCoverage<cr>", "Toggle coverage")
            map("<leader>Ga", "<cmd>GoAddTag<cr>", "Add struct tags")
            map("<leader>Gr", "<cmd>GoRmTag<cr>", "Remove struct tags")
            map("<leader>Gi", "<cmd>GoImpl<cr>", "Implement interface")
            map("<leader>Ge", "<cmd>GoIfErr<cr>", "Generate if err")
            map("<leader>Gd", "<cmd>GoDebug<cr>", "Start debugger")
            map("<leader>GD", "<cmd>GoDebug -s<cr>", "Stop debugger")
            map("<leader>Gl", "<cmd>GoLint<cr>", "Lint")
            map("<leader>Gv", "<cmd>GoVet<cr>", "Vet")
            map("<leader>Gg", "<cmd>GoGenerate<cr>", "Go generate")
            map("<leader>Gm", "<cmd>GoModTidy<cr>", "Go mod tidy")
          end,
        })
      end)

      -- ─── TS Context Commentstring & Comment.nvim ───────────────────
      safe_setup("ts_context_commentstring", function(ts_cc)
        ts_cc.setup({
          enable_autocmd = false,
        })
        local ok_comm, comm = pcall(require, "Comment")
        if ok_comm then
          local ok_ts_hook, ts_hook = pcall(require, "ts_context_commentstring.integrations.comment_nvim")
          local pre_hook = ok_ts_hook and ts_hook.create_pre_hook() or nil
          comm.setup({
            padding = true,
            sticky = true,
            ignore = "^$",
            toggler = {
              line = "gcc",
              block = "gbc",
            },
            opleader = {
              line = "gc",
              block = "gb",
            },
            extra = {
              above = "gcO",
              below = "gco",
              eol = "gcA",
            },
            mappings = {
              basic = true,
              extra = true,
            },
            pre_hook = pre_hook,
          })
        end
      end)

      -- ─── nvim-lint ────────────────────────────────────────────────
      safe_setup("lint", function(lint)
        lint.linters["clang-tidy"] = lint.linters.clangtidy
        lint.linters["golangci-lint"] = lint.linters.golangcilint

        lint.linters_by_ft = {
          c = { "clang-tidy" },
          cpp = { "clang-tidy" },
          go = { "golangci-lint" },
          python = { "ruff" },
        }

        local lint_augroup = vim.api.nvim_create_augroup("NvimLintUser", { clear = true })

        local function run_lint()
          local bufnr = vim.api.nvim_get_current_buf()
          if not vim.api.nvim_buf_is_valid(bufnr) then
            return
          end
          local ft = vim.bo[bufnr].filetype
          if not ft or ft == "" then
            return
          end
          local linters = lint.linters_by_ft[ft] or {}
          if type(linters) ~= "table" or #linters == 0 then
            return
          end

          local valid_linters = {}
          for _, name in ipairs(linters) do
            local linter = lint.linters[name]
            if linter then
              local cmd = type(linter) == "table" and linter.cmd or name
              if type(cmd) == "function" then
                cmd = cmd()
              end
              if type(cmd) == "string" and vim.fn.executable(cmd) == 1 then
                table.insert(valid_linters, name)
              end
            end
          end

          if #valid_linters > 0 then
            lint.try_lint(valid_linters)
          end
        end

        vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
          group = lint_augroup,
          callback = run_lint,
        })

        vim.api.nvim_create_user_command("Lint", function()
          run_lint()
        end, { desc = "Trigger linting for current buffer" })

        vim.keymap.set("n", "<leader>cl", function()
          run_lint()
        end, { desc = "Lint current buffer" })
      end)

      -- ─── Rustaceanvim ──────────────────────────────────────────────
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local ok_blink, blink = pcall(require, "blink.cmp")
      if ok_blink then
        capabilities = blink.get_lsp_capabilities(capabilities)
      end

      vim.g.rustaceanvim = {
        tools = {
          hover_actions = {
            replace_builtin_hover = false,
          },
          float_win_config = {
            border = "rounded",
          },
        },
        server = {
          capabilities = capabilities,
          on_attach = function(client, bufnr)
            local map = function(keys, func, desc)
              vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "Rust: " .. desc })
            end

            map("<leader>re", "<cmd>RustLsp expandMacro<cr>", "Expand macro")
            map("<leader>rc", "<cmd>RustLsp openCargo<cr>", "Open Cargo.toml")
            map("<leader>rp", "<cmd>RustLsp parentModule<cr>", "Parent module")
            map("<leader>rd", "<cmd>RustLsp renderDiagnostic<cr>", "Render diagnostic")
            map("<leader>rr", "<cmd>RustLsp runnables<cr>", "Runnables")
            map("<leader>rt", "<cmd>RustLsp testables<cr>", "Testables")
            map("<leader>rm", "<cmd>RustLsp rebuildProcMacros<cr>", "Rebuild proc macros")
            map("<leader>rk", "<cmd>RustLsp moveItem up<cr>", "Move item up")
            map("<leader>rj", "<cmd>RustLsp moveItem down<cr>", "Move item down")
            map("<leader>ra", "<cmd>RustLsp codeAction<cr>", "Code action (rust)")
            map("<leader>rh", "<cmd>RustLsp hover actions<cr>", "Hover actions")
            map("J", "<cmd>RustLsp joinLines<cr>", "Join lines (Rust)")
            map("<leader>rD", "<cmd>RustLsp debuggables<cr>", "Debuggables")
          end,
          default_settings = {
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = true,
                loadOutDirsFromCheck = true,
                buildScripts = { enable = true },
              },
              checkOnSave = true,
              check = {
                command = "clippy",
                extraArgs = { "--no-deps" },
              },
              procMacro = {
                enable = true,
                ignored = {
                  ["async-trait"] = { "async_trait" },
                  ["napi-derive"] = { "napi" },
                  ["async-recursion"] = { "async_recursion" },
                },
              },
              inlayHints = {
                bindingModeHints = { enable = false },
                chainingHints = { enable = true },
                closingBraceHints = { enable = true, minLines = 25 },
                closureReturnTypeHints = { enable = "with_block" },
                lifetimeElisionHints = { enable = "never" },
                maxLength = 25,
                parameterHints = { enable = true },
                reborrowHints = { enable = "never" },
                renderColons = true,
                typeHints = {
                  enable = true,
                  hideClosureInitialization = false,
                  hideNamedConstructor = false,
                },
              },
            },
          },
        },
        dap = {
          adapter = function()
            local ok_cfg, cfg = pcall(require, "rustaceanvim.config")
            if not ok_cfg then return nil end
            local mason_path = vim.fn.stdpath("data") .. "/mason/packages/codelldb"
            local codelldb_path = mason_path .. "/extension/adapter/codelldb"
            local liblldb_path = mason_path .. "/extension/lldb/lib/liblldb.so"

            if vim.fn.filereadable(codelldb_path) == 1 then
              return cfg.get_codelldb_adapter(codelldb_path, liblldb_path)
            else
              return cfg.get_codelldb_adapter("codelldb", "")
            end
          end,
        },
      }

      -- ─── Which-Key Specifications ──────────────────────────────────
      local ok_wk, wk = pcall(require, "which-key")
      if ok_wk then
        wk.setup({
          preset = "modern",
          delay = 300,
          win = {
            border = "rounded",
            padding = { 1, 2 },
            title = true,
            title_pos = "center",
            zindex = 1000,
          },
          layout = {
            width = { min = 20 },
            spacing = 3,
          },
          keys = {
            scroll_down = "<c-d>",
            scroll_up = "<c-u>",
          },
          show_help = true,
          show_keys = true,
          triggers = {
            { "<auto>", mode = "nxsot" },
          },
        })
        wk.add({
          { "<leader>f", group = "Find", icon = " " },
          { "<leader>e", group = "Explorer", icon = "󰙅 " },
          { "<leader>a", group = "Harpoon", icon = "󰛢 " },
          { "<leader>b", group = "Buffer", icon = "󰓩 " },
          { "<leader>l", group = "LSP", icon = " " },
          { "<leader>c", group = "Code", icon = "󰅩 " },
          { "<leader>C", group = "CMake/Build", icon = " " },
          { "<leader>r", group = "Rust", icon = "󱘗 " },
          { "<leader>G", group = "Go", icon = " " },
          { "<leader>t", group = "Test", icon = "󰙨 " },
          { "<leader>d", group = "Debug", icon = " " },
          { "<leader>u", group = "UI/Toggles", icon = "󱄄 " },
          { "<leader>g", group = "Git", icon = "󰊢 " },
          { "<leader>s", group = "Swap/Search", icon = "󰔡 " },
          { "<leader>x", group = "Trouble/Diagnostics", icon = "󰅙 " },
          { "<leader>n", group = "Noice", icon = "󰎟 " },
          { "<leader>w", icon = "󰆓 " },
          { "<leader>q", icon = "󰩈 " },
          { "<leader>L", icon = "󰒲 " },
        })

        vim.keymap.set("n", "<leader>?", function()
          wk.show({ global = false })
        end, { desc = "Buffer-local keymaps (which-key)" })
      end

      -- ─── Telescope Configuration & Keymaps ────────────────────────
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

        local map = vim.keymap.set
        map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
        map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
        map("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Find buffers" })
        map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Help tags" })
        map("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Recent files" })
        map("n", "<leader>fd", "<cmd>Telescope diagnostics<cr>", { desc = "Diagnostics" })
        map("n", "<leader>fw", "<cmd>Telescope grep_string<cr>", { desc = "Find word under cursor" })
        map("n", "<leader>fk", "<cmd>Telescope keymaps<cr>", { desc = "Keymaps" })
        map("n", "<leader>fc", "<cmd>Telescope commands<cr>", { desc = "Commands" })
        map("n", "<leader>fm", "<cmd>Telescope marks<cr>", { desc = "Marks" })
        map("n", "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", { desc = "Document symbols" })
        map("n", "<leader>fS", "<cmd>Telescope lsp_workspace_symbols<cr>", { desc = "Workspace symbols" })
        map("n", "<leader>gc", "<cmd>Telescope git_commits<cr>", { desc = "Git commits" })
        map("n", "<leader>gC", "<cmd>Telescope git_bcommits<cr>", { desc = "Git buffer commits" })
        map("n", "<leader>gt", "<cmd>Telescope git_status<cr>", { desc = "Git status" })
        map("n", "<leader><leader>", "<cmd>Telescope resume<cr>", { desc = "Resume last search" })
      end

      -- ─── Treesitter Textobjects ───────────────────────────────────
      local ok_ts_configs, ts_configs = pcall(require, "nvim-treesitter.configs")
      if ok_ts_configs then
        ts_configs.setup({
          textobjects = {
            select = {
              enable = true,
              lookahead = true,
              keymaps = {
                ["af"] = { query = "@function.outer", desc = "Around function" },
                ["if"] = { query = "@function.inner", desc = "Inside function" },
                ["ac"] = { query = "@class.outer", desc = "Around class" },
                ["ic"] = { query = "@class.inner", desc = "Inside class" },
                ["aa"] = { query = "@parameter.outer", desc = "Around argument" },
                ["ia"] = { query = "@parameter.inner", desc = "Inside argument" },
                ["al"] = { query = "@loop.outer", desc = "Around loop" },
                ["il"] = { query = "@loop.inner", desc = "Inside loop" },
                ["ai"] = { query = "@conditional.outer", desc = "Around conditional" },
                ["ii"] = { query = "@conditional.inner", desc = "Inside conditional" },
                ["ab"] = { query = "@block.outer", desc = "Around block" },
                ["ib"] = { query = "@block.inner", desc = "Inside block" },
              },
            },
            move = {
              enable = true,
              goto_next_start = {
                ["]f"] = { query = "@function.outer", desc = "Next function start" },
                ["]c"] = { query = "@class.outer", desc = "Next class start" },
                ["]a"] = { query = "@parameter.inner", desc = "Next argument" },
              },
              goto_next_end = {
                ["]F"] = { query = "@function.outer", desc = "Next function end" },
                ["]C"] = { query = "@class.outer", desc = "Next class end" },
              },
              goto_previous_start = {
                ["[f"] = { query = "@function.outer", desc = "Previous function start" },
                ["[c"] = { query = "@class.outer", desc = "Previous class start" },
                ["[a"] = { query = "@parameter.inner", desc = "Previous argument" },
              },
              goto_previous_end = {
                ["[F"] = { query = "@function.outer", desc = "Previous function end" },
                ["[C"] = { query = "@class.outer", desc = "Previous class end" },
              },
            },
            swap = {
              enable = true,
              swap_next = {
                ["<leader>cx"] = { query = "@parameter.inner", desc = "Swap with next parameter" },
              },
              swap_previous = {
                ["<leader>cX"] = { query = "@parameter.inner", desc = "Swap with previous parameter" },
              },
            },
          },
        })
      else
        local ok_ts_to, ts_to = pcall(require, "nvim-treesitter-textobjects")
        if ok_ts_to then
          ts_to.setup({
            select = {
              lookahead = true,
            },
            move = {
              set_jumps = true,
            },
          })

          local map = vim.keymap.set
          local sel = require("nvim-treesitter-textobjects.select")
          local mov = require("nvim-treesitter-textobjects.move")
          local swp = require("nvim-treesitter-textobjects.swap")

          local select_maps = {
            ["af"] = { query = "@function.outer", desc = "Around function" },
            ["if"] = { query = "@function.inner", desc = "Inside function" },
            ["ac"] = { query = "@class.outer", desc = "Around class" },
            ["ic"] = { query = "@class.inner", desc = "Inside class" },
            ["aa"] = { query = "@parameter.outer", desc = "Around argument" },
            ["ia"] = { query = "@parameter.inner", desc = "Inside argument" },
            ["al"] = { query = "@loop.outer", desc = "Around loop" },
            ["il"] = { query = "@loop.inner", desc = "Inside loop" },
            ["ai"] = { query = "@conditional.outer", desc = "Around conditional" },
            ["ii"] = { query = "@conditional.inner", desc = "Inside conditional" },
            ["ab"] = { query = "@block.outer", desc = "Around block" },
            ["ib"] = { query = "@block.inner", desc = "Inside block" },
          }
          for k, v in pairs(select_maps) do
            map({ "x", "o" }, k, function()
              sel.select_textobject(v.query)
            end, { desc = v.desc })
          end

          map({ "n", "x", "o" }, "]f", function() mov.goto_next_start("@function.outer") end, { desc = "Next function start" })
          map({ "n", "x", "o" }, "]c", function() mov.goto_next_start("@class.outer") end, { desc = "Next class start" })
          map({ "n", "x", "o" }, "]a", function() mov.goto_next_start("@parameter.inner") end, { desc = "Next argument" })
          map({ "n", "x", "o" }, "]F", function() mov.goto_next_end("@function.outer") end, { desc = "Next function end" })
          map({ "n", "x", "o" }, "]C", function() mov.goto_next_end("@class.outer") end, { desc = "Next class end" })
          map({ "n", "x", "o" }, "[f", function() mov.goto_previous_start("@function.outer") end, { desc = "Previous function start" })
          map({ "n", "x", "o" }, "[c", function() mov.goto_previous_start("@class.outer") end, { desc = "Previous class start" })
          map({ "n", "x", "o" }, "[a", function() mov.goto_previous_start("@parameter.inner") end, { desc = "Previous argument" })
          map({ "n", "x", "o" }, "[F", function() mov.goto_previous_end("@function.outer") end, { desc = "Previous function end" })
          map({ "n", "x", "o" }, "[C", function() mov.goto_previous_end("@class.outer") end, { desc = "Previous class end" })

          map("n", "<leader>cx", function() swp.swap_next("@parameter.inner") end, { desc = "Swap with next parameter" })
          map("n", "<leader>cX", function() swp.swap_previous("@parameter.inner") end, { desc = "Swap with previous parameter" })
        end
      end

    '';
  };
}
