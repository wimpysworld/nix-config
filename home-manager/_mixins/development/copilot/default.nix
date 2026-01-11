{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "martin" ];

  # Domains to auto-approve for URL access in Copilot chat
  approvedDomains = [
    "anthrophic.com"
    "docs.anthropic.com"
    "claude.com"
    "code.claude.com"
    "platform.claude.com"
    "github.com"
    "docs.github.com"
    "raw.githubusercontent.com"
    "opencode.ai"
    "zed.dev"
  ];

  # Generate autoApprove configuration from domain list
  mkAutoApprove =
    domains:
    lib.genAttrs (map (domain: "https://${domain}") domains) (_: {
      approveRequest = true;
      approveResponse = true;
    });

  # Terminal command auto-approve settings for Copilot
  # Uses regex patterns: true = allow, false = deny
  # Format: "/^pattern$/" for regex, "command" for exact match
  terminalAutoApprove = {
    # ============================================================
    # ALLOW: Read-only and low-risk shell commands
    # ============================================================

    # Basic file inspection
    "/^ls\\b/" = true;
    "/^cat\\b/" = true;
    "/^head\\b/" = true;
    "/^tail\\b/" = true;
    "/^wc\\b/" = true;
    "/^file\\b/" = true;
    "/^tree\\b/" = true;
    "pwd" = true;
    "/^which\\b/" = true;
    "/^type\\b/" = true;
    "env" = true;
    "/^fd\\b/" = true;
    "/^rg\\b/" = true;
    "/^grep\\b/" = true;
    "/^egrep\\b/" = true;
    "/^fgrep\\b/" = true;
    "whoami" = true;
    "hostname" = true;
    "/^uname\\b/" = true;
    "/^df\\b/" = true;
    "/^free\\b/" = true;
    "/^ps\\b/" = true;
    "/^top -b\\b/" = true;
    "uptime" = true;
    "date" = true;
    "lscpu" = true;
    "lsblk" = true;
    "lsusb" = true;
    "lspci" = true;
    "id" = true;
    "groups" = true;
    "/^printenv\\b/" = true;
    "/^basename\\b/" = true;
    "/^dirname\\b/" = true;
    "/^realpath\\b/" = true;
    "/^stat\\b/" = true;
    "/^du\\b/" = true;
    "/^sort\\b/" = true;
    "/^uniq\\b/" = true;
    "/^cut\\b/" = true;
    "/^awk\\b/" = true;
    "/^diff\\b/" = true;
    "/^cmp\\b/" = true;
    "/^less\\b/" = true;
    "/^more\\b/" = true;
    "/^tr\\b/" = true;
    "/^tac\\b/" = true;
    "/^rev\\b/" = true;
    "/^seq\\b/" = true;
    "/^md5sum\\b/" = true;
    "/^sha256sum\\b/" = true;
    "/^shasum\\b/" = true;
    "/^jq\\b/" = true;
    "/^yq\\b/" = true;
    "/^bc\\b/" = true;
    "/^man\\b/" = true;
    "/^tldr\\b/" = true;
    "/^strings\\b/" = true;

    # Text processing - additional
    "/^(column|fold|nl|pr|expand|unexpand|paste|join|comm)\\b/" = true;

    # Archive inspection (read-only)
    "/^tar\\s+(--list|-t)\\b/" = true;
    "/^unzip\\s+-l\\b/" = true;
    "/^zipinfo\\b/" = true;
    "/^7z\\s+l\\b/" = true;
    "/^(zcat|bzcat|xzcat|zless|bzless|xzless)\\b/" = true;

    # Network inspection (read-only)
    "/^ip\\s+(addr|link show|route show)\\b/" = true;
    "/^ss\\s+-[tul]\\b/" = true;
    "/^netstat\\s+-[tl]\\b/" = true;
    "/^ping\\s+-c\\b/" = true;
    "/^(traceroute|dig|host|nslookup)\\b/" = true;

    # Process inspection
    "/^(pgrep|pidof|pstree)\\b/" = true;
    "/^lsof\\b/" = true;

    # Alternative file viewers
    "/^(bat|most)\\b/" = true;

    # Development helpers
    "/^(xxd|hexdump|od|base64|base32)\\b/" = true;

    # Systemd read-only
    "systemctl --version" = true;
    "/^systemctl (status|is-active|is-enabled|is-failed|list-units|list-unit-files|show|cat|list-dependencies|list-jobs)\\b/" =
      true;
    "/^journalctl\\b/" = true;
    "/^systemd-analyze\\b/" = true;
    "/^hostnamectl\\b/" = true;
    "/^timedatectl\\b/" = true;
    "/^loginctl\\b/" = true;
    "/^localectl\\b/" = true;
    "/^networkctl\\b/" = true;
    "/^resolvectl\\b/" = true;
    "/^busctl\\b/" = true;
    "/^coredumpctl\\b/" = true;

    # Docker read-only
    "docker --version" = true;
    "/^docker (ps|images|logs|inspect|info|stats|network ls|volume ls)\\b/" = true;
    "docker-compose --version" = true;
    "docker compose --version" = true;

    # Build tools - version checks
    "autoconf --version" = true;
    "automake --version" = true;
    "make --version" = true;
    "/^make -n\\b/" = true;
    "cmake --version" = true;
    "cmake -E capabilities" = true;
    "meson --version" = true;
    "ninja --version" = true;
    "clang --version" = true;
    "clang++ --version" = true;
    "clang-tidy --version" = true;
    "clang-format --version" = true;
    "clangd --version" = true;
    "gcc --version" = true;
    "g++ --version" = true;
    "/^ldd\\b/" = true;
    "/^pkg-config\\b/" = true;
    "/^pkgconf\\b/" = true;
    "ar --version" = true;
    "ranlib --version" = true;
    "/^objdump\\b/" = true;
    "/^nm\\b/" = true;
    "/^readelf\\b/" = true;

    # FFmpeg info
    "/^ffmpeg -(version|formats|codecs|encoders|decoders|bsfs|protocols|pix_fmts|layouts|sample_fmts|filters|hwaccels)/" =
      true;
    "/^ffprobe\\b/" = true;

    # GitHub read-only
    "gh --version" = true;
    "/^gh (repo view|pr view|pr list|issue view|issue list|status|api)\\b/" = true;

    # Git read-only
    "/^git (status|diff|log|branch|remote|show|stash list|tag|worktree list|config --list|config --get|reflog|rev-parse|describe|shortlog|blame|ls-files|ls-tree|grep)\\b/" =
      true;

    # Hugo info
    "hugo version" = true;
    "hugo env" = true;

    # ImageMagick info
    "/^identify\\b/" = true;
    "convert --version" = true;
    "magick --version" = true;
    "/^magick identify\\b/" = true;
    "compare --version" = true;
    "composite --version" = true;
    "mogrify --version" = true;

    # Nix read-only
    "nix --version" = true;
    "/^nix (flake show|flake check|flake metadata|eval|search|path-info)\\b/" = true;
    "/^nix-instantiate --parse\\b/" = true;
    "/^nixfmt --check\\b/" = true;

    # Go read-only
    "go version" = true;
    "/^go (env|list|vet|doc|mod graph|mod why)\\b/" = true;

    # JavaScript/TypeScript read-only
    "node --version" = true;
    "npm --version" = true;
    "pnpm --version" = true;
    "/^npm (ls|outdated|view|info)\\b/" = true;
    "npx --version" = true;
    "tsc --version" = true;
    "/^tsc --noEmit\\b/" = true;

    # Just listing
    "just --version" = true;
    "just --list" = true;
    "just -l" = true;
    "just --summary" = true;

    # Lua info
    "lua -v" = true;
    "love --version" = true;

    # Rust read-only
    "cargo --version" = true;
    "/^cargo (check|clippy|doc|tree|metadata|fmt --check)\\b/" = true;
    "rustc --version" = true;
    "rustup --version" = true;
    "/^rustup (show|target list|component list)\\b/" = true;

    # Python read-only
    "python --version" = true;
    "python3 --version" = true;
    "pip --version" = true;
    "/^pip (list|show|freeze|check)\\b/" = true;
    "pytest --version" = true;
    "/^python -m pytest --collect-only\\b/" = true;
    "mypy --version" = true;
    "ruff --version" = true;
    "/^ruff check\\b/" = true;
    "uv --version" = true;
    "/^uv pip list\\b/" = true;

    # Svelte info
    "svelte-check --help" = true;

    # Wails info
    "wails --version" = true;
    "wails doctor" = true;

    # Cloudflare info
    "wrangler --version" = true;
    "wrangler whoami" = true;

    # ============================================================
    # DENY: Destructive or dangerous commands
    # ============================================================

    # Shell destructive
    "/^rm\\b/" = false;
    "/^sudo\\b/" = false;
    "/^(shred|wipe|srm|rmdir|truncate)\\b/" = false;

    # File permission and ownership changes
    "/^chmod\\b/" = false;
    "/^chown\\b/" = false;

    # Symlink creation - can overwrite files
    "/^ln\\b/" = false;

    # System modification
    "/^(sysctl|modprobe|insmod|rmmod)\\b/" = false;

    # Boot/firmware
    "/^(grub-install|update-grub|efibootmgr)\\b/" = false;

    # Disk operations
    "/^(fdisk|parted|gparted|mkfs|mkswap|swapon|swapoff|mount|umount)\\b/" = false;
    "/^dd\\b/" = false; # Disk copy utility - extremely dangerous, can destroy disks

    # Subshell execution bypasses
    "/^(bash|sh|fish|zsh|dash)\\s+-c\\b/" = false;

    # Direct code execution via interpreters
    "/^python[23]?\\s+-c\\b/" = false;
    "/^node\\s+(--eval|-e)\\b/" = false;
    "/^perl\\s+-e\\b/" = false;
    "/^ruby\\s+-e\\b/" = false;
    "/^lua\\s+-e\\b/" = false;
    "/^php\\s+-r\\b/" = false;

    # Systemd power management
    "/^systemctl (poweroff|reboot|halt|suspend|hibernate)\\b/" = false;

    # Docker mass destruction
    "/^docker (system|volume|container|image) prune\\b/" = false;

    # GitHub destructive
    "/^gh repo delete\\b/" = false;

    # Git history rewriting
    "/^git push.*(--force|-f)/" = false;
    "/^git reset --hard\\b/" = false;
    "/^git clean\\b/" = false;
    "/^git filter-branch\\b/" = false;

    # Nix garbage collection
    "/^nix-collect-garbage\\b/" = false;

    # System rebuild commands - high risk configuration changes
    "/^(nixos-rebuild|home-manager|darwin-rebuild)\\b/" = false;

    # npm cache corruption
    "/^npm cache clean --force\\b/" = false;

    # Cloudflare deletion
    "/^wrangler delete\\b/" = false;

    # Text editors - interactive, can modify files
    "/^(vi|vim|nvim|emacs|nano|ed)\\b/" = false;

    # NOTE: Many state-modifying commands (git commit/push, npm install,
    # cargo build, docker run, etc.) are intentionally NOT listed here.
    # They fall through to VS Code's default prompt behavior, which is
    # safer than auto-approving. This provides defense-in-depth while
    # maintaining compatibility with opencode and Claude Code's explicit
    # "ask" behavior. For user convenience, these could be added as false
    # (deny/prompt) entries, but the current approach is more secure.
  };
