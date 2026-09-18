{ pkgs, ... }: {
  config.vim = {
    debugger.nvim-dap = {
      enable = true;
      ui = {
        enable = true;
        setupOpts = {
          icons = {
            expanded = "▾";
            collapsed = "▸";
            current_frame = "▸";
          };
          layouts = [
            {
              elements = [
                {
                  id = "scopes";
                  size = 0.35;
                }
                {
                  id = "breakpoints";
                  size = 0.15;
                }
                {
                  id = "stacks";
                  size = 0.25;
                }
                {
                  id = "watches";
                  size = 0.25;
                }
              ];
              size = 40;
              position = "left";
            }
            {
              elements = [
                {
                  id = "repl";
                  size = 0.5;
                }
                {
                  id = "console";
                  size = 0.5;
                }
              ];
              size = 0.25;
              position = "bottom";
            }
          ];
          floating = {
            border = "rounded";
            mappings = {
              close = [
                "q"
                "<Esc>"
              ];
            };
          };
        };
      };
    };

    extraPlugins = with pkgs.vimPlugins; {
      nvim-nio = {
        package = nvim-nio;
      };
      nvim-dap-virtual-text = {
        package = nvim-dap-virtual-text;
      };
      nvim-dap-go = {
        package = nvim-dap-go;
      };
      nvim-dap-python = {
        package = nvim-dap-python;
      };
    };

    luaConfigRC.dap_setup = ''
      local ok_dap, dap = pcall(require, "dap")
      if ok_dap then
        -- Signs
        vim.fn.sign_define("DapBreakpoint", { text = " ", texthl = "DiagnosticError", linehl = "", numhl = "" })
        vim.fn.sign_define("DapBreakpointCondition", { text = " ", texthl = "DiagnosticWarn", linehl = "", numhl = "" })
        vim.fn.sign_define("DapBreakpointRejected", { text = " ", texthl = "DiagnosticError", linehl = "", numhl = "" })
        vim.fn.sign_define("DapLogPoint", { text = " ", texthl = "DiagnosticInfo", linehl = "", numhl = "" })
        vim.fn.sign_define("DapStopped", { text = "▶ ", texthl = "DiagnosticOk", linehl = "DapStoppedLine", numhl = "" })
        vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })

        -- DAP UI Listeners
        local ok_dapui, dapui = pcall(require, "dapui")
        if ok_dapui then
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
      end
    '';
  };
}
