{ lib, ... }: {
  config.vim = {
    git.gitsigns = {
      enable = true;
      setupOpts = {
        signs = {
          add = {
            text = "▎";
          };
          change = {
            text = "▎";
          };
          delete = {
            text = "";
          };
          topdelete = {
            text = "";
          };
          changedelete = {
            text = "▎";
          };
          untracked = {
            text = "▎";
          };
        };
        signs_staged = {
          add = {
            text = "▎";
          };
          change = {
            text = "▎";
          };
          delete = {
            text = "";
          };
          topdelete = {
            text = "";
          };
          changedelete = {
            text = "▎";
          };
        };
        current_line_blame = false;
        current_line_blame_opts = {
          virt_text = true;
          virt_text_pos = "eol";
          delay = 500;
          ignore_whitespace = false;
        };
        current_line_blame_formatter = "<author>, <author_time:%R> - <summary>";
        preview_config = {
          border = "rounded";
          style = "minimal";
          relative = "cursor";
          row = 0;
          col = 1;
        };
        on_attach = lib.mkLuaInline ''
          function(bufnr)
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
          end
        '';
      };
    };

    utility.diffview-nvim.enable = true;
  };
}
