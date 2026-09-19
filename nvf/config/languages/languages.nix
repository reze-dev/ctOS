{ pkgs, ... }: {
  config.vim = {
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

    extraPlugins = with pkgs.vimPlugins; {
      clangd_extensions-nvim = {
        package = clangd_extensions-nvim;
      };
      go-nvim = {
        package = go-nvim;
      };
      guihua-lua = {
        package = guihua-lua;
      };
    };

    luaConfigRC.language_tools = ''
      -- Clangd Extensions
      local ok_clangd, clangd_ext = pcall(require, "clangd_extensions")
      if ok_clangd then
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
              type = "",
              declaration = "",
              expression = "",
              statement = "",
              specifier = "",
              ["template argument"] = "",
            },
            kind_icons = {
              Compound = "",
              Recovery = "",
              TranslationUnit = "",
              PackExpansion = "",
              TemplateTypeParm = "",
              TemplateTemplateParm = "",
              TemplateParamObject = "",
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
      end

      -- Go.nvim
      local ok_go, gonvim = pcall(require, "go")
      if ok_go then
        gonvim.setup({
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
          icons = { breakpoint = "", currentpos = "" },
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
      end

      -- Rustaceanvim
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
            local codelldb_path = "${pkgs.vscode-extensions.vadimcn.vscode-lldb.adapter}/bin/codelldb"
            local liblldb_path = "${pkgs.vscode-extensions.vadimcn.vscode-lldb.adapter}/share/lldb/lib/liblldb.so"

            if vim.fn.filereadable(codelldb_path) == 1 or vim.fn.executable(codelldb_path) == 1 then
              return cfg.get_codelldb_adapter(codelldb_path, liblldb_path)
            elseif vim.fn.executable("codelldb") == 1 then
              return cfg.get_codelldb_adapter(vim.fn.exepath("codelldb"), "")
            else
              return cfg.get_codelldb_adapter("codelldb", "")
            end
          end,
        },
      }
    '';
  };
}
