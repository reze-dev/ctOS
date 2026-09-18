{ ... }: {
  config.vim = {
    binds.whichKey = {
      enable = true;
      setupOpts = {
        preset = "modern";
        delay = 300;
        win = {
          border = "rounded";
          padding = [
            1
            2
          ];
          title = true;
          title_pos = "center";
          zindex = 1000;
        };
        layout = {
          width = {
            min = 20;
          };
          spacing = 3;
        };
        keys = {
          scroll_down = "<c-d>";
          scroll_up = "<c-u>";
        };
        show_help = true;
        show_keys = true;
      };
    };

    luaConfigRC.whichkey_spec = ''
      local ok_wk, wk = pcall(require, "which-key")
      if ok_wk then
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
    '';
  };
}
