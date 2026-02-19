{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      marp-cli # Terminal Markdown presenter
      rumdl # Markdown linter
    ];
  };

  programs = {
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "[markdown]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
          "emojisense.languages" = {
            plaintext = false;
            markdown = true;
            json = true;
            scminput = true;
          };
          "markdown.preview.breaks" = true;
          "rumdl.server.path" = "${pkgs.rumdl}/bin/rumdl";
        };
        extensions = with pkgs; [
          vscode-marketplace.bierner.emojisense
          vscode-marketplace.bierner.markdown-emoji
          vscode-marketplace.budparr.language-hugo-vscode
          vscode-marketplace.marp-team.marp-vscode
          vscode-marketplace.rusnasonov.vscode-hugo
          vscode-marketplace.rvben.rumdl
          vscode-marketplace.yzhang.markdown-all-in-one
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "emoji-completions"
        "rumdl"
      ];
      userSettings = {
        languages = {
          Markdown = {
            formatter = {
              external = {
                command = "prettier";
                arguments = [
                  "--stdin-filepath"
                  "{buffer_path}"
                ];
              };
            };
          };
        };
      };
    };
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = with pkgs.vimPlugins; [
        # Treesitter parsers for markdown syntax
        (nvim-treesitter.withPlugins (p: [
          p.markdown
          p.markdown_inline
        ]))
        # Markdown rendering in buffers (including CodeCompanion chat)
        render-markdown-nvim
        # Paste images from clipboard into markdown
        img-clip-nvim
        # Preview images within Neovim (works with Kitty terminal)
        image-nvim
      ];
      extraLuaConfig = ''
        -- Image Preview: Display images in Neovim using Kitty graphics protocol
        -- Allows viewing PNG/JPG files directly in the editor
        -- Note: hijack_file_patterns requires TERM=xterm-kitty or KITTY_WINDOW_ID detection
        require("image").setup({
          backend = "kitty",
          processor = "magick_cli",  -- Explicitly use ImageMagick (required for image processing)
          integrations = {
            markdown = {
              enabled = true,
              clear_in_insert_mode = false,
              download_remote_images = true,
              only_render_image_at_cursor = false,
            },
          },
          max_width = nil,
          max_height = nil,
          max_width_window_percentage = 80,
          max_height_window_percentage = 80,
          window_overlap_clear_enabled = true,
          window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
          editor_only_render_when_focused = false,
          tmux_show_only_in_active_window = true,
          hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp" },
        })

        -- Render Markdown: Beautiful markdown rendering in Neovim
        -- Renders markdown in real-time with inline code blocks, tables, headings, etc.
        -- Configured to work with CodeCompanion chat buffers
        require('render-markdown').setup {
          file_types = { 'markdown', 'codecompanion' },  -- Enable for markdown and AI chat
          render_modes = { 'n', 'i', 'v', 'c' },         -- Render in all modes (modeless UX)
          anti_conceal = {
            enabled = true,  -- Show raw markdown when cursor is on the line
          },
          heading = {
            enabled = true,
            sign = false,    -- Don't use sign column (would conflict with gitsigns)
            icons = { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' },  -- Fancy heading icons
            backgrounds = {  -- Subtle background highlights for headings
              'RenderMarkdownH1Bg',
              'RenderMarkdownH2Bg',
              'RenderMarkdownH3Bg',
              'RenderMarkdownH4Bg',
              'RenderMarkdownH5Bg',
              'RenderMarkdownH6Bg',
            },
          },
          code = {
            enabled = true,
            sign = false,
            style = 'full',      -- Render code blocks with full styling
            left_pad = 1,
            right_pad = 1,
            width = 'block',     -- Use full block width for code
            border = 'thin',     -- Thin border around code blocks
          },
          bullet = {
            enabled = true,
            icons = { '●', '○', '◆', '◇' },  -- Nice bullet point progression
          },
          checkbox = {
            enabled = true,
            unchecked = {
              icon = '󰄱 ',
            },
            checked = {
              icon = '󰱒 ',
            },
          },
          quote = {
            enabled = true,
            icon = '▋',
          },
          link = {
            enabled = true,
            image = '󰥶 ',       -- Icon for images
            hyperlink = '󰌹 ',   -- Icon for links
          },
        }

        -- img-clip: Paste images from clipboard into markdown
        -- Integrates with CodeCompanion for pasting images into AI chat
        require('img-clip').setup {
          default = {
            prompt_for_file_name = true,     -- Ask for filename when pasting
            use_absolute_path = false,       -- Use relative paths in markdown
            relative_to_current_file = true,
          },
          filetypes = {
            -- Markdown files: save images in same directory
            markdown = {
              template = '![$CURSOR]($FILE_PATH)',
            },
            -- CodeCompanion chat: use absolute paths and simple template
            codecompanion = {
              prompt_for_file_name = false,  -- Auto-generate name in chat
              template = '[Image]($FILE_PATH)',
              use_absolute_path = true,      -- Absolute paths for portability
            },
          },
        }

        -- Smart paste: detects if clipboard has image or text
        -- Ctrl+Shift+V: paste image (CUA-friendly alternative to Ctrl+V for images)
        -- This mimics VSCode/modern editor behaviour where Shift+Paste handles images
        local function smart_paste_image()
          local clip = require('img-clip.clipboard')
          if clip.content_is_image() then
            vim.cmd('PasteImage')
          else
            -- No image in clipboard, inform user
            vim.notify('Clipboard contains text, not an image. Use Ctrl+V to paste text.', vim.log.levels.INFO)
          end
        end

        -- Ctrl+Shift+V: Smart image paste (works in both modes)
        vim.keymap.set({'n', 'i'}, '<C-S-v>', smart_paste_image, {
          noremap = true,
          silent = false,
          desc = 'Paste image from clipboard',
        })

        -- Alt+V: Alternative for terminals that don't support Ctrl+Shift+V
        vim.keymap.set({'n', 'i'}, '<M-v>', smart_paste_image, {
          noremap = true,
          silent = false,
          desc = 'Paste image from clipboard (alternative)',
        })

        -- Markdown formatting with prettier
        require('conform').formatters_by_ft.markdown = { 'prettier' }
      '';
    };
  };
}
