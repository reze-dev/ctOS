{ lib, ... }: {
  config.vim = {
    tabline.nvimBufferline = {
      enable = true;
      setupOpts = {
        options = {
          mode = "buffers";
          themable = true;
          numbers = "none";
          close_command = "bdelete! %d";
          right_mouse_command = "bdelete! %d";
          left_mouse_command = "buffer %d";
          middle_mouse_command = null;
          indicator = {
            icon = "▎";
            style = "icon";
          };
          buffer_close_icon = "󰅖";
          modified_icon = "●";
          close_icon = "";
          left_trunc_marker = "";
          right_trunc_marker = "";
          max_name_length = 30;
          max_prefix_length = 30;
          truncate_names = true;
          tab_size = 21;
          diagnostics = "nvim_lsp";
          diagnostics_update_in_insert = false;
          diagnostics_indicator = lib.mkLuaInline ''
            function(count, level)
              local icon = level:match("error") and " " or " "
              return " " .. icon .. count
            end
          '';
          offsets = [
            {
              filetype = "oil";
              text = "  File Explorer";
              highlight = "Directory";
              text_align = "left";
              separator = true;
            }
          ];
          color_icons = true;
          show_buffer_icons = true;
          show_buffer_close_icons = true;
          show_close_icon = false;
          show_tab_indicators = true;
          show_duplicate_prefix = true;
          persist_buffer_sort = true;
          separator_style = "thin";
          enforce_regular_tabs = false;
          always_show_bufferline = true;
          hover = {
            enabled = true;
            delay = 200;
            reveal = [ "close" ];
          };
        };
      };
    };

    keymaps = [
      {
        key = "<leader>bp";
        mode = "n";
        action = "<cmd>BufferLineTogglePin<cr>";
        desc = "Pin buffer";
      }
      {
        key = "<leader>bx";
        mode = "n";
        action = "<cmd>BufferLineCloseOthers<cr>";
        desc = "Close other buffers";
      }
      {
        key = "<leader>br";
        mode = "n";
        action = "<cmd>BufferLineCloseRight<cr>";
        desc = "Close buffers to the right";
      }
      {
        key = "<leader>bl";
        mode = "n";
        action = "<cmd>BufferLineCloseLeft<cr>";
        desc = "Close buffers to the left";
      }
      {
        key = "<S-h>";
        mode = "n";
        action = "<cmd>BufferLineCyclePrev<cr>";
        desc = "Previous buffer";
      }
      {
        key = "<S-l>";
        mode = "n";
        action = "<cmd>BufferLineCycleNext<cr>";
        desc = "Next buffer";
      }
      {
        key = "[b";
        mode = "n";
        action = "<cmd>BufferLineCyclePrev<cr>";
        desc = "Previous buffer";
      }
      {
        key = "]b";
        mode = "n";
        action = "<cmd>BufferLineCycleNext<cr>";
        desc = "Next buffer";
      }
    ];
  };
}
