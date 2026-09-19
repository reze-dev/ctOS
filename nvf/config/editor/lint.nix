{ pkgs, ... }: {
  config.vim = {
    diagnostics = {
      presets = {
        clangtidy.enable = true;
        golangci-lint.enable = true;
      };
      nvim-lint = {
        enable = true;
        linters = {
          clang-tidy = {
            cmd = "${pkgs.clang-tools}/bin/clang-tidy";
          };
          ruff = {
            cmd = "${pkgs.ruff}/bin/ruff";
          };
        };
        linters_by_ft = {
          c = [ "clang-tidy" ];
          cpp = [ "clang-tidy" ];
          go = [ "golangci-lint" ];
          python = [ "ruff" ];
        };
      };
    };

    luaConfigRC.lint_setup = ''
      local ok, lint = pcall(require, "lint")
      if ok then
        if lint.linters.clangtidy and not lint.linters["clang-tidy"] then
          lint.linters["clang-tidy"] = lint.linters.clangtidy
        end
        if lint.linters.golangcilint and not lint.linters["golangci-lint"] then
          lint.linters["golangci-lint"] = lint.linters.golangcilint
        end
        if not lint.linters["ruff"] then
          lint.linters["ruff"] = {
            cmd = "${pkgs.ruff}/bin/ruff",
            stdin = true,
            args = { "check", "--force-exclude", "--stdin-filename", "$FILENAME", "-" },
          }
        end

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
      end
    '';
  };
}
