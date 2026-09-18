{ lib, ... }: {
  config.vim = {
    formatter.conform-nvim = {
      enable = true;
      setupOpts = {
        formatters_by_ft = {
          c = [ "clang-format" ];
          cpp = [ "clang-format" ];
          rust = [ "rustfmt" ];
          go = [
            "goimports"
            "gofumpt"
          ];
          lua = [ "stylua" ];
          python = [
            "ruff_format"
            "ruff_organize_imports"
          ];
          toml = [ "taplo" ];
          javascript = [ "prettier" ];
          typescript = [ "prettier" ];
          javascriptreact = [ "prettier" ];
          typescriptreact = [ "prettier" ];
          html = [ "prettier" ];
          css = [ "prettier" ];
          scss = [ "prettier" ];
          json = [ "prettier" ];
          jsonc = [ "prettier" ];
          yaml = [ "prettier" ];
          markdown = [ "prettier" ];
          graphql = [ "prettier" ];
          nix = [ "nixfmt" ];
          fish = [ "fish_indent" ];
          sh = [ "shfmt" ];
          bash = [ "shfmt" ];
          "_" = [ "trim_whitespace" ];
        };
        format_on_save = lib.mkLuaInline ''
          function(bufnr)
            if vim.b[bufnr].disable_autoformat or vim.g.disable_autoformat then
              return
            end
            return {
              timeout_ms = 500,
              lsp_format = "fallback",
            }
          end
        '';
        formatters = {
          shfmt = {
            prepend_args = [
              "-i"
              "2"
            ];
          };
          stylua = {
            prepend_args = [
              "--indent-type"
              "Spaces"
              "--indent-width"
              "2"
            ];
          };
          clang-format = {
            prepend_args = [ "-fallback-style=LLVM" ];
          };
        };
      };
    };

    keymaps = [
      {
        key = "<leader>cf";
        mode = [
          "n"
          "v"
        ];
        action = "function() require('conform').format({ async = false, timeout_ms = 3000, lsp_format = 'fallback' }) end";
        lua = true;
        desc = "Format buffer/selection";
      }
    ];

    luaConfigRC.conform_commands = ''
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
    '';
  };
}
