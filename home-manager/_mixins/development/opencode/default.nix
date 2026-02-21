{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  host = config.noughty.host;
  system = pkgs.stdenv.hostPlatform.system;
  opencodePackage = inputs.opencode.packages.${system}.opencode;
in
{
  home = {
    packages = [
      inputs.nix-ai-tools.packages.${system}.ccusage-opencode
    ]
    # TODO: Disabled until upstream fixes missing outputHashes
    # https://github.com/anomalyco/opencode/issues/11755
    ++ lib.optionals (false && host.is.workstation && host.is.linux) [
      inputs.opencode.packages.${system}.desktop
    ];
  };

  programs = {
    opencode = {
      enable = true;
      package = opencodePackage;
      settings = {
        theme = "catppuccin";

        # Context compaction - manual control
        # Use /compact slash command when context gets full
        # OpenCode displays token usage in the interface to help monitor
        compaction = {
          auto = false; # Disable automatic compaction
          prune = true; # Keep pruning old tool outputs to save tokens
        };

        # Semgrep LSP - security diagnostics via the built-in diagnostics tool
        lsp = {
          semgrep = {
            command = [
              "${pkgs.semgrep}/bin/semgrep"
              "lsp"
            ];
            extensions = [
              ".R"
              ".bash"
              ".c"
              ".cc"
              ".cjs"
              ".clj"
              ".cljc"
              ".cljs"
              ".cls"
              ".cpp"
              ".cs"
              ".cts"
              ".cxx"
              ".dart"
              ".ex"
              ".exs"
              ".go"
              ".h"
              ".hcl"
              ".hh"
              ".hpp"
              ".html"
              ".hxx"
              ".java"
              ".jl"
              ".js"
              ".json"
              ".jsonnet"
              ".jsx"
              ".kt"
              ".kts"
              ".libsonnet"
              ".lua"
              ".mjs"
              ".ml"
              ".mli"
              ".mts"
              ".php"
              ".py"
              ".r"
              ".rb"
              ".rs"
              ".scala"
              ".scm"
              ".sh"
              ".sol"
              ".ss"
              ".swift"
              ".tf"
              ".trigger"
              ".ts"
              ".tsx"
              ".xml"
              ".yaml"
              ".yml"
            ];
          };
        };

        # TUI settings
        tui = {
          diff_style = "stacked"; # Always show single-column stacked diffs
          scroll_acceleration = {
            enabled = true; # Enable macOS-style smooth scroll acceleration
          };
        };

        # ══════════════════════════════════════════════════════════════
        # Keybindings - Standard CUA text editor navigation
        # ══════════════════════════════════════════════════════════════
        keybinds = {
          # Core principle: Arrow keys, Home, End, and standard navigation
          # work like a normal text editor. PgUp/PgDn scroll chat history.
          # Full CUA (Common User Access) clipboard support.

          # Application control
          app_exit = "ctrl+q"; # Quit application (Ctrl+Q instead of Ctrl+C/D)
          session_interrupt = "escape"; # Interrupt model (keep default)

          # Text input cursor movement - standard arrow keys only
          input_move_up = "up";
          input_move_down = "down";
          input_move_left = "left";
          input_move_right = "right";

          # History navigation - use Ctrl+Up/Down (avoiding Alt conflicts with window manager)
          history_previous = "ctrl+up";
          history_next = "ctrl+down";

          # Home/End - dedicated to line navigation in input
          input_line_home = "home";
          input_line_end = "end";
          input_buffer_home = "ctrl+home"; # Top of input buffer
          input_buffer_end = "ctrl+end"; # Bottom of input buffer

          # Message navigation - PgUp/PgDn for scrolling
          messages_first = "shift+pageup"; # Jump to first message
          messages_last = "shift+pagedown"; # Jump to last message
          messages_page_up = "pageup"; # Scroll up one page
          messages_page_down = "pagedown"; # Scroll down one page
          messages_next = "none"; # Not bound (use PgDn to scroll)
          messages_previous = "none"; # Not bound (use PgUp to scroll)

          # Newline insertion - Shift+Enter (primary) plus alternatives
          input_newline = "shift+return,ctrl+return";

          # Submit on Enter
          input_submit = "return";

          # Selection with Shift+Arrows (standard text editor)
          input_select_up = "shift+up";
          input_select_down = "shift+down";
          input_select_left = "shift+left";
          input_select_right = "shift+right";
          input_select_line_home = "shift+home"; # Select to line start
          input_select_line_end = "shift+end"; # Select to line end
          input_select_buffer_home = "ctrl+shift+home,ctrl+a"; # Select to buffer start (Ctrl+A = CUA "Select All")
          input_select_buffer_end = "ctrl+shift+end"; # Select to buffer end

          # Note: Ctrl+A (Select All in CUA) selects from cursor to buffer start.
          # For true "select all": Press Ctrl+End (go to end) then Ctrl+A (select to start).
          # Most of the time you're already at the end when typing, so Ctrl+A works as expected.

          # Word movement (standard Windows/Linux text editor style)
          input_word_forward = "ctrl+right";
          input_word_backward = "ctrl+left";
          input_select_word_forward = "ctrl+shift+right";
          input_select_word_backward = "ctrl+shift+left";

          # Standard CUA (Common User Access) clipboard
          input_clear = "none"; # No clear binding needed (just select all & delete if needed)
          input_paste = "ctrl+v,shift+insert,ctrl+shift+v"; # Paste - standard CUA + terminal paste
          # Pending https://github.com/anomalyco/opencode/pull/7520
          #input_copy = "ctrl+insert"; # Copy selection (CUA standard)
          #input_cut = "shift+delete"; # Cut selection (CUA standard)
          input_undo = "ctrl+z"; # Undo
          input_redo = "ctrl+shift+z"; # Redo

          # Keyboard-based text copying in OpenCode:
          # 1. Select text with Shift+Arrow keys (or other input_select_* bindings)
          # 2. Press Ctrl+Insert to copy selected text to clipboard (CUA standard)
          # 3. Press Shift+Delete to cut selected text (copy + delete) (CUA standard)
          # 4. Press Ctrl+V or Shift+Insert to paste
          #
          # CUA-standard keybindings (Common User Access from IBM/Windows/Office):
          # - Work reliably across all terminal emulators (not intercepted)
          # - Align with existing input_paste default (Shift+Insert)
          # - Avoid conflicts with terminal native shortcuts (Ctrl+Shift+C/V)
          #
          # Alternative - Mouse-based copying:
          # - SELECT TEXT WITH MOUSE → automatically copied via OSC52
          # - Ctrl+Shift+V pastes (terminal native)
          # - Ctrl+V pastes (CUA standard, configured above)
          # - Shift+Insert pastes (CUA alternative, configured above)

          # Delete operations - standard text editor with CUA
          input_backspace = "backspace";
          input_delete = "delete"; # Plain Delete key only (Shift+Del is for cut in CUA)
          input_delete_word_forward = "ctrl+delete"; # Delete word forward
          input_delete_word_backward = "ctrl+backspace"; # Delete word backward
          input_delete_line = "ctrl+shift+k"; # Delete entire line
        };

        # Global permissions - applied to all agents including built-in Build and Plan
        # These provide guardrails across the board
        permission = {
          # Safe operations - allow without prompting
          # CRITICAL: Deny rules must be LAST due to .findLast() matching
          read = {
            # ALLOW: Default allow most file reads (FIRST - lowest priority)
            "*" = "allow";
            "**/*" = "allow";

            # ══════════════════════════════════════════════════════════════
            # DENY: Credentials and secrets (LAST - highest priority)
            # These must come after the allow rules due to .findLast()
            # ══════════════════════════════════════════════════════════════

            # Environment files
            ".env" = "deny";
            ".env.*" = "deny";
            ".env.local" = "deny";
            ".env.*.local" = "deny";

            # Secrets directories
            "**/secrets/**" = "deny";
            "**/.secrets/**" = "deny";
            "secrets/**" = "deny";
            ".secrets/**" = "deny";

            # SSH keys (fully qualified + patterns)
            "${config.home.homeDirectory}/.ssh/**" = "deny";
            "**/id_rsa" = "deny";
            "**/id_rsa.*" = "deny";
            "**/id_ed25519" = "deny";
            "**/id_ed25519.*" = "deny";
            "**/id_ecdsa" = "deny";
            "**/id_ecdsa.*" = "deny";
            "**/*_rsa" = "deny";
            "**/*_rsa.*" = "deny";
            "**/*_ed25519" = "deny";
            "**/*_ed25519.*" = "deny";
            "**/*_ecdsa" = "deny";
            "**/*_ecdsa.*" = "deny";
            "*.pem" = "deny";
            "*.key" = "deny";

            # GPG keys
            "${config.home.homeDirectory}/.gnupg/**" = "deny";

            # Cloud credentials
            "${config.home.homeDirectory}/.aws/**" = "deny";
            "${config.home.homeDirectory}/.azure/**" = "deny";
            "${config.xdg.configHome}/gcloud/**" = "deny";

            # VCS credentials
            "${config.xdg.configHome}/gh/hosts.yml" = "deny";
            "${config.home.homeDirectory}/.git-credentials" = "deny";
            "${config.home.homeDirectory}/.netrc" = "deny";

            # Container/Kubernetes secrets
            "${config.home.homeDirectory}/.docker/config.json" = "deny";
            "${config.home.homeDirectory}/.kube/**" = "deny";

            # Shell history (may contain passwords)
            "${config.home.homeDirectory}/.bash_history" = "deny";
            "${config.home.homeDirectory}/.zsh_history" = "deny";
            "${config.home.homeDirectory}/.fish_history" = "deny";
            "${config.xdg.dataHome}/fish/fish_history" = "deny";
          };
          glob = "allow"; # Finding files by pattern
          grep = "allow"; # Searching file contents
          list = "allow"; # Listing directories
          todoread = "allow"; # Reading todo lists
          lsp = "allow"; # Language server queries
          # Potentially destructive operations - require approval
          edit = "allow"; # All file modifications (edit, write, patch)
          bash = {
            # ══════════════════════════════════════════════════════════════
            # Shell - read-only utilities (safe with any arguments)
            # ══════════════════════════════════════════════════════════════
            "ls" = "allow";
            "ls *" = "allow";
            "cat" = "allow";
            "cat *" = "allow";
            "head" = "allow";
            "head *" = "allow";
            "tail" = "allow";
            "tail *" = "allow";
            "wc" = "allow";
            "wc *" = "allow";
            "file" = "allow";
            "file *" = "allow";
            "tree" = "allow";
            "tree *" = "allow";
            "pwd" = "allow";
            "which" = "allow";
            "which *" = "allow";
            "type" = "allow";
            "type *" = "allow";
            "env" = "allow";
            "fd" = "allow";
            "fd *" = "allow";
            "rg" = "allow";
            "rg *" = "allow";
            "grep" = "allow";
            "grep *" = "allow";
            "egrep *" = "allow";
            "fgrep *" = "allow";
            "mkdir" = "ask";
            "mkdir *" = "ask";
            "touch" = "ask";
            "touch *" = "ask";
            "whoami" = "allow";
            "hostname" = "allow";
            "hostname *" = "allow";
            "uname" = "allow";
            "uname *" = "allow";
            "df" = "allow";
            "df *" = "allow";
            "free" = "allow";
            "free *" = "allow";
            "ps" = "allow";
            "ps *" = "allow";
            "top -b*" = "allow";
            "uptime" = "allow";
            "date" = "allow";
            "date *" = "allow";
            "lscpu" = "allow";
            "lscpu *" = "allow";
            "lsblk" = "allow";
            "lsblk *" = "allow";
            "lsusb" = "allow";
            "lsusb *" = "allow";
            "lspci" = "allow";
            "lspci *" = "allow";
            "id" = "allow";
            "id *" = "allow";
            "groups" = "allow";
            "groups *" = "allow";
            "printenv" = "allow";
            "printenv *" = "allow";
            "basename *" = "allow";
            "dirname *" = "allow";
            "realpath *" = "allow";
            "stat" = "allow";
            "stat *" = "allow";
            "du" = "allow";
            "du *" = "allow";
            "sort" = "allow";
            "sort *" = "allow";
            "uniq" = "allow";
            "uniq *" = "allow";
            "cut" = "allow";
            "cut *" = "allow";
            "awk" = "allow";
            "awk *" = "allow";
            "diff" = "allow";
            "diff *" = "allow";
            "cmp" = "allow";
            "cmp *" = "allow";
            "less *" = "allow";
            "more *" = "allow";
            "tr *" = "allow";
            "tac" = "allow";
            "tac *" = "allow";
            "rev" = "allow";
            "rev *" = "allow";
            "seq *" = "allow";
            "md5sum *" = "allow";
            "sha256sum *" = "allow";
            "shasum *" = "allow";
            "jq" = "allow";
            "jq *" = "allow";
            "yq" = "allow";
            "yq *" = "allow";
            "bc" = "allow";
            "bc *" = "allow";
            "man *" = "allow";
            "tldr *" = "allow";
            "strings *" = "allow";
            "test *" = "allow";
            "true" = "allow";
            "false" = "allow";
            "sleep *" = "allow";

            # Text processing - additional
            "column *" = "allow";
            "fold *" = "allow";
            "nl *" = "allow";
            "pr *" = "allow";
            "expand *" = "allow";
            "unexpand *" = "allow";
            "paste *" = "allow";
            "join *" = "allow";
            "comm *" = "allow";

            # Archive inspection (read-only)
            "tar -t*" = "allow";
            "tar --list*" = "allow";
            "unzip -l*" = "allow";
            "zipinfo *" = "allow";
            "7z l*" = "allow";
            "zcat *" = "allow";
            "bzcat *" = "allow";
            "xzcat *" = "allow";
            "zless *" = "allow";
            "bzless *" = "allow";
            "xzless *" = "allow";

            # Network inspection (read-only)
            "ip addr" = "allow";
            "ip addr show*" = "allow";
            "ip link show*" = "allow";
            "ip route show*" = "allow";
            "ss -t*" = "allow";
            "ss -u*" = "allow";
            "ss -l*" = "allow";
            "netstat -t*" = "allow";
            "netstat -l*" = "allow";
            "ping -c*" = "allow";
            "traceroute *" = "allow";
            "dig *" = "allow";
            "host *" = "allow";
            "nslookup *" = "allow";

            # Process inspection
            "pgrep *" = "allow";
            "pidof *" = "allow";
            "pstree *" = "allow";
            "lsof -p*" = "allow";
            "lsof *" = "allow";

            # Alternative file viewers
            "bat" = "allow";
            "bat *" = "allow";
            "most *" = "allow";

            # Development helpers
            "xxd *" = "allow";
            "hexdump *" = "allow";
            "od *" = "allow";
            "base64 *" = "allow";
            "base32 *" = "allow";
            "shellcheck *" = "allow";
            "shfmt --diff *" = "allow";
            "shfmt -d *" = "allow";
            "luacheck *" = "allow";

            # Shell - ask: file modification or redirection risk
            "xdg-open *" = "ask";
            "sed" = "ask";
            "sed *" = "ask";
            "sd *" = "ask";
            "mv *" = "ask";
            "cp *" = "ask";
            "tee *" = "ask";
            "echo *" = "ask";
            "printf *" = "ask";
            "curl *" = "ask";
            "wget *" = "ask";
            "chmod *" = "ask";
            "chown *" = "ask";
            "kill *" = "ask";
            "pkill *" = "ask";
            "ln *" = "ask";

            # ══════════════════════════════════════════════════════════════
            # Systemd - deny power management first
            # ══════════════════════════════════════════════════════════════
            "systemctl poweroff*" = "deny";
            "systemctl reboot*" = "deny";
            "systemctl halt*" = "deny";
            "systemctl suspend*" = "deny";
            "systemctl hibernate*" = "deny";
            "systemctl rescue*" = "deny";
            "systemctl emergency*" = "deny";

            # Systemd - read-only status and log queries
            "systemctl --version" = "allow";
            "systemctl status" = "allow";
            "systemctl status *" = "allow";
            "systemctl is-active *" = "allow";
            "systemctl is-enabled *" = "allow";
            "systemctl is-failed *" = "allow";
            "systemctl list-units" = "allow";
            "systemctl list-units *" = "allow";
            "systemctl list-unit-files" = "allow";
            "systemctl list-unit-files *" = "allow";
            "systemctl list-dependencies *" = "allow";
            "systemctl list-jobs" = "allow";
            "systemctl list-jobs *" = "allow";
            "systemctl list-sockets*" = "allow";
            "systemctl list-timers*" = "allow";
            "systemctl show *" = "allow";
            "systemctl cat *" = "allow";
            "systemctl help *" = "allow";
            "journalctl" = "allow";
            "journalctl *" = "allow";
            "systemd-analyze" = "allow";
            "systemd-analyze *" = "allow";
            "hostnamectl" = "allow";
            "hostnamectl *" = "allow";
            "timedatectl" = "allow";
            "timedatectl *" = "allow";
            "loginctl" = "allow";
            "loginctl *" = "allow";
            "localectl" = "allow";
            "localectl *" = "allow";
            "networkctl" = "allow";
            "networkctl *" = "allow";
            "resolvectl" = "allow";
            "resolvectl *" = "allow";
            "busctl" = "allow";
            "busctl *" = "allow";
            "coredumpctl" = "allow";
            "coredumpctl *" = "allow";

            # Systemd - ask: service state modifications
            "systemctl start *" = "ask";
            "systemctl stop *" = "ask";
            "systemctl restart *" = "ask";
            "systemctl reload *" = "ask";
            "systemctl enable *" = "ask";
            "systemctl disable *" = "ask";
            "systemctl mask *" = "ask";
            "systemctl unmask *" = "ask";
            "systemctl daemon-reload" = "ask";
            "systemctl daemon-reexec" = "ask";
            "systemctl edit *" = "ask";
            "systemctl set-property *" = "ask";

            # ══════════════════════════════════════════════════════════════
            # Docker - deny mass destruction first
            # ══════════════════════════════════════════════════════════════
            "docker rm *" = "deny";
            "docker rmi *" = "deny";
            "docker system prune*" = "deny";
            "docker volume prune*" = "deny";
            "docker container prune*" = "deny";
            "docker image prune*" = "deny";
            "docker network prune*" = "deny";
            "docker volume rm *" = "deny";
            "docker network rm *" = "deny";

            # Docker - read-only queries
            "docker --version" = "allow";
            "docker version" = "allow";
            "docker info" = "allow";
            "docker ps" = "allow";
            "docker ps *" = "allow";
            "docker images" = "allow";
            "docker images *" = "allow";
            "docker logs *" = "allow";
            "docker inspect *" = "allow";
            "docker stats" = "allow";
            "docker stats *" = "allow";
            "docker network ls" = "allow";
            "docker network ls *" = "allow";
            "docker network inspect *" = "allow";
            "docker volume ls" = "allow";
            "docker volume ls *" = "allow";
            "docker volume inspect *" = "allow";
            "docker top *" = "allow";
            "docker port *" = "allow";
            "docker diff *" = "allow";
            "docker history *" = "allow";
            "docker search *" = "allow";
            "docker-compose --version" = "allow";
            "docker-compose config*" = "allow";
            "docker compose --version" = "allow";
            "docker compose config*" = "allow";

            # Docker - ask: container operations
            "docker build *" = "ask";
            "docker run *" = "ask";
            "docker exec *" = "ask";
            "docker stop *" = "ask";
            "docker start *" = "ask";
            "docker restart *" = "ask";
            "docker kill *" = "ask";
            "docker pause *" = "ask";
            "docker unpause *" = "ask";
            "docker pull *" = "ask";
            "docker push *" = "ask";
            "docker tag *" = "ask";
            "docker create *" = "ask";
            "docker commit *" = "ask";
            "docker cp *" = "ask";
            "docker-compose up*" = "ask";
            "docker-compose down*" = "ask";
            "docker compose up*" = "ask";
            "docker compose down*" = "ask";

            # ══════════════════════════════════════════════════════════════
            # Build tools - version checks and read-only inspection
            # ══════════════════════════════════════════════════════════════
            "autoconf --version" = "allow";
            "automake --version" = "allow";
            "make --version" = "allow";
            "make -n*" = "allow";
            "cmake --version" = "allow";
            "cmake -E capabilities" = "allow";
            "meson --version" = "allow";
            "ninja --version" = "allow";
            "clang --version" = "allow";
            "clang++ --version" = "allow";
            "clang-tidy --version" = "allow";
            "clang-format --version" = "allow";
            "clangd --version" = "allow";
            "gcc --version" = "allow";
            "g++ --version" = "allow";
            "ldd" = "allow";
            "ldd *" = "allow";
            "pkg-config *" = "allow";
            "pkgconf *" = "allow";
            "ar --version" = "allow";
            "ranlib --version" = "allow";
            "objdump" = "allow";
            "objdump *" = "allow";
            "nm" = "allow";
            "nm *" = "allow";
            "readelf" = "allow";
            "readelf *" = "allow";

            # Build tools - ask: configuration and builds
            "./configure*" = "ask";
            "configure *" = "ask";
            "autoreconf*" = "ask";
            "autoconf *" = "ask";
            "automake *" = "ask";
            "make" = "ask";
            "make *" = "ask";
            "cmake *" = "ask";
            "meson *" = "ask";
            "ninja" = "ask";
            "ninja *" = "ask";
            "clang *" = "ask";
            "clang++ *" = "ask";
            "gcc *" = "ask";
            "g++ *" = "ask";
            "ar *" = "ask";
            "ranlib *" = "ask";
            "clang-tidy *" = "ask";
            "clang-format *" = "ask";

            # ══════════════════════════════════════════════════════════════
            # FFmpeg - info and probing
            # ══════════════════════════════════════════════════════════════
            "ffmpeg -version" = "allow";
            "ffmpeg -formats" = "allow";
            "ffmpeg -codecs" = "allow";
            "ffmpeg -encoders" = "allow";
            "ffmpeg -decoders" = "allow";
            "ffmpeg -bsfs" = "allow";
            "ffmpeg -protocols" = "allow";
            "ffmpeg -pix_fmts" = "allow";
            "ffmpeg -layouts" = "allow";
            "ffmpeg -sample_fmts" = "allow";
            "ffmpeg -filters" = "allow";
            "ffmpeg -hwaccels" = "allow";
            "ffprobe *" = "allow";

            # FFmpeg - ask: file processing
            "ffmpeg *" = "ask";

            # ══════════════════════════════════════════════════════════════
            # GitHub CLI - deny destructive first
            # ══════════════════════════════════════════════════════════════
            "gh repo delete*" = "deny";
            "gh release delete*" = "deny";
            "gh gist delete*" = "deny";

            # GitHub CLI - read-only queries
            "gh --version" = "allow";
            "gh auth status*" = "allow";
            "gh status" = "allow";
            "gh status *" = "allow";
            "gh repo view*" = "allow";
            "gh repo list*" = "allow";
            "gh pr view*" = "allow";
            "gh pr list*" = "allow";
            "gh pr status*" = "allow";
            "gh pr diff*" = "allow";
            "gh pr checks*" = "allow";
            "gh issue view*" = "allow";
            "gh issue list*" = "allow";
            "gh issue status*" = "allow";
            "gh run view*" = "allow";
            "gh run list*" = "allow";
            "gh workflow view*" = "allow";
            "gh workflow list*" = "allow";
            "gh release view*" = "allow";
            "gh release list*" = "allow";
            "gh gist view*" = "allow";
            "gh gist list*" = "allow";
            "gh api *" = "allow";
            "gh search *" = "allow";

            # GitHub CLI - ask: state modifications
            "gh pr create*" = "ask";
            "gh pr merge*" = "ask";
            "gh pr close*" = "ask";
            "gh pr reopen*" = "ask";
            "gh pr checkout*" = "ask";
            "gh pr review*" = "ask";
            "gh pr edit*" = "ask";
            "gh pr comment*" = "ask";
            "gh issue create*" = "ask";
            "gh issue close*" = "ask";
            "gh issue reopen*" = "ask";
            "gh issue edit*" = "ask";
            "gh issue comment*" = "ask";
            "gh repo create*" = "ask";
            "gh repo clone*" = "ask";
            "gh repo fork*" = "ask";
            "gh repo edit*" = "ask";
            "gh release create*" = "ask";
            "gh release edit*" = "ask";
            "gh run rerun*" = "ask";
            "gh run cancel*" = "ask";
            "gh workflow run*" = "ask";
            "gh gist create*" = "ask";
            "gh gist edit*" = "ask";

            # ══════════════════════════════════════════════════════════════
            # Git - deny destructive first
            # ══════════════════════════════════════════════════════════════
            "git reset --hard*" = "deny";
            "git clean*" = "deny";
            "git filter-branch*" = "deny";
            "git filter-repo*" = "deny";
            "git reflog expire*" = "deny";

            # Git - read-only queries
            "git status" = "allow";
            "git status *" = "allow";
            "git diff" = "allow";
            "git diff *" = "allow";
            "git log" = "allow";
            "git log *" = "allow";
            "git show" = "allow";
            "git show *" = "allow";
            "git branch" = "allow";
            "git branch -a*" = "allow";
            "git branch -v*" = "allow";
            "git branch -r*" = "allow";
            "git branch --list*" = "allow";
            "git branch --contains*" = "allow";
            "git branch --merged*" = "allow";
            "git branch --no-merged*" = "allow";
            "git remote" = "allow";
            "git remote *" = "allow";
            "git tag" = "allow";
            "git tag -l*" = "allow";
            "git tag --list*" = "allow";
            "git stash list*" = "allow";
            "git stash show*" = "allow";
            "git reflog" = "allow";
            "git reflog *" = "allow";
            "git rev-parse *" = "allow";
            "git describe *" = "allow";
            "git shortlog *" = "allow";
            "git blame *" = "allow";
            "git ls-files" = "allow";
            "git ls-files *" = "allow";
            "git ls-tree *" = "allow";
            "git ls-remote *" = "allow";
            "git grep *" = "allow";
            "git config --list*" = "allow";
            "git config --get*" = "allow";
            "git worktree list" = "allow";
            "git name-rev *" = "allow";
            "git cat-file *" = "allow";
            "git count-objects*" = "allow";
            "git for-each-ref *" = "allow";
            "git symbolic-ref *" = "allow";
            "git verify-commit *" = "allow";
            "git verify-tag *" = "allow";

            # Git - ask: state modifications
            "git add *" = "ask";
            "git commit" = "ask";
            "git commit *" = "ask";
            "git push" = "ask";
            "git push *" = "ask";

            # Force push - explicit deny (must come AFTER general push patterns)
            "git push*--force*" = "deny";
            "git push*-f *" = "deny";
            "git push * --force*" = "deny";
            "git push * -f*" = "deny";

            "git pull" = "ask";
            "git pull *" = "ask";
            "git fetch" = "ask";
            "git fetch *" = "ask";
            "git checkout *" = "ask";
            "git switch *" = "ask";
            "git branch -d *" = "ask";
            "git branch -D *" = "ask";
            "git branch -m *" = "ask";
            "git branch -M *" = "ask";
            "git branch --set-upstream*" = "ask";
            "git branch *" = "ask";
            "git merge *" = "ask";
            "git rebase *" = "ask";
            "git cherry-pick *" = "ask";
            "git stash" = "ask";
            "git stash *" = "ask";
            "git restore *" = "ask";
            "git reset *" = "ask";
            "git revert *" = "ask";
            "git tag -a *" = "ask";
            "git tag -d *" = "ask";
            "git tag -s *" = "ask";
            "git tag *" = "ask";
            "git worktree add *" = "ask";
            "git worktree remove *" = "ask";
            "git worktree prune*" = "ask";
            "git am *" = "ask";
            "git apply *" = "ask";
            "git bisect *" = "ask";
            "git clone *" = "ask";
            "git config *" = "ask";
            "git init*" = "ask";
            "git mv *" = "ask";
            "git rm *" = "ask";
            "git submodule *" = "ask";

            # ══════════════════════════════════════════════════════════════
            # Hugo
            # ══════════════════════════════════════════════════════════════
            "hugo version" = "allow";
            "hugo env" = "allow";
            "hugo env *" = "allow";
            "hugo list *" = "allow";
            "hugo config*" = "allow";

            "hugo" = "ask";
            "hugo *" = "ask";

            # ══════════════════════════════════════════════════════════════
            # ImageMagick
            # ══════════════════════════════════════════════════════════════
            "identify" = "allow";
            "identify *" = "allow";
            "convert --version" = "allow";
            "magick --version" = "allow";
            "magick identify *" = "allow";
            "compare --version" = "allow";
            "composite --version" = "allow";
            "mogrify --version" = "allow";

            "convert *" = "ask";
            "magick *" = "ask";
            "mogrify *" = "ask";
            "compare *" = "ask";
            "composite *" = "ask";

            # ══════════════════════════════════════════════════════════════
            # Nix - deny garbage collection first
            # ══════════════════════════════════════════════════════════════
            "nix-collect-garbage" = "deny";
            "nix-collect-garbage *" = "deny";
            "nix store gc*" = "deny";
            "nix store delete*" = "deny";

            # Nix - read-only info and evaluation
            "nix --version" = "allow";
            "nix flake show*" = "allow";
            "nix flake check*" = "allow";
            "nix flake metadata*" = "allow";
            "nix flake info*" = "allow";
            "nix eval *" = "allow";
            "nix search *" = "allow";
            "nix path-info *" = "allow";
            "nix why-depends *" = "allow";
            "nix derivation show *" = "allow";
            "nix store ls *" = "allow";
            "nix hash *" = "allow";
            "nix-instantiate" = "allow";
            "nix-instantiate *" = "allow";
            "nix repl" = "allow";
            "nix repl *" = "allow";
            "nix log *" = "allow";
            "nix show-config" = "allow";
            "nix show-config *" = "allow";
            "nix doctor" = "allow";
            "nix store verify *" = "allow";
            "nix-store --query *" = "allow";
            "nix-store -q *" = "allow";
            "nixfmt" = "allow";
            "nixfmt *" = "allow";
            "statix *" = "allow";
            "deadnix *" = "allow";
            "alejandra *" = "allow";

            # Nix - ask: builds and environment changes
            "nix build*" = "ask";
            "nix develop*" = "ask";
            "nix run *" = "ask";
            "nix shell *" = "ask";
            "nix flake update*" = "ask";
            "nix flake lock*" = "ask";
            "nix profile *" = "ask";
            "nix-shell" = "ask";
            "nix-shell *" = "ask";
            "nix-build *" = "ask";
            "nix-env *" = "ask";
            "home-manager *" = "ask";
            "nixos-rebuild *" = "ask";
            "darwin-rebuild *" = "ask";

            # ══════════════════════════════════════════════════════════════
            # Cloudflare Wrangler - deny deletion first
            # ══════════════════════════════════════════════════════════════
            "wrangler delete*" = "deny";

            "wrangler --version" = "allow";
            "wrangler whoami" = "allow";
            "wrangler *" = "ask";

            # ══════════════════════════════════════════════════════════════
            # Go
            # ══════════════════════════════════════════════════════════════
            "go version" = "allow";
            "go env" = "allow";
            "go env *" = "allow";
            "go list *" = "allow";
            "go vet" = "allow";
            "go vet *" = "allow";
            "go doc *" = "allow";
            "go mod graph" = "allow";
            "go mod graph *" = "allow";
            "go mod why *" = "allow";
            "go mod verify" = "allow";
            "go mod download" = "allow";
            "go mod download *" = "allow";
            "go help *" = "allow";

            "go build*" = "ask";
            "go run *" = "ask";
            "go test*" = "ask";
            "go generate*" = "ask";
            "go get *" = "ask";
            "go install *" = "ask";
            "go mod tidy*" = "ask";
            "go mod init*" = "ask";
            "go mod edit*" = "ask";
            "go work *" = "ask";
            "go fmt *" = "ask";
            "gofmt *" = "ask";

            # ══════════════════════════════════════════════════════════════
            # JavaScript/TypeScript - deny cache corruption first
            # ══════════════════════════════════════════════════════════════
            "npm cache clean --force*" = "deny";
            "npm cache clean -f*" = "deny";
            "pnpm store prune*" = "deny";
            "yarn cache clean*" = "deny";

            # JavaScript/TypeScript - read-only
            "node --version" = "allow";
            "node -v" = "allow";
            "npm --version" = "allow";
            "npm -v" = "allow";
            "npm ls" = "allow";
            "npm ls *" = "allow";
            "npm list *" = "allow";
            "npm outdated" = "allow";
            "npm outdated *" = "allow";
            "npm view *" = "allow";
            "npm info *" = "allow";
            "npm search *" = "allow";
            "npm explain *" = "allow";
            "npm audit" = "allow";
            "npm audit *" = "allow";
            "npm doctor" = "allow";
            "npm config list*" = "allow";
            "npm config get*" = "allow";
            "npm help *" = "allow";
            "npm pack --dry-run*" = "allow";
            "npx --version" = "allow";

            "pnpm --version" = "allow";
            "pnpm -v" = "allow";
            "pnpm ls*" = "allow";
            "pnpm list*" = "allow";
            "pnpm outdated*" = "allow";
            "pnpm audit*" = "allow";
            "pnpm why *" = "allow";

            "yarn --version" = "allow";
            "yarn -v" = "allow";
            "yarn list*" = "allow";
            "yarn info *" = "allow";
            "yarn why *" = "allow";

            "tsc --version" = "allow";
            "tsc --noEmit*" = "allow";

            # JavaScript/TypeScript - ask: installs and execution
            "npm install*" = "ask";
            "npm i" = "ask";
            "npm i *" = "ask";
            "npm ci*" = "ask";
            "npm run *" = "ask";
            "npm test*" = "ask";
            "npm start*" = "ask";
            "npm exec *" = "ask";
            "npm publish*" = "ask";
            "npm uninstall*" = "ask";
            "npm update*" = "ask";
            "npm link*" = "ask";
            "npx *" = "ask";

            "pnpm install*" = "ask";
            "pnpm i" = "ask";
            "pnpm i *" = "ask";
            "pnpm run *" = "ask";
            "pnpm test*" = "ask";
            "pnpm exec *" = "ask";
            "pnpm dlx *" = "ask";
            "pnpm add *" = "ask";
            "pnpm remove *" = "ask";

            "yarn install*" = "ask";
            "yarn add *" = "ask";
            "yarn remove *" = "ask";
            "yarn run *" = "ask";

            "tsc" = "ask";
            "tsc *" = "ask";
            "vite*" = "ask";

            # ══════════════════════════════════════════════════════════════
            # Just - listing is safe, execution is not
            # ══════════════════════════════════════════════════════════════
            "just --version" = "allow";
            "just --list" = "allow";
            "just --list *" = "allow";
            "just -l" = "allow";
            "just -l *" = "allow";
            "just --summary" = "allow";
            "just --summary *" = "allow";
            "just --evaluate*" = "allow";
            "just --show *" = "allow";
            "just eval" = "allow";
            "just build" = "allow";

            "just" = "ask";
            "just *" = "ask";

            # ══════════════════════════════════════════════════════════════
            # Lua and LÖVE
            # ══════════════════════════════════════════════════════════════
            "lua -v" = "allow";
            "love --version" = "allow";

            "lua" = "ask";
            "lua *" = "ask";
            "love *" = "ask";
            "luarocks *" = "ask";

            # ══════════════════════════════════════════════════════════════
            # Rust
            # ══════════════════════════════════════════════════════════════
            "cargo --version" = "allow";
            "cargo version" = "allow";
            "cargo check" = "allow";
            "cargo check *" = "allow";
            "cargo clippy" = "allow";
            "cargo clippy *" = "allow";
            "cargo doc" = "allow";
            "cargo doc *" = "allow";
            "cargo tree" = "allow";
            "cargo tree *" = "allow";
            "cargo metadata" = "allow";
            "cargo metadata *" = "allow";
            "cargo search *" = "allow";
            "cargo fmt --check*" = "allow";
            "cargo verify-project*" = "allow";
            "cargo locate-project*" = "allow";
            "cargo pkgid*" = "allow";
            "cargo read-manifest*" = "allow";
            "rustc --version" = "allow";
            "rustc --print *" = "allow";
            "rustup --version" = "allow";
            "rustup show*" = "allow";
            "rustup target list*" = "allow";
            "rustup component list*" = "allow";
            "rustup which *" = "allow";

            "cargo build*" = "ask";
            "cargo test*" = "ask";
            "cargo run*" = "ask";
            "cargo bench*" = "ask";
            "cargo install*" = "ask";
            "cargo uninstall*" = "ask";
            "cargo publish*" = "ask";
            "cargo update*" = "ask";
            "cargo add *" = "ask";
            "cargo remove *" = "ask";
            "cargo init*" = "ask";
            "cargo new *" = "ask";
            "cargo fmt" = "ask";
            "cargo fmt *" = "ask";
            "cargo fix*" = "ask";
            "cargo generate*" = "ask";
            "rustup update*" = "ask";
            "rustup default *" = "ask";
            "rustup toolchain *" = "ask";
            "rustup override *" = "ask";

            # ══════════════════════════════════════════════════════════════
            # Python
            # ══════════════════════════════════════════════════════════════
            "python --version" = "allow";
            "python -V" = "allow";
            "python3 --version" = "allow";
            "python3 -V" = "allow";
            "pip --version" = "allow";
            "pip -V" = "allow";
            "pip list" = "allow";
            "pip list *" = "allow";
            "pip show *" = "allow";
            "pip freeze" = "allow";
            "pip freeze *" = "allow";
            "pip check" = "allow";
            "pip index versions *" = "allow";
            "pip search *" = "allow";
            "pip help *" = "allow";

            "uv --version" = "allow";
            "uv pip list" = "allow";
            "uv pip list *" = "allow";
            "uv pip show *" = "allow";
            "uv pip freeze*" = "allow";
            "uv pip check*" = "allow";

            "pytest --version" = "allow";
            "pytest --collect-only*" = "allow";
            "python -m pytest --collect-only*" = "allow";
            "python3 -m pytest --collect-only*" = "allow";

            "mypy --version" = "allow";
            "ruff --version" = "allow";
            "ruff check" = "allow";
            "ruff check *" = "allow";
            "ruff rule *" = "allow";
            "black --version" = "allow";
            "black --check *" = "allow";
            "isort --version" = "allow";
            "isort --check*" = "allow";
            "isort --diff *" = "allow";

            "python" = "ask";
            "python *" = "ask";
            "python3" = "ask";
            "python3 *" = "ask";
            "pip install*" = "ask";
            "pip uninstall*" = "ask";
            "pip download*" = "ask";

            "uv pip install*" = "ask";
            "uv pip uninstall*" = "ask";
            "uv sync*" = "ask";
            "uv run *" = "ask";
            "uv venv*" = "ask";
            "uv lock*" = "ask";
            "uv add *" = "ask";
            "uv remove *" = "ask";

            "pytest" = "ask";
            "pytest *" = "ask";
            "python -m pytest*" = "ask";
            "python3 -m pytest*" = "ask";
            "mypy" = "ask";
            "mypy *" = "ask";
            "ruff" = "ask";
            "ruff *" = "ask";
            "black *" = "ask";
            "isort *" = "ask";

            # ══════════════════════════════════════════════════════════════
            # Svelte/SvelteKit
            # ══════════════════════════════════════════════════════════════
            "svelte-check --help" = "allow";
            "svelte-check --version" = "allow";

            "svelte-kit sync*" = "ask";
            "svelte-check" = "ask";
            "svelte-check *" = "ask";
            "svelte-kit *" = "ask";

            # ══════════════════════════════════════════════════════════════
            # Wails
            # ══════════════════════════════════════════════════════════════
            "wails --version" = "allow";
            "wails doctor" = "allow";
            "wails doctor *" = "allow";

            "wails build*" = "ask";
            "wails dev*" = "ask";
            "wails init*" = "ask";
            "wails generate*" = "ask";

            # ══════════════════════════════════════════════════════════════
            # CATCH-ALL: Unknown commands require approval
            # Must come BEFORE deny rules in Nix, but will be processed
            # first by opencode's .findLast() matching
            # ══════════════════════════════════════════════════════════════
            "*" = "ask";

            # ══════════════════════════════════════════════════════════════
            # GLOBAL OVERRIDES - MUST BE LAST (highest priority with .findLast())
            # These rules match last and override earlier patterns
            # ══════════════════════════════════════════════════════════════

            # File deletion (supervised - prompts for confirmation)
            "rm" = "ask";
            "rm *" = "ask";
            "rmdir *" = "ask";

            # Destructive operations (denied - unrecoverable or bypass deletion)
            "dd *" = "deny";
            "shred *" = "deny";
            "wipe *" = "deny";
            "srm *" = "deny";
            "truncate *" = "deny";

            # Privilege escalation
            "sudo" = "deny";
            "sudo *" = "deny";

            # Subshell execution bypasses (arbitrary code execution)
            "bash -c*" = "deny";
            "sh -c*" = "deny";
            "fish -c*" = "deny";
            "zsh -c*" = "deny";
            "dash -c*" = "deny";

            # Direct code execution via interpreters
            "python -c*" = "deny";
            "python3 -c*" = "deny";
            "python2 -c*" = "deny";
            "node -e*" = "deny";
            "node --eval*" = "deny";
            "perl -e*" = "deny";
            "ruby -e*" = "deny";
            "lua -e*" = "deny";
            "php -r*" = "deny";

            # System modification
            "sysctl *" = "deny";
            "modprobe *" = "deny";
            "insmod *" = "deny";
            "rmmod *" = "deny";

            # Boot/firmware
            "grub-install *" = "deny";
            "update-grub *" = "deny";
            "efibootmgr *" = "deny";

            # Disk operations
            "fdisk *" = "deny";
            "parted *" = "deny";
            "gparted *" = "deny";
            "mkfs*" = "deny";
            "mkswap *" = "deny";
            "swapon *" = "deny";
            "swapoff *" = "deny";
            "mount *" = "deny";
            "umount *" = "deny";
          };
          task = "allow"; # Launching subagents
          skill = "ask"; # Loading agent skills
          todowrite = "allow"; # Modifying todo lists
          webfetch = "allow"; # Fetching URLs
          websearch = "allow"; # Web searches
          codesearch = "allow"; # Code searches
          # Safety guards - always ask
          doom_loop = "ask"; # Repeated identical tool calls

          # External directory access - granular control
          # Triggered when accessing files outside the project directory
          external_directory = {
            # ══════════════════════════════════════════════════════════════
            # ALLOW: Safe read-only system directories
            # ══════════════════════════════════════════════════════════════
            "/tmp/*" = "allow";
            "/usr/share/*" = "allow";
            "/usr/local/share/*" = "allow";
            "/var/log/*" = "allow";

            # ALLOW: Nix store (read-only by nature)
            "/nix/store/*" = "allow";

            # ALLOW: User cache and data directories (fully qualified paths)
            "${config.xdg.cacheHome}/*" = "allow";
            "${config.xdg.dataHome}/*" = "allow";

            # ALLOW: Non-sensitive config directories (fully qualified paths)
            "${config.xdg.configHome}/*" = "allow"; # General config (but SSH/GPG denied by read rules)

            # ══════════════════════════════════════════════════════════════
            # CATCHALL: Prompt for other external directories
            # ══════════════════════════════════════════════════════════════
            "*" = "ask";

            # ══════════════════════════════════════════════════════════════
            # DENY: Sensitive system directories (highest priority - LAST)
            # ══════════════════════════════════════════════════════════════
            "/etc/shadow" = "deny";
            "/etc/gshadow" = "deny";
            "/etc/sudoers" = "deny";
            "/etc/sudoers.d/*" = "deny";
            "/root/*" = "deny";
            "/boot/*" = "deny";

            # DENY: Sensitive user directories (fully qualified paths - defense-in-depth)
            # Match parent directory patterns that Read tool checks
            "${config.home.homeDirectory}/.ssh" = "deny";
            "${config.home.homeDirectory}/.ssh/*" = "deny";
            "${config.home.homeDirectory}/.gnupg" = "deny";
            "${config.home.homeDirectory}/.gnupg/*" = "deny";
            "${config.home.homeDirectory}/.aws" = "deny";
            "${config.home.homeDirectory}/.aws/*" = "deny";
            "${config.home.homeDirectory}/.azure" = "deny";
            "${config.home.homeDirectory}/.azure/*" = "deny";
            "${config.xdg.configHome}/gcloud" = "deny";
            "${config.xdg.configHome}/gcloud/*" = "deny";
            "${config.home.homeDirectory}/.docker" = "deny";
            "${config.home.homeDirectory}/.docker/*" = "deny";
            "${config.home.homeDirectory}/.kube" = "deny";
            "${config.home.homeDirectory}/.kube/*" = "deny";
            "${config.xdg.configHome}/gh" = "deny";
            "${config.xdg.configHome}/gh/*" = "deny";
            "${config.home.homeDirectory}/.git-credentials" = "deny";
            "${config.home.homeDirectory}/.netrc" = "deny";
          };
        };
      };
    };
    vscode = lib.mkIf config.programs.vscode.enable {
      profiles.default = {
        extensions = with pkgs; [
          vscode-marketplace.sst-dev.opencode
        ];
      };
    };
    zed-editor = lib.mkIf config.programs.zed-editor.enable {
      extensions = [
        "opencode"
      ];
      userKeymaps = [
        {
          bindings = {
            "ctrl-alt-shift-c" = [
              "agent::NewExternalAgentThread"
              { agent = "claude_code"; }
            ];
            "ctrl-alt-shift-p" = [
              "agent::NewExternalAgentThread"
              {
                agent = {
                  custom = {
                    name = "OpenCode";
                    command = {
                      command = "opencode";
                      args = [ "acp" ];
                    };
                  };
                };
              }
            ];
          };
        }
      ];
      userSettings = {
        agent_servers = {
          OpenCode = {
            type = "custom";
            command = "opencode";
            args = [ "acp" ];
            env = { };
          };
        };
      };
    };
  };
}
