{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;

  # Fetch novim-mode plugin from GitHub (not in nixpkgs)
  novim-mode = pkgs.vimUtils.buildVimPlugin {
    pname = "novim-mode";
    version = "unstable-2025-01-10";
    src = pkgs.fetchFromGitHub {
      owner = "tombh";
      repo = "novim-mode";
      rev = "f32db9bc55f4649c600656c14c0778aa745cdb17";
      sha256 = "sha256-mEbXPtzFeJivezS3f8pYSh8MMVpj1Ky0anKUuk4yjFQ=";
    };
    meta = {
      homepage = "https://github.com/tombh/novim-mode";
      description = "Plugin to make Vim behave more like a 'normal' editor";
      license = lib.licenses.mit;
    };
  };
in
{
  catppuccin.nvim = {
    enable = config.programs.neovim.enable;
    flavor = catppuccinPalette.flavor;
  };

  programs = {
    neovim = {
      enable = true;
      defaultEditor = false; # micro is the default
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      plugins = with pkgs.vimPlugins; [
        # novim-mode for CUA/VSCode-style modeless editing
        novim-mode
        # Quality of life plugins
        vim-sensible
        vim-sleuth # Auto-detect indentation
        vim-commentary # gc to comment
        vim-surround # Surround text objects
        vim-lastplace # Restore cursor position
        # Visual enhancements
        nvim-web-devicons
        lualine-nvim
        indent-blankline-nvim
        # File management
        nvim-tree-lua
        telescope-nvim
        telescope-fzf-native-nvim
        telescope-ui-select-nvim
        plenary-nvim
        # Keybinding help
        which-key-nvim
        # Git integration
        gitsigns-nvim
        # Tab bar and buffer management
        bufferline-nvim
        bufdelete-nvim
        # LSP support
        nvim-lspconfig
        fidget-nvim
        lspkind-nvim
        # Treesitter for syntax highlighting
        # Core grammars only; language-specific grammars in their ecosystem configs
        (nvim-treesitter.withPlugins (p: [
          p.c
          p.cmake
          p.cpp
          p.make
          p.vim
          p.vimdoc
        ]))
        nvim-treesitter-context
        nvim-treesitter-textobjects
        # Autocompletion
        nvim-cmp
        cmp-nvim-lsp
        cmp-buffer
        cmp-path
        cmp_luasnip
        luasnip
        friendly-snippets
        # Formatting
        conform-nvim
        # Diagnostics
        trouble-nvim
        # Quality of life: auto-pairs, todo highlighting, terminal
        nvim-autopairs
        todo-comments-nvim
        toggleterm-nvim
        # AI assistance (Copilot)
        copilot-lua
        copilot-cmp
      ];
      extraConfig = ''
        " novim-mode is loaded automatically via the plugins list
        " This provides CUA/VSCode-style keybindings (Ctrl+S, Ctrl+C/V, etc.)

        " General settings
        set number
        set norelativenumber
        set noshowmode
        set cmdheight=0
        set laststatus=3
        set cursorline
        set scrolloff=8
        set signcolumn=yes
        set termguicolors
        set mouse=a
        set clipboard=unnamedplus
        set undofile

        " Indentation
        set tabstop=2
        set shiftwidth=2
        set expandtab
        set smartindent
      '';
      extraLuaConfig = lib.mkBefore ''
        -- Global LSP configuration (Neovim 0.11+ native API)
        -- Set default capabilities for all LSP servers (nvim-cmp integration)
        vim.lsp.config('*', {
          capabilities = require('cmp_nvim_lsp').default_capabilities(),
          root_markers = { '.git' },
        })

        -- Lualine statusbar with keybinding hints
        require('lualine').setup {
          options = {
            theme = 'catppuccin',
            component_separators = { left = "", right = "" },
            section_separators = { left = "", right = "" },
          },
          sections = {
            lualine_a = {'mode'},
            lualine_b = {'branch', 'diff', 'diagnostics'},
            lualine_c = {'filename'},
            lualine_x = {
              -- Keybinding hints (rotates to save space)
              { function() return "C-`:Term C-p:Files C-S-f:Search C-S-t:TODOs" end },
            },
            lualine_y = {'encoding', 'fileformat', 'filetype'},
            lualine_z = {'location'}
          },
        }

        -- Which-key for keybinding discovery popup
        require('which-key').setup {
          delay = 500,  -- Show popup after 500ms
          icons = {
            mappings = false,  -- Disable icons for cleaner look
          },
        }

        -- Git signs in the gutter (maximum bling)
        require('gitsigns').setup {
          signs = {
            add          = { text = "▎" },
            change       = { text = "▎" },
            delete       = { text = "" },
            topdelete    = { text = "" },
            changedelete = { text = "▎" },
            untracked    = { text = "┆" },
          },
          signs_staged = {
            add          = { text = "▎" },
            change       = { text = "▎" },
            delete       = { text = "" },
            topdelete    = { text = "" },
            changedelete = { text = "▎" },
          },
          signs_staged_enable = true,
          numhl = true,                     -- Colour line numbers by git status
          culhl = true,                     -- Highlight sign when cursor on line
          current_line_blame = true,        -- Show git blame inline
          current_line_blame_opts = {
            virt_text = true,
            virt_text_pos = "eol",
            delay = 300,
            ignore_whitespace = false,
          },
          current_line_blame_formatter = " <author>  <author_time:%Y-%m-%d>  <summary>",
          preview_config = {
            border = "rounded",
            style = "minimal",
          },
        }

        -- Indent guides
        require('ibl').setup {
          indent = { char = "│" },
          scope = { enabled = true },
        }

        -- File tree (opens by default, full-height on left for bufferline offset)
        require('nvim-tree').setup {
          view = {
            side = "left",
            width = 30,
            preserve_window_proportions = true,
          },
          renderer = { icons = { show = { file = true, folder = true, folder_arrow = true } } },
          actions = {
            open_file = {
              quit_on_open = false,        -- Keep tree open after opening file
              resize_window = false,       -- Don't resize tree when opening files
              window_picker = { enable = false },  -- Open in previous window, not picker
            },
          },
        }

        -- Bufferline tab bar
        require('bufferline').setup {
          options = {
            mode = "buffers",
            separator_style = "slant",
            show_buffer_close_icons = true,
            show_close_icon = false,
            diagnostics = "nvim_lsp",
            themable = true,
            always_show_bufferline = true,
            -- Use bufdelete for cleaner buffer closing (fixes offset issues)
            close_command = function(bufnr) require('bufdelete').bufdelete(bufnr, true) end,
            right_mouse_command = function(bufnr) require('bufdelete').bufdelete(bufnr, true) end,
            offsets = {
              {
                filetype = "NvimTree",
                text = "File Explorer",
                text_align = "left",
                highlight = "Directory",
                separator = true,
              },
            },
          },
        }
        -- Open tree on startup, then focus editor
        vim.api.nvim_create_autocmd("VimEnter", {
          callback = function()
            require('nvim-tree.api').tree.open()
            -- Move focus to the editor window (away from tree)
            vim.cmd('wincmd l')
          end
        })

        -- Telescope fuzzy finder with extensions
        local telescope = require('telescope')
        telescope.setup {
          extensions = {
            fzf = { fuzzy = true, override_generic_sorter = true, override_file_sorter = true },
            ["ui-select"] = { require("telescope.themes").get_dropdown {} },
          },
        }
        telescope.load_extension('fzf')
        telescope.load_extension('ui-select')

        -- Fidget for LSP progress
        require('fidget').setup {}

        -- Treesitter configuration
        require('nvim-treesitter.configs').setup {
          highlight = { enable = true },
          indent = { enable = true },
          textobjects = {
            select = {
              enable = true,
              lookahead = true,
              keymaps = {
                ["af"] = "@function.outer",
                ["if"] = "@function.inner",
                ["ac"] = "@class.outer",
                ["ic"] = "@class.inner",
              },
            },
          },
        }

        -- Treesitter context (sticky headers)
        require('treesitter-context').setup {
          enable = true,
          max_lines = 3,
        }

        -- Autocompletion with nvim-cmp
        local cmp = require('cmp')
        local luasnip = require('luasnip')
        local lspkind = require('lspkind')

        -- Load friendly-snippets
        require('luasnip.loaders.from_vscode').lazy_load()

        cmp.setup {
          snippet = {
            expand = function(args)
              luasnip.lsp_expand(args.body)
            end,
          },
          mapping = cmp.mapping.preset.insert({
            ['<C-Space>'] = cmp.mapping.complete(),
            ['<CR>'] = cmp.mapping.confirm({ select = true }),
            ['<Tab>'] = cmp.mapping(function(fallback)
              if cmp.visible() then
                cmp.select_next_item()
              elseif luasnip.expand_or_jumpable() then
                luasnip.expand_or_jump()
              else
                fallback()
              end
            end, { 'i', 's' }),
            ['<S-Tab>'] = cmp.mapping(function(fallback)
              if cmp.visible() then
                cmp.select_prev_item()
              elseif luasnip.jumpable(-1) then
                luasnip.jump(-1)
              else
                fallback()
              end
            end, { 'i', 's' }),
            ['<C-b>'] = cmp.mapping.scroll_docs(-4),
            ['<C-f>'] = cmp.mapping.scroll_docs(4),
            ['<C-e>'] = cmp.mapping.abort(),
          }),
          sources = cmp.config.sources({
            { name = 'copilot', group_index = 2 },  -- Copilot suggestions
            { name = 'nvim_lsp' },
            { name = 'luasnip' },
            { name = 'path' },
          }, {
            { name = 'buffer' },
          }),
          formatting = {
            format = lspkind.cmp_format({
              mode = 'symbol_text',
              maxwidth = 50,
              ellipsis_char = '...',
            }),
          },
        }

        -- Conform for formatting
        require('conform').setup {
          format_on_save = {
            timeout_ms = 500,
            lsp_fallback = true,
          },
          -- Formatters configured per-language in ecosystem configs
          formatters_by_ft = {},
        }

        -- Trouble for diagnostics
        require('trouble').setup {}

        -- Auto-pairs for brackets, quotes, etc.
        local npairs = require('nvim-autopairs')
        npairs.setup {
          check_ts = true,  -- Use treesitter for smarter pairing
          ts_config = {
            lua = { "string" },  -- Don't add pairs in lua string treesitter nodes
            javascript = { "template_string" },
            java = false,  -- Don't check treesitter on java
          },
          disable_filetype = { "TelescopePrompt", "vim" },
          fast_wrap = {
            map = "<M-e>",  -- Alt+e to wrap with pair
            chars = { "{", "[", "(", '"', "'" },
            pattern = [=[[%'%"%>%]%)%}%,]]=],
            end_key = "$",
            before_key = "h",
            after_key = "l",
            cursor_pos_before = true,
            keys = "qwertyuiopzxcvbnmasdfghjkl",
            manual_position = true,
            highlight = "Search",
            highlight_grey = "Comment",
          },
        }
        -- Integrate autopairs with nvim-cmp
        local cmp_autopairs = require('nvim-autopairs.completion.cmp')
        cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done())

        -- Todo comments highlighting (TODO, FIXME, HACK, NOTE, etc.)
        require('todo-comments').setup {
          signs = true,
          sign_priority = 8,
          keywords = {
            FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
            TODO = { icon = " ", color = "info" },
            HACK = { icon = " ", color = "warning" },
            WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
            PERF = { icon = " ", color = "default", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
            NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
            TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
          },
          highlight = {
            multiline = true,
            multiline_pattern = "^.",
            multiline_context = 10,
            before = "",
            keyword = "wide",
            after = "fg",
            pattern = [[.*<(KEYWORDS)\s*:]],
            comments_only = true,
          },
        }

        -- Toggleterm for integrated terminal (VSCode-style)
        require('toggleterm').setup {
          size = function(term)
            if term.direction == "horizontal" then
              return 15
            elseif term.direction == "vertical" then
              return vim.o.columns * 0.4
            end
          end,
          open_mapping = [[<C-`>]],  -- Ctrl+` to toggle (like VSCode)
          hide_numbers = true,
          shade_terminals = true,
          shading_factor = 2,
          start_in_insert = true,
          insert_mappings = true,
          terminal_mappings = true,
          persist_size = true,
          persist_mode = true,
          direction = "horizontal",
          close_on_exit = true,
          shell = vim.o.shell,
          float_opts = {
            border = "curved",
            winblend = 3,
          },
        }
        -- Terminal mode escape to normal mode
        vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], { noremap = true })
        -- Ctrl+Shift+` for floating terminal
        vim.keymap.set({'n', 'i', 'v', 't'}, '<C-S-`>', '<cmd>ToggleTerm direction=float<cr>', { noremap = true, silent = true })

        -- Copilot AI assistance
        require('copilot').setup {
          panel = {
            enabled = true,
            auto_refresh = true,
            keymap = {
              jump_prev = "[[",
              jump_next = "]]",
              accept = "<CR>",
              refresh = "gr",
              open = "<M-CR>",  -- Alt+Enter to open panel
            },
            layout = {
              position = "right",
              ratio = 0.4,
            },
          },
          suggestion = {
            enabled = true,
            auto_trigger = true,
            hide_during_completion = true,
            debounce = 75,
            keymap = {
              accept = "<M-l>",       -- Alt+l to accept suggestion
              accept_word = "<M-j>",  -- Alt+j to accept word
              accept_line = "<M-k>",  -- Alt+k to accept line
              next = "<M-]>",         -- Alt+] for next suggestion
              prev = "<M-[>",         -- Alt+[ for previous suggestion
              dismiss = "<C-]>",      -- Ctrl+] to dismiss
            },
          },
          filetypes = {
            yaml = false,
            markdown = true,
            help = false,
            gitcommit = true,
            gitrebase = false,
            ["."] = false,
          },
          copilot_node_command = "node",
        }
        -- Setup copilot-cmp for completion integration
        require('copilot_cmp').setup {}

        -- LSP keybindings (CUA/VSCode-style)
        vim.api.nvim_create_autocmd('LspAttach', {
          callback = function(args)
            local buffer = args.buf
            local opts = { buffer = buffer, noremap = true, silent = true }
            -- VSCode-style keybindings
            vim.keymap.set({'n', 'i'}, '<F12>', vim.lsp.buf.definition, opts)           -- Go to definition
            vim.keymap.set({'n', 'i'}, '<S-F12>', vim.lsp.buf.references, opts)         -- Find references
            vim.keymap.set({'n', 'i'}, '<F2>', vim.lsp.buf.rename, opts)                -- Rename symbol
            vim.keymap.set({'n', 'i'}, '<C-k><C-i>', vim.lsp.buf.hover, opts)           -- Hover info
            vim.keymap.set({'n', 'i'}, '<C-.>', vim.lsp.buf.code_action, opts)          -- Code actions
            vim.keymap.set({'n', 'i'}, '<C-S-o>', '<cmd>Telescope lsp_document_symbols<cr>', opts)  -- Document symbols
          end,
        })

        -- Keybindings for plugins (CUA-friendly, work in all modes)
        local opts = { noremap = true, silent = true }
        -- Ctrl+P for file finder (all modes)
        vim.keymap.set({'n', 'i', 'v'}, '<C-p>', '<cmd>Telescope find_files<cr>', opts)
        -- Ctrl+B to toggle file tree (all modes)
        vim.keymap.set({'n', 'i', 'v'}, '<C-b>', '<cmd>NvimTreeToggle<cr>', opts)
        -- Ctrl+E to focus file tree (all modes)
        vim.keymap.set({'n', 'i', 'v'}, '<C-e>', '<cmd>NvimTreeFocus<cr>', opts)
        -- Tab switching (Ctrl+Tab / Ctrl+Shift+Tab)
        vim.keymap.set({'n', 'i', 'v'}, '<C-Tab>', '<cmd>BufferLineCycleNext<cr>', opts)
        vim.keymap.set({'n', 'i', 'v'}, '<C-S-Tab>', '<cmd>BufferLineCyclePrev<cr>', opts)
        -- Ctrl+W to close current buffer (using bufdelete for clean closure)
        vim.keymap.set({'n', 'i', 'v'}, '<C-w>', '<cmd>Bdelete<cr>', opts)
        -- Ctrl+Shift+S for "Save As" via Telescope
        vim.keymap.set({'n', 'i', 'v'}, '<C-S-s>', function()
          vim.ui.input({ prompt = "Save as: ", default = vim.fn.expand("%:p") }, function(input)
            if input and input ~= "" then
              vim.cmd("saveas " .. vim.fn.fnameescape(input))
            end
          end)
        end, opts)
        -- Ctrl+Shift+F for grep/search in files
        vim.keymap.set({'n', 'i', 'v'}, '<C-S-f>', '<cmd>Telescope live_grep<cr>', opts)
        -- Todo comments navigation
        vim.keymap.set({'n', 'i', 'v'}, '<C-S-t>', '<cmd>TodoTelescope<cr>', opts)  -- Search TODOs
        -- Trouble diagnostics panel
        vim.keymap.set({'n', 'i', 'v'}, '<C-S-m>', '<cmd>Trouble diagnostics toggle<cr>', opts)  -- Problems panel
        -- Git integration keybindings (VSCode-style)
        vim.keymap.set({'n', 'i', 'v'}, '<C-S-g>', '<cmd>Telescope git_status<cr>', opts)  -- Git status
      '';
    };
  };

  xdg = lib.mkIf isLinux {
    desktopEntries = {
      nvim = {
        name = "Neovim";
        noDisplay = true;
      };
    };
  };
}