in
lib.mkIf (lib.elem username installFor) {
  home = {
    packages = [
      inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.copilot-cli
      inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.spec-kit
    ];
  };
  programs = {
    neovim = lib.mkIf config.programs.neovim.enable {
      plugins = with pkgs.vimPlugins; [
        copilot-lua
        copilot-cmp
        CopilotChat-nvim
      ];
      extraLuaConfig = ''
        -- =========================================================================
        -- COPILOT AI ASSISTANCE (Modeless/CUA-style)
        -- =========================================================================
        -- Provides inline suggestions (ghost text), completion integration, and
        -- conversational AI chat (like VSCode Copilot Chat).
        --
        -- Authentication: Run :Copilot auth once to authenticate via browser.
        --                 Credentials stored in ~/.config/github-copilot/
        --
        -- INLINE SUGGESTION KEYBINDINGS:
        --   Tab: Accept full suggestion (like VSCode)
        --   Alt+]: Next suggestion | Alt+[: Previous suggestion
        --   Ctrl+]: Dismiss suggestion
        --   Alt+Enter: Open Copilot panel (multiple suggestions)
        --
        -- COPILOT CHAT KEYBINDINGS (VSCode-style, all modes):
        --   Ctrl+Alt+I: Open/toggle Chat panel (VSCode: open chat view)
        --   Ctrl+I: Inline chat - ask about selection/buffer (VSCode: inline chat)
        --   Ctrl+Shift+Alt+L: Quick chat overlay (VSCode: quick chat)
        --
        -- CHAT ACTIONS:
        --   Ctrl+N: New chat session (when in chat window)
        --   Ctrl+/: Quick actions menu (Explain, Review, Fix, etc.)
        --   Ctrl+.: Code actions / Fix with AI (like VSCode)
        --
        -- CHAT CONTEXT (prefix in chat input):
        --   #file:<path>        - Include file content
        --   #selection          - Include visual selection
        --   #gitdiff:staged     - Include staged git diff
        --   @copilot            - Enable tool calling (file search, grep, etc.)
        -- =========================================================================

        -- Setup copilot-lua for inline suggestions
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
              accept = "<Tab>",       -- Tab to accept suggestion (like VSCode)
              accept_word = false,    -- Disabled (use Tab for full accept)
              accept_line = false,    -- Disabled (use Tab for full accept)
              next = "<M-]>",         -- Alt+] for next suggestion
              prev = "<M-[>",         -- Alt+[ for previous suggestion
              dismiss = "<C-]>",      -- Ctrl+] to dismiss (Ctrl+E used for file tree)
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

        -- Setup CopilotChat for conversational AI
        require('CopilotChat').setup {
          -- Model selection (Pro+ subscription gives access to all models)
          model = 'claude-sonnet-4',  -- Best balance of speed and quality

          -- Chat window appearance
          window = {
            layout = 'vertical',      -- Side panel like VSCode
            width = 0.35,             -- 35% of screen width
            border = 'rounded',
            title = 'Copilot Chat',
          },

          -- Show diff for code suggestions
          show_diff = true,
          show_help = true,
          auto_follow_cursor = true,
          auto_insert_mode = true,    -- Start in insert mode (CUA-friendly)

          -- Context settings
          context = 'buffers',        -- Include open buffers as context

          -- Chat behaviour
          chat_autocomplete = true,   -- Enable autocompletion in chat

          -- Mappings within the chat window
          mappings = {
            complete = {
              insert = '<Tab>',       -- Tab to complete in chat
            },
            close = {
              normal = 'q',
              insert = '<C-c>',       -- Ctrl+C to close (CUA cancel)
            },
            reset = {
              normal = '<C-r>',       -- Ctrl+R to reset chat
              insert = '<C-r>',
            },
            submit_prompt = {
              normal = '<CR>',
              insert = '<CR>',        -- Enter to submit (natural chat behaviour)
            },
            accept_diff = {
              normal = '<C-y>',       -- Ctrl+Y to accept diff
              insert = '<C-y>',
            },
            show_diff = {
              normal = '<C-d>',       -- Ctrl+D to show diff
              insert = '<C-d>',
            },
            show_info = {
              normal = '<C-i>',       -- Ctrl+I for info
            },
            show_context = {
              normal = '<C-x>',       -- Ctrl+X to show context
            },
          },

          -- Built-in prompts (available as :CopilotChat<Name> commands)
          prompts = {
            Explain = {
              prompt = '/COPILOT_EXPLAIN Write an explanation for the selected code as paragraphs of text.',
              description = 'Explain how the code works',
            },
            Review = {
              prompt = '/COPILOT_REVIEW Review the selected code for potential issues and suggest improvements.',
              description = 'Review code for issues',
            },
            Fix = {
              prompt = '/COPILOT_GENERATE There is a problem in this code. Identify the issue and rewrite the code with the fix applied.',
              description = 'Fix issues in the code',
            },
            Optimize = {
              prompt = '/COPILOT_GENERATE Optimize the selected code to improve performance and readability.',
              description = 'Optimize the code',
            },
            Docs = {
              prompt = '/COPILOT_GENERATE Add documentation comments to the selected code.',
              description = 'Add documentation',
            },
            Tests = {
              prompt = '/COPILOT_GENERATE Generate unit tests for the selected code.',
              description = 'Generate unit tests',
            },
            Commit = {
              prompt = '#gitdiff:staged Generate a concise commit message following conventional commits format for the staged changes.',
              description = 'Generate commit message',
            },
          },
        }

        -- =========================================================================
        -- MODELESS CHAT WINDOW
        -- =========================================================================
        -- Force the CopilotChat buffer to behave like a normal text input field.
        -- Uses the same approach as novim-mode: timer-delayed startinsert and
        -- blocking Escape from leaving insert mode.
        --
        -- Chat input mappings:
        --   Enter: Submit prompt
        --   Shift+Enter: New line
        --   Ctrl+W / Ctrl+C: Close chat
        --   Tab: Complete
        -- =========================================================================

        -- Helper: make a buffer modeless (like novim-mode does)
        local function make_buffer_modeless()
          -- Use longer timer to ensure buffer is fully ready
          vim.fn.timer_start(50, function()
            vim.cmd('startinsert')
            -- Block Escape from leaving insert mode in this buffer
            vim.api.nvim_buf_set_keymap(0, 'i', '<Esc>', '<Nop>', { noremap = true, silent = true })
            -- Ctrl+W to close (standard CUA close window)
            vim.api.nvim_buf_set_keymap(0, 'i', '<C-w>', '<Cmd>CopilotChatClose<CR>', { noremap = true, silent = true })
            -- Shift+Enter for newline (since Enter submits)
            vim.api.nvim_buf_set_keymap(0, 'i', '<S-CR>', '<CR>', { noremap = true, silent = true })
          end)
        end

        -- Apply modeless behaviour when entering copilot chat buffers
        -- BufWinEnter fires after window is displayed (later than BufEnter)
        vim.api.nvim_create_autocmd('BufWinEnter', {
          pattern = '*copilot-chat',
          callback = make_buffer_modeless,
        })

        -- CopilotChat keybindings (VSCode-style, modeless - work across all modes)
        local chat_opts = { noremap = true, silent = true }

        -- Ctrl+Alt+I: Open/toggle Chat panel (VSCode: Ctrl+Alt+I opens chat view)
        vim.keymap.set({'n', 'i', 'v', 's'}, '<C-M-i>', '<Cmd>CopilotChatToggle<CR>', chat_opts)

        -- Ctrl+I: Inline chat - ask about selection or current context
        -- (VSCode: Ctrl+I for inline chat in editor)
        vim.keymap.set({'n', 'i', 'v', 's'}, '<C-i>', function()
          local input = vim.fn.input('Copilot: ')
          if input ~= "" then
            require('CopilotChat').ask(input)
            vim.schedule(function()
              vim.cmd('startinsert')
            end)
          end
        end, { noremap = true, silent = false })

        -- Ctrl+Shift+Alt+L: Quick chat overlay (VSCode: quick chat)
        vim.keymap.set({'n', 'i', 'v', 's'}, '<C-S-M-l>', function()
          require('CopilotChat').open()
          vim.schedule(function()
            vim.cmd('startinsert')
          end)
        end, chat_opts)

        -- Ctrl+/: Quick actions picker (prompts menu) - common IDE convention
        vim.keymap.set({'n', 'i', 'v', 's'}, '<C-/>', '<cmd>CopilotChatPrompts<cr>', chat_opts)

        -- Model selector (no standard VSCode binding, use Alt+M)
        vim.keymap.set({'n', 'i', 'v', 's'}, '<M-m>', '<cmd>CopilotChatModels<cr>', chat_opts)
      '';
    };
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        userSettings = {
          "chat.checkpoints.showFileChanges" = true;
          "chat.edits2.enabled" = true;
          "chat.editor.fontFamily" = "FiraCode Nerd Font Mono";
          "chat.editor.fontSize" = 16;
          "chat.fontFamily" = "Work Sans";
          "chat.fontSize" = 16;
          "chat.tools.terminal.autoApprove" = terminalAutoApprove;
          "chat.tools.terminal.blockDetectedFileWrites" = "outsideWorkspace";
          "chat.tools.terminal.enableAutoApprove" = true;
          "chat.tools.urls.autoApprove" = mkAutoApprove approvedDomains;
          "chat.viewSessions.orientation" = "stacked";
          "github.copilot.chat.anthropic.thinking.enabled" = true;
          "github.copilot.chat.codesearch.enabled" = true;
          "inlineChat.enableV2" = true;
        };
        extensions = with pkgs; [
          vscode-marketplace.github.copilot-chat
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      userSettings = {
        agent = {
          commit_message_model = {
            provider = "copilot_chat";
            model = "claude-haiku-4.5";
          };
          default_model = {
            provider = "copilot_chat";
            model = "claude-sonnet-4.5";
          };
          inline_assistant_model = {
            provider = "copilot_chat";
            model = "claude-haiku-4.5";
          };
          thread_summary_model = {
            provider = "copilot_chat";
            model = "gpt-5-mini";
          };
          features = {
            edit_prediction_provider = "copilot";
          };
        };
      };
    };
  };
}
