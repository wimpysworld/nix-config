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
  composeHelpers = import "${assistantsDir}/compose.nix" { inherit lib; };
  rulesConfigLua = composeHelpers.mkRulesConfig {
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

  # Fetch nvim-scrollbar from upstream (not in nixpkgs)
  nvim-scrollbar = pkgs.vimUtils.buildVimPlugin {
    pname = "nvim-scrollbar";
    version = "unstable-2025-11-17";
    src = pkgs.fetchFromGitHub {
      owner = "petertriho";
      repo = "nvim-scrollbar";
      rev = "f8e87b96cd6362ef8579be456afee3b38fd7e2a8";
      sha256 = "sha256-g+gJp7noNdLKfvp+QbnTFE++PI3FcJG7reDenkg15k0=";
    };
    meta = {
      homepage = "https://github.com/petertriho/nvim-scrollbar";
      description = "Extensible Neovim Scrollbar";
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
        rainbow-delimiters-nvim
        virt-column-nvim
        nvim-scrollbar
        plenary-nvim
        # Find and replace
        searchbox-nvim # Buffer find/replace with floating UI
        # Quality-of-life enhancements
        snacks-nvim # Dashboard, input replacement, bigfile protection

        # Git integration
        gitsigns-nvim
        # Direnv integration
        direnv-vim
        # Tab bar and buffer management
        bufferline-nvim
        # LSP support
        nvim-lspconfig
        lspkind-nvim
        # Treesitter for syntax highlighting
        # Core grammars only; language-specific grammars in their ecosystem configs
        (nvim-treesitter.withPlugins (p: [
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
                --   F12: Go to definition | F2: Rename
                --
                -- TERMINAL:
                --   Ctrl+`: Toggle terminal | Ctrl+Shift+`: Floating terminal
                --
                -- GIT & GITHUB:
                --   Ctrl+G: Lazygit | Alt+Shift+G: Open in GitHub
                --   Ctrl+Shift+I: GitHub Issues | Ctrl+Shift+R: GitHub PRs
                --
                -- TROUBLE DIAGNOSTICS (VSCode-style problem navigation):
                --   Ctrl+Shift+M: Problems panel | Alt+M: Buffer problems only
                --   Alt+O: Symbols outline | Alt+Shift+T: TODOs panel
                --   F8: Next problem | Shift+F8: Previous problem
                --   Alt+Shift+F12: LSP references | Alt+Shift+Q: Quickfix list
                --   In Snacks picker: Ctrl+T sends results to Trouble
                --
                -- FIND AND REPLACE (CUA-style):
                --   Ctrl+F: Find in buffer (floating) | Ctrl+H: Find/Replace in buffer
                --   F3: Find next | Shift+F3: Find previous
                --   In visual mode: Ctrl+F/H search/replace within selection
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

                require('virt-column').setup {
                  char = '┊',           -- Dotted line for subtlety
                  virtcolumn = '80,88',
                  highlight = 'NonText', -- Use faint NonText highlight (very subtle)
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
                    -- Use Snacks.bufdelete for cleaner buffer closing (fixes offset issues)
                    close_command = function(bufnr) Snacks.bufdelete(bufnr) end,
                    right_mouse_command = function(bufnr) Snacks.bufdelete(bufnr) end,
                    offsets = {
                      {
                        filetype = "snacks_picker_list",
                        text = "📁 Explorer",
                        text_align = "left",
                        separator = true,
                      },
                    },
                  },
                }
                -- Keep certain UI elements in normal mode (disable novim-mode interference)
                -- CRITICAL: snacks_picker_list must be included otherwise novim-mode
                -- intercepts keys before Snacks explorer can process them
                vim.api.nvim_create_autocmd("FileType", {
                  pattern = {
                    "trouble",
                    "snacks_dashboard",
                    "snacks_input",
                    "snacks_picker_list",   -- Explorer and all pickers
                    "snacks_picker_input",  -- Picker input field
                    "snacks_picker_preview", -- Picker preview
                  },
                  callback = function()
                    vim.b.novim_mode_disable = true
                    -- Don't stop insert for picker input - we want to type there immediately
                    if vim.bo.filetype ~= "snacks_picker_input" then
                      vim.cmd('stopinsert')
                    end
                  end,
                })

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

                -- Conform for formatting (manual only, format-on-save disabled)
                require('conform').setup {
                  format_on_save = false,
                  -- Formatters configured per-language in ecosystem configs
                  formatters_by_ft = {},
                }

                -- Trouble for diagnostics, symbols, and unified problem views
                require('trouble').setup {
                  focus = false,
                  follow = true,
                  auto_refresh = true,
                  preview = {
                    type = "main",
                    scratch = true,
                  },
                  win = {
                    position = "bottom",
                    size = { height = 10 },
                  },
                  keys = {
                    ["?"] = "help",
                    ["<F5>"] = "refresh",
                    ["<Esc>"] = "close",
                    ["q"] = "close",
                    ["<CR>"] = "jump_close",
                    ["<2-leftmouse>"] = "jump_close",
                    ["o"] = "jump",
                    ["<Down>"] = "next",
                    ["<Up>"] = "prev",
                    ["}"] = "next",
                    ["{"] = "prev",
                    ["<Tab>"] = "fold_toggle",
                    ["<S-Tab>"] = "fold_toggle_recursive",
                    ["+"] = "fold_open",
                    ["-"] = "fold_close",
                  },
                  modes = {
                    symbols = {
                      desc = "Document Symbols",
                      mode = "lsp_document_symbols",
                      focus = false,
                      win = {
                        position = "right",
                        size = { width = 0.25 },
                      },
                    },
                    diagnostics_buffer = {
                      mode = "diagnostics",
                      filter = { buf = 0 },
                    },
                    todo = {
                      mode = "todo",
                      win = {
                        position = "bottom",
                        size = { height = 10 },
                      },
                    },
                  },
                }

                -- Searchbox for buffer find/replace (floating UI)
                require('searchbox').setup {
                  defaults = {
                    modifier = 'plain',  -- Don't escape special chars by default
                    confirm = 'native',  -- Use native confirm for replace
                    show_matches = '[{match}/{total}]',
                  },
                  popup = {
                    position = {
                      row = '5%',
                      col = '95%',
                    },
                    size = 30,
                    border = {
                      style = 'rounded',
                      text = {
                        top = ' Search ',
                        top_align = 'left',
                      },
                    },
                    win_options = {
                      winhighlight = 'Normal:Normal,FloatBorder:FloatBorder',
                    },
                  },
                  hooks = {
                    after_mount = function(input)
                      local opts = {buffer = input.bufnr}
                      -- Navigate matches with Up/Down arrows
                      vim.keymap.set('i', '<Down>', '<Plug>(searchbox-next-match)', opts)
                      vim.keymap.set('i', '<Up>', '<Plug>(searchbox-prev-match)', opts)
                    end,
                  },
                }

                -- =============================================================================
                -- SNACKS.NVIM CONFIGURATION
                -- =============================================================================
                -- Quality-of-life enhancements: dashboard, input replacement, bigfile protection
                -- Dashboard showcases CUA keybindings and integrates with auto-session
                -- =============================================================================

                require('snacks').setup {
                  -- Floating vim.ui.input replacement
                  input = {
                    enabled = true,
                    icon = " ",
                    icon_pos = "left",
                    prompt_pos = "title",
                    win = {
                      style = "input",
                      relative = "editor",
                      row = 2,
                      border = "rounded",
                    },
                  },

                  -- Large file protection (disables heavy features for files >1.5MB)
                  bigfile = {
                    enabled = true,
                    notify = true,
                    size = 1.5 * 1024 * 1024,
                  },

                  -- Faster startup when opening specific files
                  quickfile = { enabled = true },

                  -- Startup dashboard
                  dashboard = {
                    enabled = true,
                    width = 72,
                    row = nil,
                    col = nil,
                    pane_gap = 4,

                    preset = {
                      pick = function(cmd, opts)
                        opts = opts or {}
                        if cmd == "files" then
                          Snacks.picker.files(opts)
                        elseif cmd == "live_grep" then
                          Snacks.picker.grep(opts)
                        elseif cmd == "oldfiles" then
                          Snacks.picker.recent(opts)
                        end
                      end,

                      keys = {
                        { icon = "󰈞 ", key = "f", desc = "Find File", action = function() Snacks.picker.files() end },
                        { icon = " ", key = "r", desc = "Recent Files", action = function() Snacks.picker.recent() end },
                        { icon = " ", key = "g", desc = "Find Text", action = function() Snacks.picker.grep() end },
                        { icon = " ", key = "s", desc = "Restore Session", section = "session" },
                        { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
                        { icon = " ", key = "q", desc = "Quit", action = ":qa" },
                      },

                      header = [[
        ███╗   ██╗██╗██╗  ██╗██╗   ██╗██╗███╗   ███╗
        ████╗  ██║██║╚██╗██╔╝██║   ██║██║████╗ ████║
        ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██║██╔████╔██║
        ██║╚██╗██║██║ ██╔██╗ ╚██╗ ██╔╝██║██║╚██╔╝██║
        ██║ ╚████║██║██╔╝ ██╗ ╚████╔╝ ██║██║ ╚═╝ ██║
        ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝
               Modeless editing for everyone]],
                    },

                    sections = {
                      { section = "header" },
                      { padding = 1 },
                      {
                        text = {
                          { "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", hl = "SnacksDashboardSpecial" },
                        },
                        align = "center",
                        padding = 1,
                      },
                      {
                        text = { { "Quick Actions", hl = "SnacksDashboardTitle" } },
                        align = "center",
                        padding = 1,
                      },
                      { section = "keys", gap = 1, padding = 1 },
                      {
                        text = {
                          { "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", hl = "SnacksDashboardSpecial" },
                        },
                        align = "center",
                        padding = 1,
                      },
                      {
                        text = { { "CUA Keybindings", hl = "SnacksDashboardTitle" } },
                        align = "center",
                        padding = 1,
                      },
                      {
                        text = {
                          { "Ctrl+S", hl = "SnacksDashboardKey" }, { "  Save          ", hl = "SnacksDashboardDesc" },
                          { "Ctrl+Z", hl = "SnacksDashboardKey" }, { "  Undo          ", hl = "SnacksDashboardDesc" },
                          { "Ctrl+Y", hl = "SnacksDashboardKey" }, { "  Redo", hl = "SnacksDashboardDesc" },
                        },
                        align = "center",
                      },
                      {
                        text = {
                          { "Ctrl+C", hl = "SnacksDashboardKey" }, { "  Copy          ", hl = "SnacksDashboardDesc" },
                          { "Ctrl+X", hl = "SnacksDashboardKey" }, { "  Cut           ", hl = "SnacksDashboardDesc" },
                          { "Ctrl+V", hl = "SnacksDashboardKey" }, { "  Paste", hl = "SnacksDashboardDesc" },
                        },
                        align = "center",
                      },
                      {
                        text = {
                          { "Ctrl+F", hl = "SnacksDashboardKey" }, { "  Find          ", hl = "SnacksDashboardDesc" },
                          { "Ctrl+H", hl = "SnacksDashboardKey" }, { "  Replace       ", hl = "SnacksDashboardDesc" },
                          { "Ctrl+P", hl = "SnacksDashboardKey" }, { "  Find Files", hl = "SnacksDashboardDesc" },
                        },
                        align = "center",
                      },
                      {
                        text = {
                          { "Ctrl+B", hl = "SnacksDashboardKey" }, { "  File Tree     ", hl = "SnacksDashboardDesc" },
                          { "Ctrl+`", hl = "SnacksDashboardKey" }, { "  Terminal      ", hl = "SnacksDashboardDesc" },
                          { "F12   ", hl = "SnacksDashboardKey" }, { "  Go to Def", hl = "SnacksDashboardDesc" },
                        },
                        align = "center",
                        padding = 1,
                      },
                      {
                        text = {
                          { "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", hl = "SnacksDashboardSpecial" },
                        },
                        align = "center",
                        padding = 1,
                      },
                    },
                  },

                  -- Picker: replaces Telescope for fuzzy finding
                  picker = {
                    enabled = true,
                    ui_select = true,  -- Replaces telescope-ui-select
                  sources = {
                    files = { hidden = true },
                    grep = { hidden = true },
                    explorer = {
                      focus = "input",  -- Focus search input instead of file list
                      on_show = function(picker)
                        vim.defer_fn(function()
                          vim.cmd("startinsert")
                        end, 1)
                      end,
                      follow_file = true,
                      auto_close = false,
                      jump = { close = false },
                      win = {
                        input = {
                          keys = {
                            -- Navigate matches while staying in search input
                            ["<Up>"] = { "list_up", mode = { "i", "n" } },
                            ["<Down>"] = { "list_down", mode = { "i", "n" } },
                            -- Fast navigation with PageUp/PageDown
                            ["<PageUp>"] = { "page_up", mode = { "i", "n" } },
                            ["<PageDown>"] = { "page_down", mode = { "i", "n" } },
                            -- Escape clears search filter; use / to toggle focus back to list
                            ["<Esc>"] = { "clear_filter", mode = { "i", "n" } },
                            -- Ctrl+B closes explorer (consistent with global toggle)
                            ["<c-b>"] = { "cancel", mode = { "i", "n" } },
                            -- Disable Vim-style navigation in input (allows typing j/k)
                            ["j"] = "<Nop>",
                            ["k"] = "<Nop>",
                          },
                        },
                        list = {
                          keys = {
                            -- CUA-style navigation (mode "n" for normal mode in picker)
                            ["<Up>"] = "list_up",
                            ["<Down>"] = "list_down",
                            -- PageUp/PageDown: use custom actions that scroll by 80% of window
                            -- height, which works better than list_scroll_up/down for small windows
                            ["<PageUp>"] = "page_up",
                            ["<PageDown>"] = "page_down",
                            ["<Left>"] = "explorer_close",
                            ["<Right>"] = "confirm",
                            ["<CR>"] = "confirm",           -- Enter to open
                            ["<2-LeftMouse>"] = "confirm",  -- Double-click to open

                            -- CUA-style file operations
                            ["<F2>"] = "explorer_rename",   -- Rename
                            ["<Delete>"] = "explorer_del",  -- Delete
                            ["<F5>"] = "explorer_update",   -- Refresh
                            ["a"] = "explorer_add",         -- Add file/directory
                            ["c"] = "explorer_copy",        -- Copy
                            ["x"] = "explorer_move",        -- Cut
                            ["p"] = "explorer_paste",       -- Paste
                            ["y"] = "explorer_yank",        -- Yank path
                            ["h"] = "toggle_hidden",        -- Toggle hidden files
                            ["/"] = "filter",               -- Filter/fuzzy find

                            -- Disable Vim-style navigation (using CUA arrow keys only)
                            ["j"] = "<Nop>",
                            ["k"] = "<Nop>",
                            ["gg"] = "<Nop>",
                            ["G"] = "<Nop>",
                            ["i"] = "<Nop>",
                            ["l"] = "<Nop>",

                            -- Selection
                            ["<Space>"] = "toggle_select",
                            ["<Tab>"] = "select_and_next",

                            -- Close explorer (cancel restores focus to main window)
                            ["q"] = "cancel",
                            ["<Esc>"] = "cancel",
                            -- Ctrl+B toggle: close explorer when focused (mirror of global Ctrl+B)
                            ["<c-b>"] = "cancel",
                            -- Ctrl+Q: close explorer AND quit Neovim (single-press quit)
                            -- Uses custom action that handles unsaved buffers gracefully
                            ["<C-q>"] = "close_and_quit",
                          },
                        },
                      },
                    },
                  },
                    win = {
                      input = {
                        keys = {
                          ["<c-t>"] = { "trouble_open", mode = { "n", "i" } },
                        },
                      },
                      list = {
                        keys = {
                          -- Disable default preview_scroll_up to allow explorer Ctrl+B toggle
                          ["<c-b>"] = false,
                        },
                      },
                    },
                    -- Custom actions for CUA-style behaviour
                    -- Merged with Trouble actions for Ctrl+T integration
                    actions = vim.tbl_extend("force", require("trouble.sources.snacks").actions, {
                      -- Clear filter text (for Escape in search input)
                      clear_filter = function(picker)
                        -- Clear the input line using Vim's native <C-u>
                        local keys = vim.api.nvim_replace_termcodes("<C-u>", true, true, true)
                        vim.api.nvim_feedkeys(keys, "n", false)
                      end,
                      -- Page scrolling with fixed amounts (independent of vim.wo.scroll)
                      -- This fixes PageUp/PageDown in small windows like explorer sidebar
                      page_down = function(picker)
                        local height = picker.list.state.height or 20
                        picker.list:scroll(math.max(1, math.floor(height * 0.8)))
                      end,
                      page_up = function(picker)
                        local height = picker.list.state.height or 20
                        picker.list:scroll(-math.max(1, math.floor(height * 0.8)))
                      end,
                      -- Close explorer and quit Neovim (for Ctrl+Q single-press quit)
                      close_and_quit = function(picker)
                        picker:close()
                        vim.schedule(function()
                          -- Only quit if no unsaved buffers
                          local modified = vim.tbl_filter(function(buf)
                            return vim.bo[buf].modified
                          end, vim.api.nvim_list_bufs())
                          if #modified > 0 then
                            vim.cmd('confirm qa')
                          else
                            vim.cmd('qa')
                          end
                        end)
                      end,
                    }),
                  },

                  -- Terminal (replaces toggleterm.nvim)
                  terminal = {
                    enabled = true,
                    win = {
                      style = 'terminal',
                      position = 'bottom',
                      height = 0.3,
                      border = 'rounded',
                    },
                  },

                  -- Lazygit integration
                  lazygit = {
                    enabled = true,
                    configure = true,  -- Auto-sync theme with Neovim colorscheme
                    win = {
                      style = 'float',
                      width = 0.9,
                      height = 0.9,
                      border = 'rounded',
                    },
                  },

                  -- Git browse (open files in GitHub/GitLab)
                  gitbrowse = {
                    enabled = true,
                    notify = true,
                  },

                  -- Notification system (replaces fidget for LSP progress)
                  notifier = {
                    enabled = true,
                    timeout = 3000,
                    width = { min = 40, max = 0.4 },
                    height = { min = 1, max = 0.6 },
                    margin = { top = 0, right = 1, bottom = 0 },
                    padding = true,
                    sort = { "level", "added" },
                    level = vim.log.levels.TRACE,
                    icons = { error = " ", warn = " ", info = " ", debug = " ", trace = " " },
                    style = "compact",
                    top_down = true,
                    date_format = "%R",
                  },

                  -- Indent guides with rainbow colours and scope highlighting (replaces indent-blankline and hlchunk)
                  indent = {
                    enabled = true,
                    indent = {
                      enabled = true,
                      only_scope = true,
                      only_current = true,
                      char = "│",
                      priority = 1,
                      hl = { "SnacksIndent1", "SnacksIndent2", "SnacksIndent3", "SnacksIndent4", "SnacksIndent5", "SnacksIndent6", "SnacksIndent7" },
                    },
                    animate = {
                      enabled = vim.fn.has("nvim-0.10") == 1,
                      style = "out",
                      easing = "linear",
                      duration = { step = 20, total = 300 },
                    },
                    scope = {
                      enabled = true,
                      priority = 200,
                      char = "│",
                      underline = false,
                      only_current = false,
                      hl = "SnacksIndentScope",
                    },
                    chunk = {
                      enabled = true,
                      only_current = true,
                      priority = 200,
                      hl = "SnacksIndentChunk",
                      char = { corner_top = "╭", corner_bottom = "╰", horizontal = "─", vertical = "│", arrow = "🢒" },
                    },
                  },

                  -- Status column with git signs and fold indicators (replaces scrollview signs)
                  statuscolumn = {
                    enabled = true,
                    left = { "mark", "sign" },
                    right = { "fold", "git" },
                    folds = { open = false, git_hl = false },
                    git = { patterns = { "GitSign", "MiniDiffSign" } },
                    refresh = 50,
                  },

                  -- Word highlighting and navigation (replaces vim-illuminate)
                  words = {
                    enabled = true,
                    debounce = 200,
                    notify_jump = false,
                    notify_end = true,
                    foldopen = true,
                    jumplist = true,
                    modes = { "n", "i", "c" },
                  },

                  -- Smooth scrolling (replaces nvim-scrollview scrolling behaviour)
                  scroll = {
                    enabled = true,
                    animate = {
                      duration = { step = 10, total = 200 },
                      easing = "linear",
                    },
                    animate_repeat = {
                      delay = 100,
                      duration = { step = 5, total = 50 },
                      easing = "linear",
                    },
                    filter = function(buf)
                      return vim.g.snacks_scroll ~= false and vim.b[buf].snacks_scroll ~= false and vim.bo[buf].buftype ~= "terminal"
                    end,
                  },

                  -- Dim: focus mode that dims code outside current scope
                  dim = {
                    enabled = true,
                    scope = {
                      min_size = 5,
                      max_size = 20,
                      siblings = true,
                    },
                    animate = {
                      enabled = true,
                      easing = "outQuad",
                      duration = { step = 20, total = 300 },
                    },
                  },

                  -- Image rendering in documents
                  image = {
                    enabled = true,
                    formats = { "png", "jpg", "jpeg", "gif", "bmp", "webp", "tiff", "heic", "avif", "mp4", "mov", "avi", "mkv", "webm", "pdf" },
                    force = false,
                    doc = { enabled = true, inline = true, float = true, max_width = 80, max_height = 40 },
                    img_dirs = { "img", "images", "assets", "static", "public", "media" },
                    icons = { math = " ", chart = " ", image = " " },
                  },

                  -- File explorer with CUA-style keybindings
                  -- NOTE: Explorer is a picker in disguise. Key actions:
                  --   - close: closes picker only
                  --   - cancel: closes picker and restores focus to main window
                  --   - page_up/page_down: custom actions that scroll by 80% of window height
                  --   - close_and_quit: closes explorer then quits Neovim
                  --   - list_up/down: move cursor by one item
                  -- IMPORTANT: novim-mode must be disabled for snacks_picker_list filetype
                  -- (see FileType autocmd above) otherwise keys are intercepted before
                  -- Snacks can process them.
                  -- Keybindings are configured in picker.sources.explorer above.
                  explorer = {
                    enabled = true,
                  },
                  scope = { enabled = false },
                  animate = { enabled = false },
                }

                -- Scrollbar with Catppuccin colors and gitsigns integration
                -- Renders on the right edge (separate from snacks.statuscolumn on the left)
                require('scrollbar').setup {
                  show = true,
                  show_in_active_only = false,
                  set_highlights = true,
                  folds = 1000, -- handle folds, large value means only show for unfolded regions
                  max_lines = false, -- disable for large files
                  hide_if_all_visible = false, -- hide if nothing to scroll
                  throttle_ms = 100,
                  handle = {
                    text = ' ',
                    blend = 50,
                    color = '${catppuccinPalette.getColor "surface1"}',
                    highlight = 'Visual',
                    hide_if_all_visible = true, -- hides handle if all lines are visible
                  },
                  marks = {
                     Cursor = {
                       text = '⌖',
                       priority = 0,
                       color = '${catppuccinPalette.getColor "blue"}',
                       highlight = 'Normal',
                     },
                    Search = {
                      text = { '┈', '┉' },
                      priority = 1,
                      color = '${catppuccinPalette.getColor "peach"}',
                      highlight = 'Search',
                    },
                    Error = {
                      text = { '✗', '✘' },
                      priority = 2,
                      color = '${catppuccinPalette.getColor "red"}',
                      highlight = 'DiagnosticError',
                    },
                     Warn = {
                       text = { '△', '▲' },
                       priority = 3,
                       color = '${catppuccinPalette.getColor "yellow"}',
                       highlight = 'DiagnosticWarn',
                     },
                    Info = {
                      text = { '○', '●' },
                      priority = 4,
                      color = '${catppuccinPalette.getColor "sky"}',
                      highlight = 'DiagnosticInfo',
                    },
                     Hint = {
                       text = { '◇', '◆' },
                       priority = 5,
                       color = '${catppuccinPalette.getColor "teal"}',
                       highlight = 'DiagnosticHint',
                     },
                    GitAdd = {
                      text = '┃',
                      priority = 7,
                      color = '${catppuccinPalette.getColor "green"}',
                      highlight = 'GitSignsAdd',
                    },
                    GitChange = {
                      text = '┋',
                      priority = 7,
                      color = '${catppuccinPalette.getColor "yellow"}',
                      highlight = 'GitSignsChange',
                    },
                    GitDelete = {
                      text = '┃' ,
                      priority = 7,
                      color = '${catppuccinPalette.getColor "red"}',
                      highlight = 'GitSignsDelete',
                    },
                  },
                  excluded_buftypes = {
                    'terminal',
                  },
                  excluded_filetypes = {
                    'prompt',
                    'TelescopePrompt',
                    'noice',
                    'snacks_picker',
                    'snacks_dashboard',
                    'snacks_input',
                    'snacks_picker_list',
                    'trouble',
                    'codecompanion',
                  },
                  autocmd = {
                    render = {
                      'BufWinEnter',
                      'TabEnter',
                      'TermEnter',
                      'WinEnter',
                      'CmdwinLeave',
                      'TextChanged',
                      'VimResized',
                      'WinScrolled',
                    },
                    clear = {
                      'BufWinLeave',
                      'TabLeave',
                      'TermLeave',
                      'WinLeave',
                    },
                  },
                  handlers = {
                    cursor = true,
                    diagnostic = true,
                    gitsigns = true, -- requires gitsigns
                    handle = true,
                    search = false, -- disabled (user doesn't have nvim-hlslens)
                  },
                }

                -- Gitsigns integration for scrollbar
                require('scrollbar.handlers.gitsigns').setup()

                -- LSP Progress notifications (replaces fidget)
                local lsp_progress = vim.defaulttable()
                vim.api.nvim_create_autocmd("LspProgress", {
                  callback = function(ev)
                    local client = vim.lsp.get_client_by_id(ev.data.client_id)
                    local value = ev.data.params.value
                    if not client or type(value) ~= "table" then return end

                    local p = lsp_progress[client.id]
                    for i = 1, #p + 1 do
                      if i == #p + 1 or p[i].token == ev.data.params.token then
                        p[i] = {
                          token = ev.data.params.token,
                          msg = ("[%3d%%] %s%s"):format(
                            value.kind == "end" and 100 or value.percentage or 100,
                            value.title or "",
                            value.message and (" **%s**"):format(value.message) or ""
                          ),
                          done = value.kind == "end",
                        }
                        break
                      end
                    end

                    local msg = {}
                    lsp_progress[client.id] = vim.tbl_filter(function(v)
                      return table.insert(msg, v.msg) or not v.done
                    end, p)

                    local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
                    vim.notify(table.concat(msg, "\n"), "info", {
                      id = "lsp_progress",
                      title = client.name,
                      opts = function(notif)
                        notif.icon = #lsp_progress[client.id] == 0 and " "
                          or spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
                      end,
                    })
                  end,
                })

                -- Custom highlight groups for dashboard (Catppuccin integration)
                vim.api.nvim_create_autocmd("ColorScheme", {
                  callback = function()
                    vim.api.nvim_set_hl(0, "SnacksDashboardHeader", { fg = "${catppuccinPalette.getColor "mauve"}", bold = true })
                    vim.api.nvim_set_hl(0, "SnacksDashboardTitle", { fg = "${catppuccinPalette.getColor "blue"}", bold = true })
                    vim.api.nvim_set_hl(0, "SnacksDashboardKey", { fg = "${catppuccinPalette.getColor "peach"}", bold = true })
                    vim.api.nvim_set_hl(0, "SnacksDashboardDesc", { fg = "${catppuccinPalette.getColor "text"}" })
                    vim.api.nvim_set_hl(0, "SnacksDashboardSpecial", { fg = "${catppuccinPalette.getColor "surface1"}" })
                    vim.api.nvim_set_hl(0, "SnacksDashboardIcon", { fg = "${catppuccinPalette.getColor "lavender"}" })

                    -- Snacks indent rainbow colours
                    vim.api.nvim_set_hl(0, "SnacksIndent1", { fg = "${catppuccinPalette.getColor "rosewater"}" })
                    vim.api.nvim_set_hl(0, "SnacksIndent2", { fg = "${catppuccinPalette.getColor "flamingo"}" })
                    vim.api.nvim_set_hl(0, "SnacksIndent3", { fg = "${catppuccinPalette.getColor "pink"}" })
                    vim.api.nvim_set_hl(0, "SnacksIndent4", { fg = "${catppuccinPalette.getColor "mauve"}" })
                    vim.api.nvim_set_hl(0, "SnacksIndent5", { fg = "${catppuccinPalette.getColor "blue"}" })
                    vim.api.nvim_set_hl(0, "SnacksIndent6", { fg = "${catppuccinPalette.getColor "teal"}" })
                    vim.api.nvim_set_hl(0, "SnacksIndent7", { fg = "${catppuccinPalette.getColor "green"}" })
                    vim.api.nvim_set_hl(0, "SnacksIndentScope", { fg = "${catppuccinPalette.getColor "lavender"}", bold = true })
                    vim.api.nvim_set_hl(0, "SnacksIndentChunk", { fg = "${catppuccinPalette.getColor "mauve"}" })

                    -- Snacks notification styling
                    vim.api.nvim_set_hl(0, "SnacksNotifierTitle", { fg = "${catppuccinPalette.getColor "blue"}", bold = true })
                    vim.api.nvim_set_hl(0, "SnacksNotifierBorder", { fg = "${catppuccinPalette.getColor "surface1"}" })

                    -- Snacks dim highlight (subtle grey for unfocused code)
                    vim.api.nvim_set_hl(0, "SnacksDim", { fg = "${catppuccinPalette.getColor "overlay0"}" })
                  end,
                })
                vim.cmd("doautocmd ColorScheme")

                -- Auto-trim trailing whitespace on save
                require('trim').setup {
                  ft_blocklist = { 'markdown', 'diff', 'gitcommit' },
                  trim_on_write = true,
                  trim_trailing = true,
                  trim_last_line = true,       -- Remove blank lines at end of file
                  trim_first_line = true,      -- Remove blank lines at start of file
                  highlight = false,           -- Don't highlight (trim handles this silently)
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
                  disable_filetype = { "snacks_picker", "vim" },
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
                -- Explorer state is handled by session save/restore; no manual opening needed
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
                  -- Don't save explorer windows in session (avoids restoration conflicts)
                  bypass_save_filetypes = { 'snacks_picker_list', 'snacks_dashboard' },
                  -- Close explorer before saving session to prevent stale state
                  pre_save_cmds = {
                    function()
                      -- Close any open Snacks picker/explorer windows before save
                      for _, win in ipairs(vim.api.nvim_list_wins()) do
                        local buf = vim.api.nvim_win_get_buf(win)
                        local ft = vim.bo[buf].filetype
                        if ft:match("^snacks_picker") or ft == "snacks_dashboard" then
                          pcall(vim.api.nvim_win_close, win, true)
                        end
                      end
                    end,
                  },
                }

                -- Terminal keybindings (Ctrl+` to toggle, like VSCode)
                vim.keymap.set({'n', 'i', 'v', 't'}, '<C-`>', function()
                  Snacks.terminal.toggle()
                end, { noremap = true, silent = true, desc = 'Toggle terminal' })

                vim.keymap.set({'n', 'i', 'v', 't'}, '<C-S-`>', function()
                  Snacks.terminal.toggle(nil, { win = { position = 'float', border = 'rounded' } })
                end, { noremap = true, silent = true, desc = 'Toggle floating terminal' })

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
                    vim.keymap.set({'n', 'i'}, '<C-S-o>', function() Snacks.picker.lsp_symbols() end, opts)  -- Document symbols
                  end,
                })

                -- Keybindings for plugins (CUA-friendly, work in all modes)
                local opts = { noremap = true, silent = true }
                -- Ctrl+P for file finder (all modes)
                vim.keymap.set({'n', 'i', 'v'}, '<C-p>', function() Snacks.picker.files() end, opts)
                -- Alt+Home: Open dashboard
                vim.keymap.set({'n', 'i', 'v'}, '<M-Home>', function() Snacks.dashboard() end, opts)
                -- Toggle file explorer (Ctrl+B for CUA familiarity)
                -- Close explorer if focused, otherwise toggle it open
                vim.keymap.set({'n', 'i', 'v'}, '<C-b>', function()
                  local ft = vim.bo.filetype
                  if ft == 'snacks_picker_list' or ft == 'snacks_picker_input' or ft == 'snacks_picker_preview' then
                    -- In explorer: use same action as Esc (cancel = close and restore focus)
                    local picker = Snacks.picker.get()[1]
                    if picker then picker:close() end
                  else
                    -- Not in explorer: toggle it
                    Snacks.explorer()
                  end
                end, { desc = 'Toggle file explorer' })
                -- Tab switching (Ctrl+Tab / Ctrl+Shift+Tab)
                vim.keymap.set({'n', 'i', 'v'}, '<C-Tab>', '<cmd>BufferLineCycleNext<cr>', opts)
                vim.keymap.set({'n', 'i', 'v'}, '<C-S-Tab>', '<cmd>BufferLineCyclePrev<cr>', opts)
                -- Ctrl+W to close current buffer (using Snacks.bufdelete for clean closure)
                vim.keymap.set({'n', 'i', 'v'}, '<C-w>', function() Snacks.bufdelete() end, opts)
                -- Words navigation (LSP references - replaces vim-illuminate navigation)
                vim.keymap.set({'n', 'i'}, ']]', function() Snacks.words.jump(vim.v.count1) end, { noremap = true, silent = true, desc = 'Next LSP reference' })
                vim.keymap.set({'n', 'i'}, '[[', function() Snacks.words.jump(-vim.v.count1) end, { noremap = true, silent = true, desc = 'Previous LSP reference' })
                -- Alt+S for "Save As" (Ctrl+Shift+S doesn't work reliably in terminals)
                vim.keymap.set({'n', 'i', 'v', 's'}, '<M-s>', function()
                  vim.ui.input({ prompt = "Save as: ", default = vim.fn.expand("%:p") }, function(input)
                    if input and input ~= "" then
                      vim.cmd("saveas " .. vim.fn.fnameescape(input))
                    end
                  end)
                end, opts)
                -- Ctrl+Shift+F for grep/search in files
                vim.keymap.set({'n', 'i', 'v'}, '<C-S-f>', function() Snacks.picker.grep() end, opts)
                -- Todo comments navigation
                vim.keymap.set({'n', 'i', 'v'}, '<C-S-t>', function() Snacks.picker.todo_comments() end, opts)  -- Search TODOs
                -- Trouble diagnostics panel
                vim.keymap.set({'n', 'i', 'v'}, '<C-S-m>', '<cmd>Trouble diagnostics toggle<cr>', opts)  -- Problems panel
                -- Buffer diagnostics only (Alt+M)
                vim.keymap.set({'n', 'i', 'v'}, '<M-m>', '<cmd>Trouble diagnostics_buffer toggle<cr>', opts)
                -- Symbols/Outline panel (Alt+O)
                vim.keymap.set({'n', 'i', 'v'}, '<M-o>', '<cmd>Trouble symbols toggle<cr>', opts)
                -- Todo comments panel (Alt+Shift+T to avoid conflict with CodeCompanion Alt+T)
                vim.keymap.set({'n', 'i', 'v'}, '<M-S-t>', '<cmd>Trouble todo toggle<cr>', opts)
                -- Navigate problems: F8/Shift+F8 (VSCode standard)
                vim.keymap.set({'n', 'i', 'v'}, '<F8>', function()
                  require('trouble').next({ skip_groups = true, jump = true })
                end, opts)
                vim.keymap.set({'n', 'i', 'v'}, '<S-F8>', function()
                  require('trouble').prev({ skip_groups = true, jump = true })
                end, opts)
                -- LSP references in Trouble (Alt+Shift+F12)
                vim.keymap.set({'n', 'i', 'v'}, '<M-S-F12>', '<cmd>Trouble lsp_references toggle<cr>', opts)
                -- Quickfix list in Trouble (Alt+Shift+Q)
                vim.keymap.set({'n', 'i', 'v'}, '<M-S-q>', '<cmd>Trouble qflist toggle<cr>', opts)

                -- =========================================================================
                -- FIND AND REPLACE (CUA-style floating dialogs)
                -- =========================================================================
                -- Override novim-mode's Ctrl+F (native /) with searchbox floating dialog
                -- Must be set after plugins load to take precedence
                vim.api.nvim_create_autocmd('VimEnter', {
                  callback = function()
                    local find_opts = { noremap = true, silent = true }

                    -- Ctrl+F: Find in current buffer (floating dialog)
                    vim.keymap.set({'n', 'i', 'v', 's'}, '<C-f>', function()
                      require('searchbox').incsearch({
                        show_matches = '[{match}/{total}]',
                      })
                    end, find_opts)

                    -- Ctrl+H: Find and Replace in current buffer (floating dialog)
                    vim.keymap.set({'n', 'i', 'v', 's'}, '<C-h>', function()
                      require('searchbox').replace({
                        confirm = 'menu',
                      })
                    end, find_opts)

                    -- Visual mode: search within selection
                    vim.keymap.set('v', '<C-f>', function()
                      require('searchbox').incsearch({ visual_mode = true })
                    end, find_opts)

                    -- Visual mode: replace within selection
                    vim.keymap.set('v', '<C-h>', function()
                      require('searchbox').replace({ visual_mode = true, confirm = 'menu' })
                    end, find_opts)

                    -- F3 / Shift+F3: Find next/previous match
                    vim.keymap.set({'n', 'i', 'v', 's'}, '<F3>', '<cmd>normal! n<cr>', find_opts)
                    vim.keymap.set({'n', 'i', 'v', 's'}, '<S-F3>', '<cmd>normal! N<cr>', find_opts)
                  end,
                })

                -- Lazygit (Ctrl+G - terminals can't distinguish Ctrl+G from Ctrl+Shift+G)
                -- Override novim-mode's Ctrl+G (goto line) since we use Ctrl+L for goto line
                -- Set after plugins load to ensure priority over novim-mode's binding
                vim.api.nvim_create_autocmd('VimEnter', {
                  callback = function()
                    vim.keymap.set({'n', 'i', 'v', 's'}, '<C-g>', function()
                      Snacks.lazygit()
                    end, { noremap = true, silent = true, desc = 'Open Lazygit' })
                  end,
                })

                -- Git browse (open in GitHub/GitLab)
                vim.keymap.set({'n', 'i', 'v'}, '<M-S-g>', function()
                  Snacks.gitbrowse()
                end, { noremap = true, silent = true, desc = 'Open in GitHub' })

                -- GitHub integration (requires gh CLI)
                vim.keymap.set({'n', 'i', 'v'}, '<C-S-i>', function()
                  Snacks.picker.gh_issues()
                end, { noremap = true, silent = true, desc = 'GitHub Issues' })

                vim.keymap.set({'n', 'i', 'v'}, '<C-S-r>', function()
                  Snacks.picker.gh_prs()
                end, { noremap = true, silent = true, desc = 'GitHub PRs' })

                 -- Command palette (VSCode-style Ctrl+Shift+P)
                 vim.keymap.set({'n', 'i', 'v'}, '<C-S-p>', function() Snacks.picker.commands() end, opts)

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

                       -- Slash commands with Snacks picker integration
                       slash_commands = {
                         ['file'] = {
                           opts = { provider = 'snacks' },
                         },
                         ['buffer'] = {
                           opts = { provider = 'snacks' },
                         },
                         ['symbols'] = {
                           opts = { provider = 'snacks' },
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

                    -- Action palette uses Snacks picker (Escape to close, better UX)
                    action_palette = {
                      provider = 'snacks',
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
                -- Updates lualine status and shows notifications for AI activity.
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
                    -- Notify via Snacks notifier for more visible feedback
                    vim.notify("AI request started", vim.log.levels.INFO, { title = "CodeCompanion", id = "codecompanion" })
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
                      vim.notify("AI response complete", vim.log.levels.INFO, { title = "CodeCompanion", id = "codecompanion", timeout = 2000 })
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
