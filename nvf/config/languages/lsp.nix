{ ... }: {
  config.vim = {
    lsp = {
      enable = true;
      trouble = {
        enable = true;
        setupOpts = {
          use_diagnostic_signs = true;
        };
      };
    };

    luaConfigRC.lsp_config = ''
      vim.diagnostic.config({
        underline = true,
        update_in_insert = false,
        virtual_text = {
          spacing = 4,
          source = "if_many",
          prefix = "",
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
    '';

    keymaps = [
      {
        key = "<leader>xx";
        mode = "n";
        action = "<cmd>Trouble diagnostics toggle<cr>";
        desc = "Diagnostics (Trouble)";
      }
      {
        key = "<leader>xX";
        mode = "n";
        action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>";
        desc = "Buffer diagnostics (Trouble)";
      }
      {
        key = "<leader>xs";
        mode = "n";
        action = "<cmd>Trouble symbols toggle focus=false<cr>";
        desc = "Symbols (Trouble)";
      }
      {
        key = "<leader>xl";
        mode = "n";
        action = "<cmd>Trouble lsp toggle focus=false win.position=right<cr>";
        desc = "LSP references (Trouble)";
      }
      {
        key = "<leader>xL";
        mode = "n";
        action = "<cmd>Trouble loclist toggle<cr>";
        desc = "Location list (Trouble)";
      }
      {
        key = "<leader>xQ";
        mode = "n";
        action = "<cmd>Trouble qflist toggle<cr>";
        desc = "Quickfix list (Trouble)";
      }
    ];
  };
}
