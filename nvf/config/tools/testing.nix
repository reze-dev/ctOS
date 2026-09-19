{ pkgs, ... }: {
  config.vim = {
    extraPlugins = with pkgs.vimPlugins; {
      neotest = {
        package = neotest;
      };
      neotest-go = {
        package = neotest-go;
      };
      neotest-rust = {
        package = neotest-rust;
      };
      neotest-gtest = {
        package = neotest-gtest;
      };
      neotest-golang = {
        package = neotest-golang;
      };
      fixcursorhold-nvim = {
        package = FixCursorHold-nvim;
      };
    };

    luaConfigRC.neotest_setup = ''
      local ok_neotest, neotest = pcall(require, "neotest")
      if ok_neotest then
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

        local map = vim.keymap.set
        map("n", "<leader>tt", function() neotest.run.run() end, { desc = "Test: run nearest" })
        map("n", "<leader>tf", function() neotest.run.run(vim.fn.expand("%")) end, { desc = "Test: run current file" })
        map("n", "<leader>ta", function() neotest.run.run(vim.fn.getcwd()) end, { desc = "Test: run all (project)" })
        map("n", "<leader>tw", function() neotest.watch.toggle() end, { desc = "Test: toggle watch mode" })
        map("n", "<leader>td", function() neotest.run.run({ strategy = "dap" }) end, { desc = "Test: debug nearest (DAP)" })
        map("n", "<leader>ts", function() neotest.summary.toggle() end, { desc = "Test: toggle summary" })
        map("n", "<leader>to", function() neotest.output.open({ enter = true }) end, { desc = "Test: open output window" })
        map("n", "<leader>tO", function() neotest.output_panel.toggle() end, { desc = "Test: toggle output panel" })
        map("n", "<leader>tS", function() neotest.run.stop() end, { desc = "Test: stop running test" })
        map("n", "]T", function() neotest.jump.next({ status = "failed" }) end, { desc = "Test: jump next failed" })
        map("n", "[T", function() neotest.jump.prev({ status = "failed" }) end, { desc = "Test: jump previous failed" })
      end
    '';
  };
}
