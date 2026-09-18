{ ... }: {
  config.vim.keymaps = [
    # Better escape
    {
      key = "jk";
      mode = "i";
      action = "<ESC>";
      desc = "Exit insert mode";
    }

    # Save & quit
    {
      key = "<leader>w";
      mode = "n";
      action = "<cmd>w<cr>";
      desc = "Save file";
    }
    {
      key = "<leader>q";
      mode = "n";
      action = "<cmd>q<cr>";
      desc = "Quit";
    }
    {
      key = "<leader>Q";
      mode = "n";
      action = "<cmd>qa!<cr>";
      desc = "Force quit all";
    }

    # Clear search highlights
    {
      key = "<leader>nh";
      mode = "n";
      action = "<cmd>nohlsearch<cr>";
      desc = "Clear search highlights";
    }

    # Better window navigation (overridden by tmux-navigator when in tmux)
    {
      key = "<C-h>";
      mode = "n";
      action = "<C-w>h";
      desc = "Move to left window";
    }
    {
      key = "<C-j>";
      mode = "n";
      action = "<C-w>j";
      desc = "Move to lower window";
    }
    {
      key = "<C-k>";
      mode = "n";
      action = "<C-w>k";
      desc = "Move to upper window";
    }
    {
      key = "<C-l>";
      mode = "n";
      action = "<C-w>l";
      desc = "Move to right window";
    }

    # Resize windows with arrows
    {
      key = "<C-Up>";
      mode = "n";
      action = "<cmd>resize +2<cr>";
      desc = "Increase window height";
    }
    {
      key = "<C-Down>";
      mode = "n";
      action = "<cmd>resize -2<cr>";
      desc = "Decrease window height";
    }
    {
      key = "<C-Left>";
      mode = "n";
      action = "<cmd>vertical resize -2<cr>";
      desc = "Decrease window width";
    }
    {
      key = "<C-Right>";
      mode = "n";
      action = "<cmd>vertical resize +2<cr>";
      desc = "Increase window width";
    }

    # Buffer navigation
    {
      key = "<S-h>";
      mode = "n";
      action = "<cmd>bprevious<cr>";
      desc = "Previous buffer";
    }
    {
      key = "<S-l>";
      mode = "n";
      action = "<cmd>bnext<cr>";
      desc = "Next buffer";
    }
    {
      key = "<leader>bd";
      mode = "n";
      action = "<cmd>bdelete<cr>";
      desc = "Close buffer";
    }
    {
      key = "<leader>bD";
      mode = "n";
      action = "<cmd>bdelete!<cr>";
      desc = "Force close buffer";
    }

    # Move lines up/down in visual mode
    {
      key = "J";
      mode = "v";
      action = ":m '>+1<cr>gv=gv";
      desc = "Move selection down";
    }
    {
      key = "K";
      mode = "v";
      action = ":m '<-2<cr>gv=gv";
      desc = "Move selection up";
    }

    # Stay in visual mode when indenting
    {
      key = "<";
      mode = "v";
      action = "<gv";
      desc = "Indent left";
    }
    {
      key = ">";
      mode = "v";
      action = ">gv";
      desc = "Indent right";
    }

    # Keep cursor centered when scrolling
    {
      key = "<C-d>";
      mode = "n";
      action = "<C-d>zz";
      desc = "Scroll down (centered)";
    }
    {
      key = "<C-u>";
      mode = "n";
      action = "<C-u>zz";
      desc = "Scroll up (centered)";
    }

    # Keep search terms centered
    {
      key = "n";
      mode = "n";
      action = "nzzzv";
      desc = "Next search result (centered)";
    }
    {
      key = "N";
      mode = "n";
      action = "Nzzzv";
      desc = "Previous search result (centered)";
    }

    # Join lines without moving cursor
    {
      key = "J";
      mode = "n";
      action = "mzJ`z";
      desc = "Join lines";
    }

    # Paste without losing register content
    {
      key = "<leader>p";
      mode = "x";
      action = "\"_dP";
      desc = "Paste without overwriting register";
    }

    # Delete without yanking
    {
      key = "<leader>d";
      mode = "x";
      action = "\"_d";
      desc = "Delete without yanking";
    }

    # Better terminal navigation
    {
      key = "<C-h>";
      mode = "t";
      action = "<cmd>wincmd h<cr>";
      desc = "Move to left window (terminal)";
    }
    {
      key = "<C-j>";
      mode = "t";
      action = "<cmd>wincmd j<cr>";
      desc = "Move to lower window (terminal)";
    }
    {
      key = "<C-k>";
      mode = "t";
      action = "<cmd>wincmd k<cr>";
      desc = "Move to upper window (terminal)";
    }
    {
      key = "<C-l>";
      mode = "t";
      action = "<cmd>wincmd l<cr>";
      desc = "Move to right window (terminal)";
    }
    {
      key = "<Esc><Esc>";
      mode = "t";
      action = ''<C-\><C-n>'';
      desc = "Exit terminal mode";
    }

    # Quickfix navigation
    {
      key = "]q";
      mode = "n";
      action = "<cmd>cnext<cr>zz";
      desc = "Next quickfix item";
    }
    {
      key = "[q";
      mode = "n";
      action = "<cmd>cprev<cr>zz";
      desc = "Previous quickfix item";
    }

    # Select all
    {
      key = "<C-a>";
      mode = "n";
      action = "gg<S-v>G";
      desc = "Select all";
    }

    # Package manager / configuration info
    {
      key = "<leader>L";
      mode = "n";
      action = "function() vim.notify('Configured declaratively via Nix / nvf flake', vim.log.levels.INFO, { title = 'Package Manager' }) end";
      lua = true;
      desc = "Open Lazy plugin manager / Nix info";
    }
  ];
}
