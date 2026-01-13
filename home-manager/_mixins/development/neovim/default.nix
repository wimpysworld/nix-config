{
  catppuccinPalette,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;

  # Sops file for AI API keys (Anthropic, OpenAI, Gemini)
  aiSopsFile = ../../../../secrets/ai.yaml;

  # Generate CodeCompanion rules config from agent files
  assistantsDir = ../assistants;
  allAssistantFiles = builtins.readDir assistantsDir;
  agentFiles = lib.filterAttrs (
    name: type: type == "regular" && lib.hasSuffix ".agent.md" name
  ) allAssistantFiles;

  codecompanionHelpers = import "${assistantsDir}/codecompanion.nix" { inherit lib; };
  rulesConfigLua = codecompanionHelpers.mkRulesConfig {
    inherit agentFiles;
    configDir = config.xdg.configHome + "/nvim";
  };

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

  # Fetch nvzone/volt (dependency for nvzone/menu)
  nvzone-volt = pkgs.vimUtils.buildVimPlugin {
    pname = "volt";
    version = "unstable-2025-01-11";
    src = pkgs.fetchFromGitHub {
      owner = "nvzone";
      repo = "volt";
      rev = "620de1321f275ec9d80028c68d1b88b409c0c8b1";
      sha256 = "sha256-5Xao1+QXZOvqwCXL6zWpckJPO1LDb8I7wtikMRFQ3Jk=";
    };
    meta = {
      homepage = "https://github.com/nvzone/volt";
      description = "Volt is a reactive UI library for Neovim";
      license = lib.licenses.gpl3Only;
    };
  };

  # Fetch nvzone/menu for context menus
  nvzone-menu = pkgs.vimUtils.buildVimPlugin {
    pname = "menu";
    version = "unstable-2025-01-11";
    src = pkgs.fetchFromGitHub {
      owner = "nvzone";
      repo = "menu";
      rev = "7a0a4a2896b715c066cfbe320bdc048091874cc6";
      sha256 = "sha256-4GfQ6Mo32rsoQAXKZF9Bpnm/sms2hfbrTldpLp5ySoY=";
    };
    # Skip require check - plugin has runtime dependencies (volt, neo-tree, nvim-tree)
    nvimSkipModule = [
      "menu"
      "menus.neo-tree"
      "menus.nvimtree"
    ];
    meta = {
      homepage = "https://github.com/nvzone/menu";
      description = "Menu plugin for Neovim with nested menu support";
      license = lib.licenses.gpl3Only;
    };
  };

  # Fetch codecompanion.nvim from upstream (nixpkgs version lags behind significantly)
  # v18.x introduced breaking changes: strategies→interactions, adapters→adapters.http
  codecompanion-nvim = pkgs.vimUtils.buildVimPlugin {
    pname = "codecompanion.nvim";
    version = "18.4.0";
    src = pkgs.fetchFromGitHub {
      owner = "olimorris";
      repo = "codecompanion.nvim";
      rev = "v18.4.0";
      sha256 = "sha256-DHU/eaZmNQ+rr05+OiZR6s5aEHXjyEd6SJzUYybnVr4=";
    };
    # Skip require check - plugin has many optional runtime dependencies
    # (plenary, telescope, fzf-lua, mini.pick, snacks, blink.cmp, nvim-cmp, etc.)
    doCheck = false;
    meta = {
      homepage = "https://github.com/olimorris/codecompanion.nvim";
      description = "AI-powered coding companion for Neovim";
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
        vim-sleuth # Auto-detect indentation
        vim-lastplace # Restore cursor position
        trim-nvim # Auto-trim trailing whitespace on save
        # Visual enhancements
        nvim-web-devicons
        lualine-nvim
        indent-blankline-nvim
        rainbow-delimiters-nvim
        hlchunk-nvim
        virt-column-nvim
        vim-illuminate
        nvim-scrollview
        # Context menus (right-click menus)
        nvzone-volt # Required by nvzone-menu
        nvzone-menu
        # File management
        neo-tree-nvim
        nui-nvim # Required by neo-tree
        nvim-lsp-file-operations # LSP-aware file renames (updates imports)
        telescope-nvim
        telescope-fzf-native-nvim
        telescope-ui-select-nvim
        plenary-nvim

        # Git integration
        gitsigns-nvim
        # Direnv integration
        direnv-vim
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
        # Formatting
        conform-nvim
        # Diagnostics
        trouble-nvim
        # Quality of life: auto-pairs, todo highlighting, terminal, sessions
        nvim-autopairs
        todo-comments-nvim
        toggleterm-nvim
        auto-session
        # AI assistance: CodeCompanion for multi-provider LLM integration
        # Provides chat, inline transforms, and agentic tools
        codecompanion-nvim
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
        " Don't auto-sync with system clipboard (CUA: only Ctrl+C/X should copy/cut)
        " novim-mode handles explicit clipboard operations
        set clipboard=
        set undofile
        set splitright
        set splitbelow

        " Session options (required for auto-session)
        set sessionoptions=blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions

        " Indentation
        set tabstop=2
        set shiftwidth=2
        set expandtab
        set smartindent


      '';
      extraLuaConfig = lib.mkBefore ''
        -- =============================================================================
        -- MODELESS EDITING CONFIGURATION
        -- =============================================================================
        -- This configuration provides a VSCode/CUA-like editing experience using the
        -- novim-mode plugin. The goal is to make Neovim behave like a "normal" editor:
        --
        -- PHILOSOPHY:
        --   - No modal editing: users type text immediately without mode switching
        --   - Selection via Shift+Arrow keys (like VSCode, Word, etc.)
        --   - Standard CUA keybindings: Ctrl+C/X/V for copy/cut/paste, Ctrl+S to save
        --   - Additional classic keybindings: Shift+Del (cut), Shift+Ins (paste)
        --   - All custom keybindings work across modes {'n', 'i', 'v', 's'} to maintain
        --     consistent behaviour regardless of Neovim's internal state
        --
        -- KEY MAPPINGS (provided by novim-mode):
        --   Ctrl+S: Save | Ctrl+Z: Undo | Ctrl+Y: Redo | Ctrl+A: Select all
        --   Ctrl+C: Copy | Ctrl+X: Cut | Ctrl+V: Paste | Ctrl+F: Find
        --   Shift+Arrow: Select text | Ctrl+Arrow: Move by word
        --   Tab: Indent selection | Shift+Tab: Unindent selection
        --
        -- ADDITIONAL MAPPINGS (defined below):
        --   Ctrl+Ins: Paste | Ctrl+Del: Cut selection | Alt+S: Save As
        --   Ctrl+P: Find files | Ctrl+Shift+F: Search in files
        --   Ctrl+B: Toggle file tree | Ctrl+W: Close buffer
        --   Ctrl+`: Terminal | F12: Go to definition | F2: Rename
        --
        -- NOTE: Some Ctrl+Shift combinations don't work reliably in terminals
        -- (terminals can't distinguish Ctrl+S from Ctrl+Shift+S). Alt-based
        -- alternatives are used where necessary.
        --
        -- AI ASSISTANCE: CodeCompanion configured below
        --   Ctrl+Alt+I: Toggle chat panel | Ctrl+I: Inline chat prompt
        --   Alt+A: Actions picker | Alt+M: Model/adapter selector
        --   Alt+/: Quick transform (visual) | Alt+E: Explain (visual)
        --   Alt+X: Fix code (visual) | Alt+T: Generate tests (visual)
        --   Alt+D: Generate docs (visual)
        --   In chat buffer: Enter sends, Shift/Ctrl+Enter for newline
        --
        -- COMPLETION MENU (nvim-cmp):
        --   Tab: Accept selected | Up/Down: Navigate | Escape: Close
        -- =============================================================================

        -- Global LSP configuration (Neovim 0.11+ native API)
        -- Set default capabilities for all LSP servers (nvim-cmp integration)
        vim.lsp.config('*', {
          capabilities = require('cmp_nvim_lsp').default_capabilities(),
          root_markers = { '.git' },
        })

        -- Lualine statusbar with keybinding hints and AI status
        -- CodeCompanion status tracking (updated via autocmds below)
        _G.codecompanion_status = ""

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
              -- CodeCompanion AI status indicator
              {
                function() return _G.codecompanion_status end,
                cond = function() return _G.codecompanion_status ~= "" end,
                color = { fg = "${catppuccinPalette.getColor "mauve"}" },
              },
              -- Keybinding hints
              { function() return "C-M-i:Chat M-m:Model M-a:Actions" end },
            },
            lualine_y = {'encoding', 'fileformat', 'filetype'},
            lualine_z = {'location'}
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

        -- Rainbow delimiters (colourful bracket matching)
        local rainbow_delimiters = require('rainbow-delimiters')
        local rainbow_highlight = {
          'RainbowDelimiterRed',
          'RainbowDelimiterYellow',
          'RainbowDelimiterBlue',
          'RainbowDelimiterOrange',
          'RainbowDelimiterGreen',
          'RainbowDelimiterViolet',
          'RainbowDelimiterCyan',
        }
        require('rainbow-delimiters.setup').setup {
          strategy = {
            [""] = rainbow_delimiters.strategy['global'],
          },
          query = {
            [""] = 'rainbow-delimiters',
          },
          highlight = rainbow_highlight,
        }

        -- Indent guides with rainbow scope lines
        require('ibl').setup {
          indent = { char = "│" },
          scope = {
            enabled = true,
            highlight = rainbow_highlight,  -- Use rainbow colours for scope line
          },
        }
        -- Hook indent-blankline to rainbow-delimiters for matching colours
        local hooks = require('ibl.hooks')
        hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)

        -- Hlchunk: draw lines connecting bracket pairs
        -- Uses Vim's searchpair (not treesitter) for consistent { } matching
        require('hlchunk').setup {
          chunk = {
            enable = true,
            use_treesitter = false,       -- Use searchpair for all { } brackets
            style = {
              { fg = "${catppuccinPalette.getColor "mauve"}" },
              { fg = "${catppuccinPalette.getColor "red"}" },   -- Error colour
            },
            chars = {
              horizontal_line = "─",
              vertical_line = "│",
              left_top = "╭",
              left_bottom = "╰",
              right_arrow = ">",
            },
            textobject = "",              -- Disable textobject (we use treesitter's)
            max_file_size = 1024 * 1024,  -- 1MB
            error_sign = true,            -- Show different colour for syntax errors
            duration = 200,               -- Animation duration (ms)
            delay = 300,                  -- Delay before showing (ms)
          },
          indent = {
            enable = false,  -- Disabled: using indent-blankline instead
          },
          line_num = {
            enable = false,  -- Disabled: gitsigns handles line number colouring
          },
          blank = {
            enable = false,
          },
        }

        -- Virtual column markers at 80 and 88 characters (thin lines, not highlighted columns)
        require('virt-column').setup {
          char = '┊',           -- Dotted line for subtlety
          virtcolumn = '80,88',
          highlight = 'NonText', -- Use faint NonText highlight (very subtle)
        }

        -- Scrollbar with signs (diagnostics, search, marks, git)
        -- Clickable for navigation, right-click for info
        require('scrollview').setup {
          excluded_filetypes = { 'neo-tree', 'toggleterm' },
          current_only = true,           -- Only show scrollbar in current window
          winblend = 50,                 -- Transparency (0-100)
          signs_on_startup = {           -- Enable these sign groups
            'diagnostics',
            'search',
            'marks',
            'keywords',                  -- TODO, FIXME, HACK, etc.
          },
          diagnostics_severities = {     -- Show all diagnostic levels
            vim.diagnostic.severity.ERROR,
            vim.diagnostic.severity.WARN,
            vim.diagnostic.severity.INFO,
            vim.diagnostic.severity.HINT,
          },
        }

        -- Illuminate: highlight other occurrences of word under cursor
        require('illuminate').configure {
          delay = 200,           -- Delay before highlighting (ms)
          under_cursor = true,   -- Highlight word under cursor
          providers = {
            'lsp',               -- Use LSP for smart highlighting
            'treesitter',        -- Fall back to treesitter
            'regex',             -- Fall back to regex
          },
          filetypes_denylist = { -- Don't illuminate in these filetypes
            'neo-tree',
            'TelescopePrompt',
            'toggleterm',
          },
        }

        -- File tree (neo-tree: more features, better session handling)
        require('neo-tree').setup {
          close_if_last_window = true,     -- Close neo-tree if it's the last window
          popup_border_style = "rounded",
          enable_git_status = true,
          enable_diagnostics = true,
          sort_case_insensitive = true,
          default_component_configs = {
            container = {
              enable_character_fade = true,
            },
            indent = {
              indent_size = 2,
              padding = 1, -- extra padding on left hand side
              -- indent guides
              with_markers = true,
              indent_marker = "│",
              last_indent_marker = "└",
              highlight = "NeoTreeIndentMarker",
              -- expander config, needed for nesting files
              with_expanders = nil, -- if nil and file nesting is enabled, will enable expanders
              expander_collapsed = "",
              expander_expanded = "",
              expander_highlight = "NeoTreeExpander",
            },
            icon = {
              folder_closed = "",
              folder_open = "",
              folder_empty = "󰜌",
              provider = function(icon, node, state) -- default icon provider utilizes nvim-web-devicons if available
                if node.type == "file" or node.type == "terminal" then
                  local success, web_devicons = pcall(require, "nvim-web-devicons")
                  local name = node.type == "terminal" and "terminal" or node.name
                  if success then
                    local devicon, hl = web_devicons.get_icon(name)
                    icon.text = devicon or icon.text
                    icon.highlight = hl or icon.highlight
                  end
                end
              end,
              -- The next two settings are only a fallback, if you use nvim-web-devicons and configure default icons there
              -- then these will never be used.
              default = "*",
              highlight = "NeoTreeFileIcon",
              use_filtered_colors = true, -- Whether to use a different highlight when the file is filtered (hidden, dotfile, etc.).
            },
            modified = {
              symbol = "[+]",
              highlight = "NeoTreeModified",
            },
            name = {
              trailing_slash = false,
              use_filtered_colors = true, -- Whether to use a different highlight when the file is filtered (hidden, dotfile, etc.).
              use_git_status_colors = true,
              highlight = "NeoTreeFileName",
            },
            git_status = {
              symbols = {
                -- Change type
                added = "", -- or "✚"
                modified = "", -- or ""
                deleted = "✖", -- this can only be used in the git_status source
                renamed = "󰁕", -- this can only be used in the git_status source
                -- Status type
                untracked = "",
                ignored = "",
                unstaged = "󰄱",
                staged = "",
                conflict = "",
              },
            },
          },
          window = {
            position = "left",
            width = 30,
            mappings = {
              -- CUA-friendly mappings (avoid single-letter vim bindings)
              ["<CR>"] = "open",
              ["<2-LeftMouse>"] = "open",
              ["<F2>"] = "rename",
              ["<Del>"] = "delete",
              ["<F5>"] = "refresh",
              -- Keep some useful defaults
              ["a"] = "add",               -- Add file/directory
              ["d"] = "delete",
              ["r"] = "rename",
              ["y"] = "copy_to_clipboard",
              ["x"] = "cut_to_clipboard",
              ["p"] = "paste_from_clipboard",
              ["c"] = "copy",              -- Copy to location
              ["m"] = "move",              -- Move to location
              ["q"] = "close_window",
              ["R"] = "refresh",
              ["?"] = "show_help",
              ["<"] = "prev_source",
              [">"] = "next_source",
              ["/"] = "fuzzy_finder",      -- Built-in fuzzy finder
              ["H"] = "toggle_hidden",
              ["o"] = "open",
              ["s"] = "open_vsplit",
              ["S"] = "open_split",
              ["t"] = "open_tabnew",
            },
          },
          filesystem = {
            filtered_items = {
              visible = false,             -- Hide hidden files by default
              hide_dotfiles = false,       -- But don't hide dotfiles
              hide_gitignored = true,      -- Hide gitignored files
              hide_by_name = {
                ".git",
                "node_modules",
                "__pycache__",
              },
            },
            follow_current_file = {
              enabled = true,              -- Auto-reveal current file
              leave_dirs_open = true,      -- Keep parent dirs open
            },
            use_libuv_file_watcher = true, -- Auto-refresh on file changes
          },
          buffers = {
            follow_current_file = {
              enabled = true,
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
                filetype = "neo-tree",
                text = "",
                separator = true,
              },
            },
          },
        }
        -- Open tree on startup, then focus editor
        vim.api.nvim_create_autocmd("VimEnter", {
          callback = function()
            vim.cmd('Neotree show')
            -- Move focus to the editor window (away from tree)
            vim.cmd('wincmd l')
          end
        })

        -- Keep neo-tree and menu in normal mode (prevent novim-mode from switching to insert)
        -- This ensures these UI elements remain navigable without mode interference
        vim.api.nvim_create_autocmd("FileType", {
          pattern = { "neo-tree", "neo-tree-popup", "NvMenu", "VoltWindow" },
          callback = function()
            vim.b.novim_mode_disable = true  -- Disable novim-mode for this buffer
            vim.cmd('stopinsert')            -- Ensure we're in normal mode
          end,
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

        -- LSP file operations (updates imports when renaming files in neo-tree)
        require('lsp-file-operations').setup {}

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
        local lspkind = require('lspkind')

        cmp.setup {
          mapping = cmp.mapping.preset.insert({
            ['<C-Space>'] = cmp.mapping.complete(),
            ['<CR>'] = cmp.mapping.confirm({ select = true }),
            -- Tab: accept completion if visible, otherwise insert tab/spaces
            -- Only in insert mode - select mode Tab is used for indenting selections
            ['<Tab>'] = cmp.mapping(function(_)
              if cmp.visible() then
                cmp.confirm({ select = true })  -- Accept selected completion
              else
                -- Insert appropriate indentation (respects expandtab, shiftwidth, etc.)
                local key = vim.api.nvim_replace_termcodes('<Tab>', true, true, true)
                vim.api.nvim_feedkeys(key, 'n', false)
              end
            end, { 'i' }),
            ['<S-Tab>'] = cmp.mapping(function(fallback)
              if cmp.visible() then
                cmp.select_prev_item()
              else
                fallback()
              end
            end, { 'i', 's' }),
            ['<Down>'] = cmp.mapping.select_next_item(),
            ['<Up>'] = cmp.mapping.select_prev_item(),
            ['<C-b>'] = cmp.mapping.scroll_docs(-4),
            ['<C-f>'] = cmp.mapping.scroll_docs(4),
            -- Escape closes completion menu, falls through to novim-mode otherwise
            ['<Esc>'] = cmp.mapping(function(fallback)
              if cmp.visible() then
                cmp.abort()
              else
                fallback()
              end
            end, { 'i' }),
          }),
          sources = cmp.config.sources({
            { name = 'nvim_lsp' },
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

        -- Auto-trim trailing whitespace on save
        require('trim').setup {
          ft_blocklist = { 'markdown', 'diff', 'gitcommit' },
          trim_on_write = true,
          trim_trailing = true,
          trim_last_line = true,       -- Remove blank lines at end of file
          trim_first_line = true,      -- Remove blank lines at start of file
          highlight = false,           -- Don't highlight (scrollview already shows this)
          notifications = false,       -- Silent operation
        }

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

        -- Auto-session: automatically save and restore sessions per directory
        require('auto-session').setup {
          enabled = true,                -- Enable auto-session
          auto_restore = true,           -- Restore session when opening Neovim in a directory
          auto_save = true,              -- Save session when leaving Neovim
          auto_create = true,            -- Create session if none exists
          suppressed_dirs = {            -- Don't create sessions in these directories
            '~/',
            '~/Downloads',
            '~/tmp',
            '/tmp',
          },
          -- Close neo-tree before saving session (it doesn't restore well)
          pre_save_cmds = { 'Neotree close' },
          -- Reopen neo-tree after restoring session
          post_restore_cmds = {
            function()
              vim.cmd('Neotree show')
              vim.cmd('wincmd l')
            end,
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
        -- Terminal mode: automatically enter terminal mode when opening/focusing
        -- This provides a modeless experience - just start typing commands
        vim.api.nvim_create_autocmd({'TermOpen', 'BufEnter', 'BufWinEnter'}, {
          pattern = 'term://*',
          callback = function()
            vim.fn.timer_start(50, function()
              if vim.bo.buftype == 'terminal' then
                vim.cmd('startinsert')
              end
            end)
          end,
        })
        -- Ctrl+Shift+` for floating terminal
        vim.keymap.set({'n', 'i', 'v', 't'}, '<C-S-`>', '<cmd>ToggleTerm direction=float<cr>', { noremap = true, silent = true })

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
        vim.keymap.set({'n', 'i', 'v'}, '<C-b>', '<cmd>Neotree toggle<cr>', opts)
        -- Ctrl+E to focus file tree (all modes)
        vim.keymap.set({'n', 'i', 'v'}, '<C-e>', '<cmd>Neotree focus<cr>', opts)
        -- Tab switching (Ctrl+Tab / Ctrl+Shift+Tab)
        vim.keymap.set({'n', 'i', 'v'}, '<C-Tab>', '<cmd>BufferLineCycleNext<cr>', opts)
        vim.keymap.set({'n', 'i', 'v'}, '<C-S-Tab>', '<cmd>BufferLineCyclePrev<cr>', opts)
        -- Ctrl+W to close current buffer (using bufdelete for clean closure)
        vim.keymap.set({'n', 'i', 'v'}, '<C-w>', '<cmd>Bdelete<cr>', opts)
        -- Alt+S for "Save As" (Ctrl+Shift+S doesn't work reliably in terminals)
        vim.keymap.set({'n', 'i', 'v', 's'}, '<M-s>', function()
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
         -- Command palette (VSCode-style Ctrl+Shift+P)
         vim.keymap.set('n', '<C-S-p>', '<cmd>Telescope commands<cr>', opts)
         vim.keymap.set('i', '<C-S-p>', '<cmd>Telescope commands<cr>', opts)
         vim.keymap.set('v', '<C-S-p>', '<cmd>Telescope commands<cr>', opts)

        -- Additional CUA keybindings (classic Windows/IBM style)
        -- Tab/Shift+Tab to indent/dedent selection (VSCode-style)
        -- novim-mode uses select mode where Tab is broken in Neovim, so we convert to visual mode first
        vim.keymap.set('s', '<Tab>', '<C-G>>gv', opts)      -- Select -> Visual -> indent -> reselect
        vim.keymap.set('s', '<S-Tab>', '<C-G><gv', opts)    -- Select -> Visual -> dedent -> reselect
        vim.keymap.set('v', '<Tab>', '>gv', opts)           -- Visual mode indent
        vim.keymap.set('v', '<S-Tab>', '<gv', opts)         -- Visual mode dedent
        -- Shift+Enter behaves like Enter (consistent editing experience)
        vim.keymap.set({'n', 'i', 'v', 's'}, '<S-CR>', '<CR>', opts)
        -- Shift+Del to cut selection to system clipboard (like Ctrl+X)
        -- Uses same approach as novim-mode: <C-O>"+xi
        vim.keymap.set('s', '<S-Del>', '<C-O>"+xi', opts)
        vim.keymap.set('v', '<S-Del>', '"+xi', opts)
        -- Shift+Ins to paste from system clipboard (like Ctrl+V)
        -- Call the same novim_mode#Paste() function that Ctrl+V uses
        vim.keymap.set({'n', 'i', 'v', 's'}, '<S-Ins>', '<C-O>:call novim_mode#Paste()<CR>', opts)

        -- Context menu (nvzone/menu) - CUA-friendly right-click menus

        -- Neo-tree file explorer menu (CUA-friendly keybinds)
        local neotree_manager = require "neo-tree.sources.manager"
        local neotree_cc = require "neo-tree.sources.common.commands"

        local function get_neotree_state()
          local state = neotree_manager.get_state_for_window()
          assert(state)
          state.config = state.config or {}
          return state
        end

        local function neotree_call(what)
          return vim.schedule_wrap(function()
            local state = get_neotree_state()
            local cb = require("neo-tree.sources." .. state.name .. ".commands")[what] or neotree_cc[what]
            cb(state)
          end)
        end

        local function neotree_copy_path(how)
          return function()
            local node = get_neotree_state().tree:get_node()
            if node.type == "message" then return end
            vim.fn.setreg('"', vim.fn.fnamemodify(node.path, how))
            vim.fn.setreg("+", vim.fn.fnamemodify(node.path, how))
          end
        end

        local function neotree_open_in_terminal()
          return function()
            local node = get_neotree_state().tree:get_node()
            if node.type == "message" then return end
            local path = node.path
            local node_type = vim.uv.fs_stat(path).type
            local dir = node_type == "directory" and path or vim.fn.fnamemodify(path, ":h")
            vim.cmd("ToggleTerm dir=" .. vim.fn.fnameescape(dir))
          end
        end

        local neotree_menu = {
          { name = "  New File", cmd = neotree_call "add", rtxt = "Ctrl+N" },
          { name = "  New Folder", cmd = neotree_call "add_directory", rtxt = "Ctrl+Shift+N" },
          { name = "separator" },
          { name = "  Open", cmd = neotree_call "open", rtxt = "Enter" },
          { name = "  Open in Split", cmd = neotree_call "open_split" },
          { name = "  Open in Vertical Split", cmd = neotree_call "open_vsplit" },
          { name = "󰓪  Open in New Tab", cmd = neotree_call "open_tabnew" },
          { name = "separator" },
          { name = "  Cut", cmd = neotree_call "cut_to_clipboard", rtxt = "Ctrl+X" },
          { name = "  Copy", cmd = neotree_call "copy_to_clipboard", rtxt = "Ctrl+C" },
          { name = "  Paste", cmd = neotree_call "paste_from_clipboard", rtxt = "Ctrl+V" },
          { name = "separator" },
          { name = "󰴠  Copy Path", cmd = neotree_copy_path ":p", rtxt = "Ctrl+Shift+C" },
          { name = "  Copy Relative Path", cmd = neotree_copy_path ":~:." },
          { name = "separator" },
          { name = "  Rename", cmd = neotree_call "rename", rtxt = "F2" },
          { name = "  Delete", hl = "ExRed", cmd = neotree_call "delete", rtxt = "Del" },
          { name = "separator" },
          { name = "  Open in Terminal", hl = "ExBlue", cmd = neotree_open_in_terminal() },
          { name = "   File Details", cmd = neotree_call "show_file_details" },
          { name = "separator" },
          { name = "  Refresh", cmd = neotree_call "refresh", rtxt = "F5" },
          { name = "  Toggle Hidden Files", cmd = neotree_call "toggle_hidden", rtxt = "Ctrl+H" },
        }

        -- Define custom menu items for modeless editing workflow
        local cua_menu = {
          { name = "Cut", cmd = "normal! \"+x", rtxt = "Ctrl+X" },
          { name = "Copy", cmd = "normal! \"+y", rtxt = "Ctrl+C" },
          { name = "Paste", cmd = "call novim_mode#Paste()", rtxt = "Ctrl+V" },
          { name = "separator" },
          { name = "Select All", cmd = "normal! ggVG", rtxt = "Ctrl+A" },
          { name = "separator" },
          { name = "  Find", hl = "ExBlue", items = {
            { name = "Find in Files", cmd = "Telescope live_grep", rtxt = "Ctrl+Shift+F" },
            { name = "Find Files", cmd = "Telescope find_files", rtxt = "Ctrl+P" },
            { name = "Find TODOs", cmd = "TodoTelescope", rtxt = "Ctrl+Shift+T" },
            { name = "Find Symbols", cmd = "Telescope lsp_document_symbols", rtxt = "Ctrl+Shift+O" },
          }},
          { name = "separator" },
          { name = "  LSP", hl = "ExBlue", items = {
            { name = "Go to Definition", cmd = function() vim.lsp.buf.definition() end, rtxt = "F12" },
            { name = "Find References", cmd = function() vim.lsp.buf.references() end, rtxt = "Shift+F12" },
            { name = "Rename Symbol", cmd = function() vim.lsp.buf.rename() end, rtxt = "F2" },
            { name = "Code Actions", cmd = function() vim.lsp.buf.code_action() end, rtxt = "Ctrl+." },
            { name = "Hover Info", cmd = function() vim.lsp.buf.hover() end, rtxt = "Ctrl+K Ctrl+I" },
            { name = "separator" },
            { name = "Format Document", cmd = function()
              local ok, conform = pcall(require, "conform")
              if ok then conform.format({ lsp_fallback = true }) else vim.lsp.buf.format() end
            end },
          }},
          { name = "separator" },
          { name = "  Git", hl = "ExGreen", items = {
            { name = "Git Status", cmd = "Telescope git_status", rtxt = "Ctrl+Shift+G" },
            { name = "Stage Hunk", cmd = function() require('gitsigns').stage_hunk() end },
            { name = "Reset Hunk", cmd = function() require('gitsigns').reset_hunk() end },
            { name = "Preview Hunk", cmd = function() require('gitsigns').preview_hunk() end },
            { name = "Blame Line", cmd = function() require('gitsigns').blame_line({ full = true }) end },
          }},
          { name = "separator" },
          { name = "  View", hl = "ExYellow", items = {
            { name = "Toggle File Tree", cmd = "Neotree toggle", rtxt = "Ctrl+B" },
            { name = "Toggle Terminal", cmd = "ToggleTerm", rtxt = "Ctrl+`" },
            { name = "Problems Panel", cmd = "Trouble diagnostics toggle", rtxt = "Ctrl+Shift+M" },
            { name = "Command Palette", cmd = "Telescope commands", rtxt = "Ctrl+Shift+P" },
          }},
        }

        -- Helper function to close menu
        local function close_menu()
          local state = require('menu.state')
          if state.bufids and #state.bufids > 0 then
            for _, buf in ipairs(state.bufids) do
              if vim.api.nvim_buf_is_valid(buf) then
                local wins = vim.fn.win_findbuf(buf)
                for _, win in ipairs(wins) do
                  if vim.api.nvim_win_is_valid(win) then
                    vim.api.nvim_win_close(win, true)
                  end
                end
                vim.api.nvim_buf_delete(buf, { force = true })
              end
            end
            state.bufids = {}
            state.bufs = {}
            state.config = nil
            state.nested_menu = ""
            -- Return to original window
            if state.old_data and vim.api.nvim_win_is_valid(state.old_data.win) then
              vim.api.nvim_set_current_win(state.old_data.win)
            end
            return true
          end
          return false
        end

        -- Right-click to open context menu (mouse users)
        vim.keymap.set({ 'n', 'v' }, '<RightMouse>', function()
          -- Delete old menus to prevent stacking
          require('menu.utils').delete_old_menus()
          -- Position cursor at mouse location
          vim.cmd.exec '"normal! \\<RightMouse>"'
          -- Determine which menu to show based on the buffer type
          local buf = vim.api.nvim_win_get_buf(vim.fn.getmousepos().winid)
          local ft = vim.bo[buf].filetype
          local menu_items = cua_menu
          if ft == "neo-tree" then
            menu_items = neotree_menu  -- Use CUA-friendly neo-tree menu
          end
          -- Open menu at mouse position
          require('menu').open(menu_items, { mouse = true })
        end, opts)

        -- Shift+F10 to open context menu (keyboard users, like Windows)
        vim.keymap.set({ 'n', 'i', 'v' }, '<S-F10>', function()
          require('menu.utils').delete_old_menus()
          require('menu').open(cua_menu, { mouse = false })
        end, opts)

        -- Alt+F10 as alternative (some terminals don't pass Shift+F10)
        vim.keymap.set({ 'n', 'i', 'v' }, '<M-F10>', function()
          require('menu.utils').delete_old_menus()
          require('menu').open(cua_menu, { mouse = false })
        end, opts)

        -- Escape closes menu if open (works in all modes for novim-mode compatibility)
        -- Note: Telescope and other floating pickers handle their own Escape bindings
        vim.keymap.set({ 'n', 'v', 's' }, '<Esc>', function()
          if not close_menu() then
            -- No menu was open, do normal escape behaviour
            local mode = vim.fn.mode()
            if mode == 'v' or mode == 'V' or mode == '\22' then
              -- Exit visual mode
              vim.cmd('normal! ' .. vim.api.nvim_replace_termcodes('<Esc>', true, true, true))
            elseif mode == 's' or mode == 'S' or mode == '\19' then
              -- Exit select mode
              vim.cmd('normal! ' .. vim.api.nvim_replace_termcodes('<Esc>', true, true, true))
            end
          end
        end, { noremap = true, silent = true, expr = false })

        -- Insert mode Escape: close menu or let novim-mode handle it
        vim.keymap.set('i', '<Esc>', function()
          if close_menu() then
            return ""  -- Closed menu, consume keypress
          else
            -- Pass through to novim-mode
            return vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
          end
        end, { noremap = true, silent = true, expr = true })

        -- =========================================================================
        -- CODECOMPANION AI ASSISTANCE (Modeless/CUA-style)
        -- =========================================================================
        -- Multi-provider LLM integration with chat, inline transforms, and agentic
        -- tools. Configured for GitHub Copilot Pro+ (primary) with Anthropic fallback.
        --
        -- Authentication:
        --   Copilot: Uses OAuth token from ~/.config/github-copilot/apps.json
        --            (created via :Copilot auth from copilot-lua/copilot.vim)
        --   Anthropic: Set ANTHROPIC_API_KEY environment variable (optional fallback)
        --
        -- CHAT KEYBINDINGS (VSCode-style, modeless - work across all modes):
        --   Ctrl+Alt+I: Open/toggle Chat panel
        --   Ctrl+I: Inline chat - ask about selection/buffer
        --   Alt+M: Change model/adapter (works globally or in chat)
        --   Alt+A: Actions picker
        --   Enter: Send message (in chat buffer)
        --   Shift+Enter / Ctrl+Enter: Insert newline (in chat buffer)
        --   Ctrl+C: Close/cancel chat | Alt+Q: Stop generation | Ctrl+D: Show diff
        --
        -- VISUAL MODE AI (select text first):
        --   Alt+/: Quick transform | Alt+E: Explain | Alt+X: Fix
        --   Alt+T: Generate tests | Alt+D: Generate docs
        --
        -- CHAT CONTEXT (prefix in chat input):
        --   #buffer        - Current buffer content
        --   #file:<path>   - Include file content
        --   @full_stack_dev - Enable full coding agent with tools
        --   @files         - Enable file operation tools only
        --
        -- TOOLS (agentic capabilities):
        --   cmd_runner         - Execute shell commands (requires approval)
        --   insert_edit_into_file - Apply code changes to files
        --   create_file/delete_file - File management
        --   file_search/grep_search - Search codebase
        --   read_file          - Read file contents
        -- =========================================================================

        require('codecompanion').setup {
          -- Adapter configuration (LLM providers)
          adapters = {
            http = {
              -- GitHub Copilot Pro+ as primary (uses OAuth from apps.json)
              copilot = 'copilot',
              -- Anthropic Claude as fallback (requires ANTHROPIC_API_KEY env var)
              -- Uses API aliases which auto-update to latest snapshots
              anthropic = function()
                return require('codecompanion.adapters').extend('anthropic', {
                  env = {
                    api_key = 'ANTHROPIC_API_KEY',
                  },
                  schema = {
                    model = {
                      default = 'claude-sonnet-4-5',
                      choices = {
                        'claude-sonnet-4-5',
                        'claude-opus-4-5',
                        'claude-haiku-4-5',
                      },
                    },
                  },
                })
              end,
            },
          },
          opts = {
            log_level = 'WARN',  -- Set to DEBUG for troubleshooting
          },

          -- Rules configuration (agent definitions loaded as context)
          -- Agents defined as rules can be referenced by prompts via opts.rules
          rules = ${rulesConfigLua},

          -- Interactions configuration (chat, inline, cmd behaviours)
          interactions = {
            -- Chat buffer settings
            chat = {
              adapter = 'copilot',  -- Default to GitHub Copilot Pro+
              roles = {
                llm = function(adapter)
                  return 'AI (' .. adapter.formatted_name .. ')'
                end,
                user = 'Developer',
              },
               opts = {
                 completion_provider = 'cmp',  -- Use nvim-cmp for slash command completion
                 -- Decorate user prompts with tags before sending to LLM
                 -- (Similar to VS Code Copilot - helps differentiate user input from context)
                 prompt_decorator = function(message, adapter, context)
                   return string.format([[<prompt>%s</prompt>]], message)
                 end,
               },

              -- CUA-compatible keymaps for chat buffer
              -- Only override modes; callbacks are inherited from defaults
              keymaps = {
                send = {
                  modes = { n = '<CR>', i = '<CR>' },  -- Enter to send (chat-style)
                },
                close = {
                  modes = { n = '<C-c>', i = '<C-c>' },  -- Ctrl+C to close/cancel
                },
                stop = {
                  modes = { n = 'q', i = '<M-q>' },  -- q or Alt+Q to stop generation
                },
                regenerate = {
                  modes = { n = '<C-r>' },  -- Ctrl+R to regenerate
                },
                super_diff = {
                  modes = { n = '<C-d>' },  -- Ctrl+D to show super diff
                },
                change_adapter = {
                  modes = { n = '<M-m>', i = '<M-m>' },  -- Alt+M to change model/adapter
                },
                clear = {
                  modes = { n = '<C-l>' },  -- Ctrl+L to clear chat
                },
              },

               -- Slash commands with Telescope integration
               slash_commands = {
                 ['file'] = {
                   opts = { provider = 'telescope' },
                 },
                 ['buffer'] = {
                   opts = { provider = 'telescope' },
                 },
                 ['symbols'] = {
                   opts = { provider = 'telescope' },
                 },
               },

               -- Variables: context placeholders (invoked with #)
               variables = {
                 ['buffer'] = {
                   opts = {
                     -- Auto-sync buffer changes by sharing diffs on each turn
                     -- Use "all" to share entire buffer instead of just changes
                     default_params = 'diff',
                   },
                 },
               },

              -- Tool configuration for agentic workflows
              tools = {
                -- Tool groups bundle related tools together
                groups = {
                  -- Full coding agent with all capabilities
                  full_stack_dev = {
                    description = 'Full Stack Developer - Can run code, edit code and modify files',
                    prompt = 'You have access to ''${tools} to help with coding tasks',
                    tools = {
                      'cmd_runner',
                      'create_file',
                      'delete_file',
                      'file_search',
                      'get_changed_files',
                      'grep_search',
                      'insert_edit_into_file',
                      'list_code_usages',
                      'read_file',
                    },
                    opts = {
                      collapse_tools = true,  -- Collapse tool definitions in prompt
                    },
                  },
                  -- File operations only (safer subset)
                  files = {
                    description = 'File operations - reading, searching, and editing files',
                    prompt = 'You have access to ''${tools} for file operations',
                    tools = {
                      'create_file',
                      'file_search',
                      'get_changed_files',
                      'grep_search',
                      'insert_edit_into_file',
                      'read_file',
                    },
                    opts = {
                      collapse_tools = true,
                    },
                  },
                },

                 -- Individual tool configuration
                 -- cmd_runner: Always requires approval (dangerous operations)
                 cmd_runner = {
                   opts = {
                     require_approval_before = true,
                     allowed_in_yolo_mode = false,  -- Never auto-approve commands
                     auto_submit_errors = true,     -- Send errors back to LLM
                     auto_submit_success = false,   -- Manually review successful output
                   },
                 },
                 -- delete_file: Always requires approval
                 delete_file = {
                   opts = {
                     require_approval_before = true,
                     allowed_in_yolo_mode = false,
                   },
                 },
                 -- insert_edit_into_file: Show confirmation after edits
                 insert_edit_into_file = {
                   opts = {
                     require_approval_before = { buffer = false, file = false },
                     require_confirmation_after = true,
                     file_size_limit_mb = 2,
                     auto_submit_success = true,  -- Auto-continue after successful edits
                   },
                 },

                -- Global tool options
                opts = {
                  auto_submit_errors = true,   -- Auto-send errors back to LLM
                  auto_submit_success = true,  -- Auto-send success back to LLM
                  folds = { enabled = true },  -- Fold tool calls in chat
                },
              },
            },

            -- Inline assistant settings
            inline = {
              adapter = 'copilot',  -- Use Copilot for inline too
              -- CUA-style keymaps for accepting/rejecting inline changes
              keymaps = {
                accept_change = {
                  modes = { n = '<M-CR>' },  -- Alt+Enter to accept
                },
                reject_change = {
                  modes = { n = '<Esc>' },  -- Escape to reject
                },
              },
            },
          },

           -- Display configuration
           display = {
             chat = {
               -- Modeless behaviour: start in insert mode (matches novim-mode philosophy)
               start_in_insert_mode = true,
               -- Hide intro message for cleaner look
               intro_message = nil,
               -- Show token counts
               show_token_count = true,
               -- Hide settings panel (cleaner)
               show_settings = false,
               -- Auto-scroll during streaming (disabled automatically if you move cursor)
               auto_scroll = true,
               -- Don't fold context - show all information inline
               fold_context = false,
               -- Don't fold reasoning output - keep it visible
               fold_reasoning = false,
               -- Show reasoning output (extended thinking from models that support it)
               show_reasoning = true,

              -- Chat window layout
              window = {
                layout = 'vertical',    -- Side panel like VSCode
                width = 0.35,           -- 35% of screen width
                border = 'rounded',
                full_height = true,
                opts = {
                  breakindent = true,
                  cursorcolumn = false,
                  cursorline = false,
                  foldcolumn = '0',
                  linebreak = true,
                  list = false,
                  numberwidth = 1,
                  signcolumn = 'no',
                  spell = false,
                  wrap = true,
                },
              },

              -- Customise token display
              token_count = function(tokens, adapter)
                return ' (' .. tokens .. ' tokens)'
              end,
            },

            -- Action palette uses Telescope (Escape to close, better UX)
            action_palette = {
              provider = 'telescope',
              opts = {
                show_preset_prompts = false,  -- Hide built-in prompts, use custom only
              },
            },

            -- Inline diff display
            inline = {
              layout = 'vertical',  -- Side-by-side diff
            },
          },

          -- Prompt library: custom agents and commands
          -- Auto-generated from assistants/*.agent.md and *.prompt.md files
          -- Native markdown loading from ~/.config/nvim/prompts/codecompanion/
          prompt_library = {
            markdown = {
              dirs = {
                vim.fn.stdpath('config') .. '/prompts/codecompanion',
              },
            },
          },
        }

        -- =========================================================================
        -- CODECOMPANION STATUS FEEDBACK
        -- =========================================================================
        -- Updates lualine status and shows fidget notifications for AI activity.
        -- Provides visual feedback when prompts are submitted and responses stream.
        -- =========================================================================

        local cc_augroup = vim.api.nvim_create_augroup("CodeCompanionStatusHooks", { clear = true })

        -- Track active requests per chat for proper status management
        local cc_active_chats = {}

        vim.api.nvim_create_autocmd("User", {
          group = cc_augroup,
          pattern = "CodeCompanionRequestStarted",
          callback = function(event)
            local id = event.data and event.data.id
            if id then
              cc_active_chats[id] = true
            end
            _G.codecompanion_status = " Thinking..."
            require('lualine').refresh()
            -- Also notify via fidget for more visible feedback
            local ok, fidget = pcall(require, 'fidget')
            if ok then
              fidget.notify("AI request started", vim.log.levels.INFO, { annote = "CodeCompanion", key = "codecompanion" })
            end
          end,
        })

        vim.api.nvim_create_autocmd("User", {
          group = cc_augroup,
          pattern = "CodeCompanionRequestStreaming",
          callback = function(_)
            _G.codecompanion_status = " Streaming..."
            require('lualine').refresh()
          end,
        })

        vim.api.nvim_create_autocmd("User", {
          group = cc_augroup,
          pattern = { "CodeCompanionRequestFinished", "CodeCompanionChatStopped" },
          callback = function(event)
            local id = event.data and event.data.id
            if id then
              cc_active_chats[id] = nil
            end
            -- Only clear status if no active requests remain
            if vim.tbl_isempty(cc_active_chats) then
              _G.codecompanion_status = ""
              require('lualine').refresh()
              local ok, fidget = pcall(require, 'fidget')
              if ok then
                fidget.notify("AI response complete", vim.log.levels.INFO, { annote = "CodeCompanion", key = "codecompanion", ttl = 2 })
              end
            end
          end,
        })

         -- =========================================================================
         -- MODELESS CHAT WINDOW
         -- =========================================================================
         -- Force the CodeCompanion chat buffer to behave like a normal text input.
         -- Uses the same approach as novim-mode: timer-delayed startinsert and
         -- blocking Escape from leaving insert mode.
         --
         -- Chat input mappings:
         --   Enter: Submit prompt
         --   Ctrl+Enter / Shift+Enter: Insert newline
         --   Ctrl+C: Close chat
         -- =========================================================================

         -- Helper: make CodeCompanion buffer modeless
         local function make_codecompanion_modeless()
           -- Use timer to ensure buffer is fully ready
           vim.fn.timer_start(50, function()
             -- Verify we're still in a codecompanion buffer
             local ft = vim.bo.filetype
             if ft ~= 'codecompanion' then return end

             -- Disable novim-mode for this buffer (it handles its own keymaps)
             vim.b.novim_mode_disable = true
             vim.cmd('startinsert')

             -- Only set buffer-local keymaps if not already set
             if not vim.b.codecompanion_modeless_setup then
               vim.b.codecompanion_modeless_setup = true
               -- Block Escape from leaving insert mode in this buffer
               vim.api.nvim_buf_set_keymap(0, 'i', '<Esc>', '<Nop>', { noremap = true, silent = true })
               -- Ctrl+Enter and Shift+Enter insert newlines (Enter submits)
               vim.api.nvim_buf_set_keymap(0, 'i', '<C-CR>', '<CR>', { noremap = true, silent = true })
               vim.api.nvim_buf_set_keymap(0, 'i', '<S-CR>', '<CR>', { noremap = true, silent = true })
             end
           end)
         end

        -- Apply modeless behaviour when entering CodeCompanion chat buffers
        -- Multiple events to ensure insert mode persists after picker interactions
        vim.api.nvim_create_autocmd({'BufEnter', 'BufWinEnter', 'WinEnter'}, {
          callback = function()
            -- Check filetype (more reliable than pattern matching buffer name)
            if vim.bo.filetype == 'codecompanion' then
              make_codecompanion_modeless()
            end
          end,
        })

        -- Also handle FileType for initial buffer creation
        vim.api.nvim_create_autocmd('FileType', {
          pattern = 'codecompanion',
          callback = make_codecompanion_modeless,
        })

        -- CodeCompanion global keybindings (VSCode-style, modeless - work across all modes)
        local cc_opts = { noremap = true, silent = true }

        -- Ctrl+Alt+I: Open/toggle Chat panel (VSCode: Ctrl+Alt+I opens chat view)
        vim.keymap.set({'n', 'i', 'v', 's'}, '<C-M-i>', '<Cmd>CodeCompanionChat Toggle<CR>', cc_opts)

        -- Ctrl+I: Inline chat - ask about selection or current context
        -- (VSCode: Ctrl+I for inline chat in editor)
        vim.keymap.set({'n', 'i', 'v', 's'}, '<C-i>', function()
          local input = vim.fn.input('CodeCompanion: ')
          if input ~= "" then
            require('codecompanion').chat(input)
            vim.schedule(function()
              vim.cmd('startinsert')
            end)
          end
        end, { noremap = true, silent = false })

        -- Alt+A: Actions picker (prompts and quick actions menu)
        vim.keymap.set({'n', 'i', 'v', 's'}, '<M-a>', '<Cmd>CodeCompanionActions<CR>', cc_opts)

        -- Alt+M: Model/adapter selector (global binding)
        -- When in chat buffer, the chat keymap handles it directly
        -- When outside chat, opens chat first then triggers adapter picker
        vim.keymap.set({'n', 'i', 'v', 's'}, '<M-m>', function()
          local cc = require('codecompanion')
          -- Check if we're already in a codecompanion buffer
          local ft = vim.bo.filetype
          if ft == 'codecompanion' then
            -- Let the buffer-local keymap handle it (already mapped above)
            -- Feed the key to trigger the chat buffer's own Alt+M binding
            local key = vim.api.nvim_replace_termcodes('<M-m>', true, true, true)
            vim.api.nvim_feedkeys(key, 'n', false)
            return
          end
          -- Not in chat buffer - open/toggle chat then trigger adapter picker
          local chat = cc.last_chat()
          if chat and chat.ui and chat.ui:is_visible() then
            -- Chat is visible, focus it and trigger adapter change
            vim.cmd('CodeCompanionChat Focus')
            vim.defer_fn(function()
              local c = cc.last_chat()
              if c and c.change_adapter then c:change_adapter() end
            end, 50)
          elseif chat then
            -- Chat exists but hidden, toggle it open then change adapter
            cc.toggle()
            vim.defer_fn(function()
              local c = cc.last_chat()
              if c and c.change_adapter then c:change_adapter() end
            end, 150)
          else
            -- No chat exists, create one then change adapter
            cc.chat()
            vim.defer_fn(function()
              local c = cc.last_chat()
              if c and c.change_adapter then c:change_adapter() end
            end, 250)
          end
        end, cc_opts)

        -- Alt+/: Quick inline prompt (transform selection with prompt)
        vim.keymap.set({'v', 's'}, '<M-/>', function()
          local input = vim.fn.input('Transform: ')
          if input ~= "" then
            require('codecompanion').inline({ args = input })
          end
        end, { noremap = true, silent = false, desc = 'AI inline transform' })

        -- Alt+E: Explain selection (uses built-in prompt)
        vim.keymap.set({'v', 's'}, '<M-e>', '<Cmd>CodeCompanion /explain<CR>', cc_opts)

        -- Alt+X: Fix selection (uses built-in prompt)
        -- Note: Alt+F is reserved for find operations
        vim.keymap.set({'v', 's'}, '<M-x>', '<Cmd>CodeCompanion /fix<CR>', cc_opts)

        -- Alt+T: Generate tests (uses built-in prompt)
        vim.keymap.set({'v', 's'}, '<M-t>', '<Cmd>CodeCompanion /tests<CR>', cc_opts)

        -- Alt+D: Generate docstring/documentation
        vim.keymap.set({'v', 's'}, '<M-d>', function()
          require('codecompanion').inline({
            args = 'Add comprehensive documentation/docstring to this code. Follow the language conventions.',
          })
        end, cc_opts)
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

  # Export AI API keys from sops for CodeCompanion
  programs = {
    fish.shellInit = lib.mkIf config.programs.neovim.enable ''
      # Export AI API keys for CodeCompanion (Neovim)
      set -gx ANTHROPIC_API_KEY (cat ${config.sops.secrets.ANTHROPIC_API_KEY.path} 2>/dev/null; or echo "")
    '';
    bash.initExtra = lib.mkIf config.programs.neovim.enable ''
      # Export AI API keys for CodeCompanion (Neovim)
      export ANTHROPIC_API_KEY=$(cat ${config.sops.secrets.ANTHROPIC_API_KEY.path} 2>/dev/null || echo "")
    '';
  };

  sops.secrets = {
    ANTHROPIC_API_KEY = {
      sopsFile = aiSopsFile;
    };
  };
}
