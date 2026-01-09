{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
  installFor = [ "martin" ];
  opencodePackage =
    if isLinux then
      inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    else if isDarwin then
      pkgs.unstable.opencode
    else
      pkgs.opencode;
in
lib.mkIf (lib.elem username installFor) {
  home.file."${config.xdg.configHome}/zed/keymap.json" = lib.mkIf config.programs.zed-editor.enable {
    text = builtins.toJSON [
      {
        bindings = {
          "cmd-alt-o" = [
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
  };

  programs = {
    opencode = {
      enable = true;
      package = opencodePackage;
      settings = {
        theme = "catppuccin";
        # Global permissions - applied to all agents including built-in Build and Plan
        # These provide guardrails across the board
        permission = {
          # Safe operations - allow without prompting
          read = "allow"; # Reading files
          glob = "allow"; # Finding files by pattern
          grep = "allow"; # Searching file contents
          list = "allow"; # Listing directories
          todoread = "allow"; # Reading todo lists
          lsp = "allow"; # Language server queries
          # Potentially destructive operations - require approval
          edit = "allow"; # All file modifications (edit, write, patch)
          bash = {
            # CATCH-ALL: Unknown commands require approval
            # ============================================================
            "*" = "ask";

            # Shell
            # ============================================================
            # allow: read-only and low-risk
            "ls" = "allow";
            "cat" = "allow";
            "head" = "allow";
            "tail" = "allow";
            "wc" = "allow";
            "file" = "allow";
            "tree" = "allow";
            "pwd" = "allow";
            "which" = "allow";
            "type" = "allow";
            "env" = "allow";
            "fd" = "allow";
            "rg" = "allow";
            "mkdir" = "allow";
            "touch" = "allow";
            "whoami" = "allow";
            "hostname" = "allow";
            "uname" = "allow";
            "uname -a" = "allow";
            "df" = "allow";
            "df -h" = "allow";
            "free" = "allow";
            "free -h" = "allow";
            "ps" = "allow";
            "ps aux" = "allow";
            "top -b" = "allow";
            "top -b -n 1" = "allow";
            "uptime" = "allow";
            "date" = "allow";
            "lscpu" = "allow";
            "lsblk" = "allow";
            "lsusb" = "allow";
            "lspci" = "allow";
            "id" = "allow"; # shows user/group IDs
            "groups" = "allow"; # shows group memberships
            "printenv" = "allow";
            "basename" = "allow";
            "dirname" = "allow";
            "realpath" = "allow";
            "stat" = "allow";
            "du" = "allow"; # disk usage (read-only)
            "du -h" = "allow";
            "sort" = "allow"; # sorts stdin, no file modification
            "uniq" = "allow";
            "cut" = "allow";
            "awk" = "allow";
            "diff" = "allow";
            "cmp" = "allow";
            "less" = "allow";
            "more" = "allow";
            "tr" = "allow";
            "tac" = "allow";
            "rev" = "allow";
            "seq" = "allow";
            "md5sum" = "allow";
            "sha256sum" = "allow";
            "shasum" = "allow";
            "jq" = "allow";
            "yq" = "allow";
            "bc" = "allow";
            "man" = "allow";
            "tldr" = "allow";
            "strings" = "allow"; # extract strings from binaries
            # ask: file modification or redirection risk
            "xdg-open" = "ask"; # opens files/URLs with default app
            "sed" = "ask";
            "sd" = "ask"; # modifies files in place
            "mv" = "ask";
            "cp" = "ask";
            "tee" = "ask";
            "echo" = "ask"; # redirection risk
            "printf" = "ask"; # redirection risk
            "curl" = "ask"; # network + file write
            "wget" = "ask"; # network + file write
            "chmod" = "ask";
            "chown" = "ask";
            "kill" = "ask";
            "pkill" = "ask";
            # deny: destructive or privilege escalation
            "rm" = "deny";
            "sudo" = "deny";

            # Systemd service management
            # ============================================================
            # allow: read-only status and log queries
            "systemctl --version" = "allow";
            "systemctl status" = "allow";
            "systemctl is-active" = "allow";
            "systemctl is-enabled" = "allow";
            "systemctl is-failed" = "allow";
            "systemctl list-units" = "allow";
            "systemctl list-unit-files" = "allow";
            "systemctl show" = "allow";
            "systemctl cat" = "allow";
            "journalctl" = "allow";
            "journalctl -u" = "allow";
            "journalctl -f" = "allow";
            "journalctl --no-pager" = "allow";
            "systemd-analyze" = "allow";
            "systemd-analyze blame" = "allow";
            "systemd-analyze critical-chain" = "allow";
            "hostnamectl" = "allow";
            "hostnamectl status" = "allow";
            "timedatectl" = "allow";
            "timedatectl status" = "allow";
            "loginctl" = "allow";
            "loginctl list-sessions" = "allow";
            "localectl" = "allow";
            "localectl status" = "allow";
            "networkctl" = "allow";
            "networkctl status" = "allow";
            "networkctl list" = "allow";
            "resolvectl" = "allow";
            "resolvectl status" = "allow";
            "busctl" = "allow";
            "busctl list" = "allow";
            "busctl tree" = "allow";
            # allow: additional read-only queries
            "systemctl list-dependencies" = "allow"; # unit dependency tree
            "systemctl list-jobs" = "allow"; # pending jobs
            "journalctl --disk-usage" = "allow"; # check journal size
            "coredumpctl" = "allow"; # list coredumps
            "resolvectl query" = "allow"; # DNS queries
            "resolvectl dns" = "allow"; # DNS servers configuration
            # ask: service state modifications
            "systemctl start" = "ask";
            "systemctl stop" = "ask";
            "systemctl restart" = "ask";
            "systemctl reload" = "ask";
            "systemctl enable" = "ask";
            "systemctl disable" = "ask";
            "systemctl mask" = "ask";
            "systemctl unmask" = "ask";
            "systemctl daemon-reload" = "ask";
            "systemctl edit" = "ask";
            # deny: power management
            "systemctl poweroff" = "deny";
            "systemctl reboot" = "deny";
            "systemctl halt" = "deny";
            "systemctl suspend" = "deny";
            "systemctl hibernate" = "deny";

            # Container management
            # ============================================================
            # allow: read-only queries
            "docker --version" = "allow";
            "docker ps" = "allow";
            "docker images" = "allow";
            "docker logs" = "allow";
            "docker inspect" = "allow";
            "docker info" = "allow";
            "docker stats" = "allow";
            "docker network ls" = "allow";
            "docker volume ls" = "allow";
            "docker-compose --version" = "allow";
            "docker compose --version" = "allow";
            # ask: container operations (Dockerfiles run arbitrary code)
            "docker build" = "ask";
            "docker run" = "ask";
            "docker exec" = "ask";
            "docker stop" = "ask";
            "docker start" = "ask";
            "docker-compose up" = "ask";
            "docker-compose down" = "ask";
            "docker pull" = "ask";
            "docker push" = "ask";
            # deny: mass destruction
            "docker system prune" = "deny";
            "docker volume prune" = "deny";
            "docker container prune" = "deny";
            "docker image prune" = "deny";

            # Build tools (autotools, cmake, meson, ninja, clang)
            # ============================================================
            # allow: version checks and info queries
            "autoconf --version" = "allow";
            "automake --version" = "allow";
            "make --version" = "allow";
            "make -n" = "allow"; # shows what would be done without executing
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
            "ldd --version" = "allow"; # library dependency info
            "pkg-config --version" = "allow";
            "pkgconf --version" = "allow";
            "ar --version" = "allow";
            "ranlib --version" = "allow";
            "objdump --version" = "allow";
            "nm --version" = "allow";
            "readelf --version" = "allow";
            # allow: read-only binary inspection
            "objdump" = "allow"; # disassembly/headers
            "nm" = "allow"; # symbol listing
            "readelf" = "allow"; # ELF structure
            "ldd" = "allow"; # shared library deps
            # allow: library discovery (read-only queries)
            "pkg-config" = "allow";
            "pkgconf" = "allow";
            # ask: configuration and builds (configure/cmakelists/build scripts run arbitrary code)
            "./configure" = "ask"; # executes configure script
            "configure" = "ask";
            "autoreconf" = "ask";
            "autoconf" = "ask";
            "automake" = "ask";
            "make" = "ask";
            "make clean" = "ask";
            "make install" = "ask";
            "cmake" = "ask";
            "cmake -E" = "ask";
            "cmake --build" = "ask";
            "cmake --install" = "ask";
            "meson" = "ask";
            "meson setup" = "ask";
            "meson compile" = "ask";
            "meson test" = "ask";
            "meson install" = "ask";
            "meson clean" = "ask";
            "ninja" = "ask";
            "ninja clean" = "ask";
            "clang" = "ask";
            "clang++" = "ask";
            "gcc" = "ask";
            "g++" = "ask";
            # ask: archive manipulation
            "ar" = "ask";
            "ranlib" = "ask";
            # ask: auto-fixing tools (modify files)
            "clang-tidy" = "ask"; # can auto-fix with --fix
            "clang-format" = "ask"; # modifies files

            # FFmpeg media processing
            # ============================================================
            # allow: info, probing, and codec/filter queries
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
            "ffmpeg -loglevel" = "allow";
            "ffmpeg -hwaccels" = "allow"; # list hardware acceleration methods
            "ffprobe" = "allow";
            # ask: file processing (creates/overwrites files)
            "ffmpeg" = "ask";

            # GitHub operations
            # ============================================================
            # allow: read-only queries
            "gh --version" = "allow";
            "gh repo view" = "allow";
            "gh pr view" = "allow";
            "gh pr list" = "allow";
            "gh issue view" = "allow";
            "gh issue list" = "allow";
            "gh status" = "allow";
            # ask: state modifications
            "gh pr create" = "ask";
            "gh pr merge" = "ask";
            "gh pr checkout" = "ask";
            "gh issue create" = "ask";
            "gh release create" = "ask";
            "gh repo create" = "ask";
            "gh repo clone" = "ask";
            # deny: destructive operations
            "gh repo delete" = "deny";

            # Git operations
            # ============================================================
            # allow: read-only queries
            "git status" = "allow";
            "git diff" = "allow";
            "git log" = "allow";
            "git branch" = "allow";
            "git remote" = "allow";
            "git show" = "allow";
            "git stash list" = "allow";
            "git tag" = "allow";
            "git worktree list" = "allow";
            "git config --list" = "allow";
            "git config --get" = "allow";
            "git remote -v" = "allow";
            "git branch -a" = "allow";
            "git reflog" = "allow";
            # ask: state modifications
            "git add" = "ask";
            "git commit" = "ask";
            "git push" = "ask";
            "git pull" = "ask";
            "git fetch" = "ask";
            "git checkout" = "ask";
            "git switch" = "ask";
            "git merge" = "ask";
            "git rebase" = "ask";
            "git stash" = "ask";
            "git restore" = "ask";
            "git cherry-pick" = "ask";
            "git worktree" = "ask"; # add/remove/prune create/delete directories
            "git rev-parse" = "allow"; # get commit hashes, branch info
            "git describe" = "allow"; # version info from tags
            "git shortlog" = "allow"; # summarise commits
            "git blame" = "allow"; # line-by-line history
            "git ls-files" = "allow"; # list tracked files
            "git ls-tree" = "allow"; # list tree contents
            "git grep" = "allow"; # git-specific search
            # deny: history rewriting / destructive
            "git push --force" = "deny";
            "git push -f" = "deny";
            "git reset --hard" = "deny";
            "git clean" = "deny";
            "git filter-branch" = "deny";

            # Hugo static site generator
            # ============================================================
            # allow: info only
            "hugo version" = "allow";
            "hugo env" = "allow";
            # ask: builds and server (creates files)
            "hugo" = "ask";
            "hugo server" = "ask";
            "hugo new" = "ask";

            # ImageMagick image processing
            # ============================================================
            # allow: info, metadata queries, and version checks
            "identify" = "allow";
            "identify -verbose" = "allow";
            "convert --version" = "allow";
            "magick --version" = "allow";
            "magick identify" = "allow";
            "compare --version" = "allow";
            "composite --version" = "allow";
            "mogrify --version" = "allow";
            # ask: file processing (creates/overwrites files)
            "convert" = "ask";
            "magick" = "ask";
            "mogrify" = "ask";
            "compare" = "ask";
            "composite" = "ask";

            # NixOS and Home Manager
            # ============================================================
            # allow: info and evaluation
            "nix --version" = "allow";
            "nix flake show" = "allow";
            "nix flake check" = "allow";
            "nix eval" = "allow";
            "nix search" = "allow";
            "nix-instantiate --parse" = "allow"; # syntax check only, no eval
            "nix flake metadata" = "allow";
            "nix path-info" = "allow";
            "nixfmt --check" = "allow"; # check formatting, no write
            # ask: builds and environment (evaluates derivations)
            "nix build" = "ask";
            "nix develop" = "ask";
            "nix-shell" = "ask";
            "nix flake update" = "ask";
            "nix-env" = "ask";
            "home-manager switch" = "ask";
            "nixos-rebuild" = "ask";
            # deny: garbage collection (can break system)
            "nix-collect-garbage" = "deny";

            # Cloudflare Workers deployment
            # ============================================================
            # allow: info only
            "wrangler --version" = "allow";
            "wrangler whoami" = "allow";
            # ask: development and deployment (pushes to production!)
            "wrangler dev" = "ask";
            "wrangler deploy" = "ask";
            "wrangler publish" = "ask";
            "wrangler secret" = "ask";
            "wrangler kv" = "ask";
            "wrangler r2" = "ask";
            "wrangler d1" = "ask";
            # deny: resource deletion
            "wrangler delete" = "deny";

            # Go language toolchain
            # ============================================================
            # allow: info and static analysis
            "go version" = "allow";
            "go env" = "allow";
            "go list" = "allow";
            "go vet" = "allow";
            "go doc" = "allow";
            "go mod graph" = "allow";
            "go mod why" = "allow";
            # ask: builds and code execution
            "go build" = "ask";
            "go run" = "ask";
            "go test" = "ask";
            "go generate" = "ask"; # runs arbitrary //go:generate commands
            "go get" = "ask"; # downloads + can run code
            "go mod tidy" = "ask";
            "go install" = "ask";

            # JavaScript/TypeScript ecosystem
            # ============================================================
            # allow: info and type checking
            "node --version" = "allow";
            "npm --version" = "allow";
            "pnpm --version" = "allow";
            "npm ls" = "allow";
            "npm outdated" = "allow";
            "npm view" = "allow";
            "npm info" = "allow";
            "npx --version" = "allow";
            "tsc --version" = "allow";
            "tsc --noEmit" = "allow"; # type check only
            # ask: installs (supply chain risk) and execution
            "npm install" = "ask";
            "npm run" = "ask";
            "npm test" = "ask";
            "npm publish" = "ask";
            "pnpm install" = "ask";
            "pnpm run" = "ask";
            "yarn add" = "ask";
            "yarn install" = "ask";
            "vite" = "ask";
            "vite build" = "ask";
            # deny: cache corruption
            "npm cache clean --force" = "deny";

            # Just command runner - CAUTION: recipes are arbitrary shell
            # ============================================================
            # allow: listing only
            "just --version" = "allow";
            "just --list" = "allow";
            "just -l" = "allow";
            "just --summary" = "allow";
            # ask: all recipe execution
            "just" = "ask";

            # Lua ecosystem and LÖVE game framework
            # ============================================================
            # allow: info only
            "lua -v" = "allow";
            "love --version" = "allow";
            # ask: execution and package management
            "lua" = "ask";
            "love" = "ask"; # runs game code
            "luarocks install" = "ask";
            "luarocks remove" = "ask";

            # Rust language toolchain
            # ============================================================
            # allow: info and static analysis
            "cargo --version" = "allow";
            "cargo check" = "allow";
            "cargo clippy" = "allow";
            "cargo doc" = "allow";
            "cargo tree" = "allow";
            "rustc --version" = "allow";
            "rustup --version" = "allow";
            "rustup show" = "allow";
            "rustup target list" = "allow";
            "rustup component list" = "allow";
            "cargo fmt --check" = "allow"; # check formatting, no write
            "cargo metadata" = "allow";
            # ask: builds and code execution (build.rs runs arbitrary code)
            "cargo build" = "ask";
            "cargo test" = "ask";
            "cargo run" = "ask";
            "cargo install" = "ask";
            "cargo publish" = "ask";
            "cargo update" = "ask";
            "rustup update" = "ask";
            "rustup default" = "ask";

            # Python ecosystem
            # ============================================================
            # allow: info and read-only
            "python --version" = "allow";
            "python3 --version" = "allow";
            "pip --version" = "allow";
            "pip list" = "allow";
            "pip show" = "allow";
            "pip freeze" = "allow";
            "pip check" = "allow";
            "pytest --version" = "allow";
            "python -m pytest --collect-only" = "allow";
            "mypy --version" = "allow";
            "ruff --version" = "allow";
            "ruff check" = "allow"; # lint without fixing
            "uv --version" = "allow";
            "uv pip list" = "allow";
            # ask: installs and execution (setup.py runs arbitrary code)
            "pip install" = "ask";
            "pip uninstall" = "ask";
            "python" = "ask";
            "python3" = "ask";
            "pytest" = "ask";
            "mypy" = "ask";
            "ruff" = "ask";
            "uv pip install" = "ask";
            "uv sync" = "ask";
            "uv run" = "ask";

            # Svelte/SvelteKit framework
            # ============================================================
            # allow: info and sync
            "svelte-check --help" = "allow";
            # ask: builds and type checking (may run plugins)
            "svelte-kit sync" = "ask";
            "svelte-check" = "ask";
            "svelte-kit build" = "ask";

            # Wails Go + Web desktop apps
            # ============================================================
            # allow: info only
            "wails --version" = "allow";
            "wails doctor" = "allow";
            # ask: builds and dev server
            "wails build" = "ask";
            "wails dev" = "ask";
            "wails init" = "ask";
          };
          task = "ask"; # Launching subagents
          skill = "ask"; # Loading agent skills
          todowrite = "allow"; # Modifying todo lists
          webfetch = "allow"; # Fetching URLs
          websearch = "allow"; # Web searches
          codesearch = "allow"; # Code searches
          # Safety guards - always ask
          external_directory = "ask"; # Files outside project
          doom_loop = "ask"; # Repeated identical tool calls
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
    };
  };
}
