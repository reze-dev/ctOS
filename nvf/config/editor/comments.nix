{ pkgs, lib, ... }: {
  config.vim = {
    comments.comment-nvim = {
      enable = true;
      setupOpts = {
        padding = true;
        sticky = true;
        ignore = "^$";
        toggler = {
          line = "gcc";
          block = "gbc";
        };
        opleader = {
          line = "gc";
          block = "gb";
        };
        extra = {
          above = "gcO";
          below = "gco";
          eol = "gcA";
        };
        mappings = {
          basic = true;
          extra = true;
        };
        pre_hook = lib.mkLuaInline ''
          function()
            local ok_hook, ts_hook = pcall(require, "ts_context_commentstring.integrations.comment_nvim")
            return ok_hook and ts_hook.create_pre_hook() or nil
          end
        '';
      };
    };

    extraPlugins = with pkgs.vimPlugins; {
      nvim-ts-context-commentstring = {
        package = nvim-ts-context-commentstring;
        setup = "require('ts_context_commentstring').setup({ enable_autocmd = false })";
      };
    };

    notes.todo-comments = {
      enable = true;
      setupOpts = {
        signs = true;
        sign_priority = 8;
        keywords = {
          FIX = {
            icon = " ";
            color = "error";
            alt = [
              "FIXME"
              "BUG"
              "FIXIT"
              "ISSUE"
            ];
          };
          TODO = {
            icon = " ";
            color = "info";
          };
          HACK = {
            icon = " ";
            color = "warning";
          };
          WARN = {
            icon = " ";
            color = "warning";
            alt = [
              "WARNING"
              "XXX"
            ];
          };
          PERF = {
            icon = "󰅒 ";
            alt = [
              "OPTIM"
              "PERFORMANCE"
              "OPTIMIZE"
            ];
          };
          NOTE = {
            icon = "󰍨 ";
            color = "hint";
            alt = [ "INFO" ];
          };
          TEST = {
            icon = "⏲ ";
            color = "test";
            alt = [
              "TESTING"
              "PASSED"
              "FAILED"
            ];
          };
        };
        merge_keywords = true;
        highlight = {
          multiline = true;
          multiline_pattern = "^.";
          multiline_context = 10;
          before = "";
          keyword = "wide";
          after = "fg";
          pattern = ''.*<(KEYWORDS)\s*:'';
          comments_only = true;
          max_line_len = 400;
          exclude = [ ];
        };
        search = {
          command = "rg";
          args = [
            "--color=never"
            "--no-heading"
            "--with-filename"
            "--line-number"
            "--column"
          ];
          pattern = ''\b(KEYWORDS):'';
        };
      };
    };

    keymaps = [
      {
        key = "]t";
        mode = "n";
        action = "function() require('todo-comments').jump_next() end";
        lua = true;
        desc = "Next TODO";
      }
      {
        key = "[t";
        mode = "n";
        action = "function() require('todo-comments').jump_prev() end";
        lua = true;
        desc = "Previous TODO";
      }
      {
        key = "<leader>ft";
        mode = "n";
        action = "<cmd>TodoTelescope<cr>";
        desc = "Find TODOs";
      }
      {
        key = "<leader>fT";
        mode = "n";
        action = "<cmd>TodoTelescope keywords=TODO,FIX,FIXME<cr>";
        desc = "Find TODO/FIX/FIXME";
      }
    ];
  };
}
