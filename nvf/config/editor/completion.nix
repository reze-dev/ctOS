{ ... }: {
  config.vim = {
    autocomplete = {
      nvim-cmp.enable = false;
      blink-cmp = {
        enable = true;
        friendly-snippets.enable = true;
        setupOpts = {
          keymap = {
            preset = "default";
            "<C-space>" = [
              "show"
              "show_documentation"
              "hide_documentation"
            ];
            "<C-e>" = [ "hide" ];
            "<CR>" = [
              "accept"
              "fallback"
            ];
            "<Tab>" = [
              "select_next"
              "snippet_forward"
              "fallback"
            ];
            "<S-Tab>" = [
              "select_prev"
              "snippet_backward"
              "fallback"
            ];
            "<C-j>" = [
              "select_next"
              "fallback"
            ];
            "<C-k>" = [
              "select_prev"
              "fallback"
            ];
            "<C-b>" = [
              "scroll_documentation_up"
              "fallback"
            ];
            "<C-f>" = [
              "scroll_documentation_down"
              "fallback"
            ];
          };
          appearance = {
            nerd_font_variant = "mono";
          };
          completion = {
            accept = {
              auto_brackets = {
                enabled = true;
              };
            };
            menu = {
              border = "rounded";
              winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None";
            };
            documentation = {
              auto_show = true;
              auto_show_delay_ms = 200;
              window = {
                border = "rounded";
                winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder";
              };
            };
            ghost_text = {
              enabled = true;
            };
          };
          signature = {
            enabled = true;
            window = {
              border = "rounded";
            };
          };
          fuzzy = {
            implementation = "prefer_rust";
          };
        };
      };
    };
  };
}
