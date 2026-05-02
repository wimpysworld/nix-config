{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Codex re-execs std::env::current_exe() when launching the Linux sandbox.
  # Nix store paths can disappear after a Home Manager generation switch, and
  # CODEX_HOME/.codex paths are special protected paths inside the Linux
  # sandbox. The interactive entry point must therefore exec a stable
  # user-owned binary copy outside CODEX_HOME.
  # Keep the source package unwrapped so that copied binary remains self-same
  # for arg0 dispatch, including codex-linux-sandbox.
  codexPackage =
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex.overrideAttrs
      (_oldAttrs: {
        postFixup = "";
      });
  codexRuntimePackages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    # Codex's Linux sandbox prefers the first usable bwrap on PATH. Supplying
    # the distro/Nixpkgs build avoids the less predictable vendored fallback.
    pkgs.bubblewrap
    # The Linux sandbox uses rg to expand deny-read globs. Keep it available
    # even though this module currently avoids split filesystem profiles.
    pkgs.ripgrep
  ];

  # ACP adapter that lets Zed drive Codex over the Agent Client Protocol.
  # The binary is `codex-acp`, pinned via the llm-agents flake input so the
  # adapter version stays in lockstep with the codex CLI it speaks to.
  codexAcpPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex-acp;
  codexLegacyDir = "${config.home.homeDirectory}/.codex";
  codexXdgDir = "${config.xdg.configHome}/codex";
  codexStableBin = "${config.xdg.dataHome}/codex/bin/codex";
  codexLegacyStableBin = "${codexLegacyDir}/bin/codex";
  codexXdgStableBin = "${codexXdgDir}/bin/codex";
  codexLauncherPackage = pkgs.writeShellApplication {
    name = "codex";
    text = ''
      if [ -x "${codexStableBin}" ]; then
        exec "${codexStableBin}" "$@"
      fi
      if [ -x "${codexLegacyStableBin}" ]; then
        exec "${codexLegacyStableBin}" "$@"
      fi
      exec "${codexXdgStableBin}" "$@"
    '';
  };
  tomlMergePython = pkgs.python3.withPackages (ps: [ ps.tomli-w ]);

  # Import shared MCP server definitions and translate them into Codex's
  # native config.toml schema.
  mcpServerDefs = import ../mcp/servers.nix {
    inherit config pkgs;
  };
  assistantCompose = import ../assistants/compose.nix { inherit lib; };

  # Determine CODEX_HOME path, mirroring the Home Manager module logic.
  # The HM module sets CODEX_HOME = xdg.configHome/codex when
  # home.preferXdgDirectories is true (and package >= 0.2.0, which it is).
  codexDir = if config.home.preferXdgDirectories then codexXdgDir else codexLegacyDir;

  codexSkillNames =
    let
      sharedSkillNames = builtins.attrNames assistantCompose.skillDirs;
      commandSkillNames = builtins.attrNames assistantCompose.standaloneCommandDirs;
      agentCommandSkillNames = lib.flatten (
        lib.mapAttrsToList (
          agentName: _:
          map (cmdName: "${agentName}-${cmdName}") (
            builtins.attrNames (assistantCompose.discoverAgentCommands agentName)
          )
        ) assistantCompose.agentDirs
      );
    in
    lib.sort (a: b: a < b) (sharedSkillNames ++ commandSkillNames ++ agentCommandSkillNames);

  # Command policy overrides. The generated rules keep an explicit
  # allow/prompt/deny policy shape aligned with Claude Code and OpenCode even
  # though approval_policy = "never" suppresses interactive prompts.
  #
  # Format: each attrset has { pattern = [...]; justification = "..."; }
  allowedRules = [
    {
      pattern = [ "nix-instantiate" ];
      justification = "Nix evaluation and parsing are safe for trusted projects.";
    }
    {
      pattern = [ "nixfmt" ];
      justification = "Nix formatting is an approved project maintenance command.";
    }
    {
      pattern = [
        "nix"
        "help"
      ];
      justification = "Nix help output is read-only.";
    }
    {
      pattern = [
        "nix"
        "help-stores"
      ];
      justification = "Nix store help output is read-only.";
    }
    {
      pattern = [
        "nix"
        "config"
        "show"
      ];
      justification = "Showing the resolved Nix configuration is read-only.";
    }
    {
      pattern = [
        "nix"
        "config"
        "check"
      ];
      justification = "Validating the Nix configuration is read-only.";
    }
    {
      pattern = [
        "nix"
        "store"
        [
          "ping"
          "info"
          "cat"
          "dump-path"
          "diff-closures"
          "path-from-hash-part"
        ]
      ];
      justification = "Read-only Nix store inspection commands.";
    }
    {
      pattern = [
        "nix"
        "nar"
        [
          "ls"
          "cat"
          "dump-path"
        ]
      ];
      justification = "Read-only NAR archive inspection commands.";
    }
    {
      pattern = [
        "nix"
        "profile"
        [
          "list"
          "history"
          "diff-closures"
        ]
      ];
      justification = "Read-only profile inspection commands.";
    }
    {
      pattern = [
        "nix"
        "registry"
        "list"
      ];
      justification = "Listing flake registry entries is read-only.";
    }
    {
      pattern = [
        "nix"
        "print-dev-env"
      ];
      justification = "Printing the development environment is read-only.";
    }
    {
      pattern = [
        "nix"
        "realisation"
        "info"
      ];
      justification = "Realisation information is read-only.";
    }
    {
      pattern = [
        "nix"
        "key"
        "convert-secret-to-public"
      ];
      justification = "Deriving a public key from a secret key prints the public key only.";
    }
    {
      pattern = [
        "nix-store"
        [
          "--read-log"
          "-l"
          "--dump"
          "--verify"
        ]
      ];
      justification = "Read-only legacy nix-store inspection commands.";
    }
    {
      pattern = [ "nix-hash" ];
      justification = "Computing Nix hashes is read-only.";
    }
    {
      pattern = [
        "nix-channel"
        "--list"
      ];
      justification = "Listing Nix channels is read-only.";
    }
    {
      pattern = [ "nix-info" ];
      justification = "Reporting the Nix installation summary is read-only.";
    }
    {
      pattern = [ "nix-tree" ];
      justification = "Browsing the Nix store dependency tree is read-only.";
    }
    {
      pattern = [ "nix-diff" ];
      justification = "Diffing two Nix derivations is read-only.";
    }
    {
      pattern = [ "nvd" ];
      justification = "Comparing Nix package versions is read-only.";
    }

    # GitHub - read-only queries
    {
      pattern = [
        "gh"
        "search"
      ];
      justification = "GitHub search queries are read-only.";
    }

    # Read-only filesystem inspection.
    {
      pattern = [ "readlink" ];
      justification = "Reading symlink targets is read-only.";
    }

    # Build tools - configuration, builds, and compilation. Workspace edits
    # are bounded by the workspace-write sandbox; out-of-tree installation
    # (`make install`, `cmake --install`) is intentionally still routed
    # through prompt rules below.
    {
      pattern = [ "./configure" ];
      justification = "Build configuration scripts produce workspace artefacts.";
    }
    {
      pattern = [ "configure" ];
      justification = "Build configuration scripts produce workspace artefacts.";
    }
    {
      pattern = [ "autoreconf" ];
      justification = "Build system regeneration writes inside the workspace.";
    }
    {
      pattern = [ "autoconf" ];
      justification = "Build system regeneration writes inside the workspace.";
    }
    {
      pattern = [ "automake" ];
      justification = "Build system regeneration writes inside the workspace.";
    }
    {
      pattern = [ "make" ];
      justification = "Build commands write inside the workspace; `make install` is still prompted.";
    }
    {
      pattern = [ "cmake" ];
      justification = "Build commands write inside the workspace; `cmake --install` is still prompted.";
    }
    {
      pattern = [ "meson" ];
      justification = "Build commands write inside the workspace.";
    }
    {
      pattern = [ "ninja" ];
      justification = "Build commands write inside the workspace.";
    }
    {
      pattern = [ "clang" ];
      justification = "Compilation produces workspace artefacts.";
    }
    {
      pattern = [ "clang++" ];
      justification = "Compilation produces workspace artefacts.";
    }
    {
      pattern = [ "gcc" ];
      justification = "Compilation produces workspace artefacts.";
    }
    {
      pattern = [ "g++" ];
      justification = "Compilation produces workspace artefacts.";
    }
    {
      pattern = [ "ar" ];
      justification = "Archive creation writes inside the workspace.";
    }
    {
      pattern = [ "ranlib" ];
      justification = "Archive index updates write inside the workspace.";
    }
    {
      pattern = [ "clang-tidy" ];
      justification = "clang-tidy edits and reports run inside the workspace.";
    }
    {
      pattern = [ "clang-format" ];
      justification = "clang-format rewrites are workspace-bounded.";
    }

    # Per-language test, build, and format runners. Splitting these out of
    # the parent prompt rules below lets Codex's `Forbidden > Prompt > Allow`
    # ordering match each more-specific allow without the parent prompt
    # winning. See the comment near the parent rules for the full rationale.
    {
      pattern = [
        "go"
        "build"
      ];
      justification = "Go builds produce workspace artefacts.";
    }
    {
      pattern = [
        "go"
        "test"
      ];
      justification = "Go test runs project test code inside the workspace.";
    }
    {
      pattern = [
        "go"
        "fmt"
      ];
      justification = "go fmt rewrites are workspace-bounded.";
    }
    {
      pattern = [ "gofmt" ];
      justification = "gofmt rewrites are workspace-bounded.";
    }
    {
      pattern = [
        "cargo"
        "build"
      ];
      justification = "Cargo builds produce workspace artefacts.";
    }
    {
      pattern = [
        "cargo"
        "test"
      ];
      justification = "Cargo test runs project test code inside the workspace.";
    }
    {
      pattern = [
        "cargo"
        "fmt"
      ];
      justification = "cargo fmt rewrites are workspace-bounded.";
    }
    {
      pattern = [
        "npm"
        "test"
      ];
      justification = "npm test runs project test code inside the workspace.";
    }
    {
      pattern = [
        "pnpm"
        "test"
      ];
      justification = "pnpm test runs project test code inside the workspace.";
    }

    # Python test, lint, and formatter runners. The parent `[ "python" ]` and
    # `[ "python3" ]` prompt rules have been removed (see comment in the
    # promptRules block) so these specific allows are the only matches.
    {
      pattern = [
        "python"
        "-m"
        "pytest"
      ];
      justification = "pytest runs project test code inside the workspace.";
    }
    {
      pattern = [
        "python3"
        "-m"
        "pytest"
      ];
      justification = "pytest runs project test code inside the workspace.";
    }
    {
      pattern = [ "pytest" ];
      justification = "pytest runs project test code inside the workspace.";
    }
    {
      pattern = [ "mypy" ];
      justification = "mypy is read-only type-checking.";
    }
    {
      pattern = [ "ruff" ];
      justification = "ruff is workspace-bounded; `ruff format` and `ruff check --fix` rewrite project files.";
    }
    {
      pattern = [ "black" ];
      justification = "black rewrites are workspace-bounded.";
    }
    {
      pattern = [ "isort" ];
      justification = "isort rewrites are workspace-bounded.";
    }
    {
      pattern = [ "shfmt" ];
      justification = "shfmt rewrites are workspace-bounded.";
    }

    # svelte-check is read-only.
    {
      pattern = [ "svelte-check" ];
      justification = "svelte-check is read-only type-checking.";
    }

    # ffmpeg is allowed broadly; the workspace-write sandbox is the actual
    # security boundary. ffmpeg can read/write network protocols (http://,
    # ftp://, rtmp://, etc.) and arbitrary filesystem paths, so this rule
    # does not by itself contain media processing - sandbox containment does.
    {
      pattern = [ "ffmpeg" ];
      justification = "Media processing in workspace-bounded sandbox.";
    }

    # `git -C <path> <subcommand>` for read-only subcommands cannot be
    # expressed as a prefix_rule: Codex's prefix patterns are positional and
    # offer no wildcard token between literals to skip over the path
    # argument. Read-only git inspection through `-C` therefore falls back to
    # Codex's prompt heuristics; auto-approval lives only in OpenCode and the
    # Claude Code auto-approve hook.
  ];

  promptRules = [
    # Shell - file modification, redirection, network, or process risk
    {
      pattern = [ "xdg-open" ];
      justification = "Opening local desktop handlers requires approval.";
    }
    {
      pattern = [ "sed" ];
      justification = "sed can modify files in-place or hide redirection through shell wrappers.";
    }
    {
      pattern = [ "sd" ];
      justification = "sd can modify files in-place.";
    }
    {
      pattern = [ "mkdir" ];
      justification = "Directory creation changes the filesystem.";
    }
    {
      pattern = [ "touch" ];
      justification = "Touching files changes timestamps or creates files.";
    }
    {
      pattern = [ "mv" ];
      justification = "Moving files changes the filesystem.";
    }
    {
      pattern = [ "cp" ];
      justification = "Copying files can overwrite existing files.";
    }
    {
      pattern = [ "tee" ];
      justification = "tee can write or overwrite files.";
    }
    {
      pattern = [ "echo" ];
      justification = "echo can write files through shell redirection.";
    }
    {
      pattern = [ "printf" ];
      justification = "printf can write files through shell redirection.";
    }
    {
      pattern = [ "curl" ];
      justification = "Network fetches and uploads require approval.";
    }
    {
      pattern = [ "wget" ];
      justification = "Network fetches require approval.";
    }
    {
      pattern = [ "chmod" ];
      justification = "Permission changes require approval.";
    }
    {
      pattern = [ "chown" ];
      justification = "Ownership changes require approval.";
    }
    {
      pattern = [ "kill" ];
      justification = "Terminating processes requires approval.";
    }
    {
      pattern = [ "pkill" ];
      justification = "Terminating processes requires approval.";
    }
    {
      pattern = [ "ln" ];
      justification = "Symlink and hardlink creation can overwrite files.";
    }
    {
      pattern = [ "rm" ];
      justification = "Deletion is supervised rather than auto-approved.";
    }
    {
      pattern = [ "rmdir" ];
      justification = "Deletion is supervised rather than auto-approved.";
    }

    # Systemd - service state modifications
    {
      pattern = [
        "systemctl"
        [
          "start"
          "stop"
          "restart"
          "reload"
          "enable"
          "disable"
          "mask"
          "unmask"
          "edit"
        ]
      ];
      justification = "Systemd service changes require approval.";
    }
    {
      pattern = [
        "systemctl"
        "daemon-reload"
      ];
      justification = "Reloading systemd manager state requires approval.";
    }

    # Container - mutable operations
    {
      pattern = [
        "docker"
        [
          "build"
          "run"
          "exec"
          "stop"
          "start"
          "pull"
          "push"
        ]
      ];
      justification = "Docker state changes and image transfer require approval.";
    }
    {
      pattern = [
        "docker-compose"
        [
          "up"
          "down"
        ]
      ];
      justification = "Docker Compose state changes require approval.";
    }
    {
      pattern = [
        "docker"
        "compose"
        [
          "up"
          "down"
        ]
      ];
      justification = "Docker Compose state changes require approval.";
    }

    # Build tools - the C/C++ build pipeline (./configure, autoreconf, make,
    # cmake, meson, ninja, gcc, clang, ar, ranlib, clang-tidy, clang-format)
    # was moved to allowedRules above. Out-of-tree installation
    # (`make install`, `cmake --install`) keeps prompting through the entries
    # below.
    {
      pattern = [
        "make"
        "install"
      ];
      justification = "make install writes outside the workspace.";
    }
    {
      pattern = [
        "cmake"
        "--install"
      ];
      justification = "cmake --install writes outside the workspace.";
    }
    # GitHub and Git - state modifications
    {
      pattern = [
        "gh"
        "pr"
        [
          "create"
          "merge"
          "checkout"
        ]
      ];
      justification = "GitHub pull request mutations require approval.";
    }
    {
      pattern = [
        "gh"
        "issue"
        "create"
      ];
      justification = "GitHub issue creation requires approval.";
    }
    {
      pattern = [
        "gh"
        "release"
        "create"
      ];
      justification = "GitHub release creation requires approval.";
    }
    {
      pattern = [
        "gh"
        "repo"
        [
          "create"
          "clone"
        ]
      ];
      justification = "Repository creation and cloning require approval.";
    }
    {
      pattern = [
        "git"
        [
          "add"
          "commit"
          "push"
          "pull"
          "fetch"
          "checkout"
          "switch"
          "merge"
          "rebase"
          "stash"
          "restore"
          "cherry-pick"
          "worktree"
        ]
      ];
      justification = "Git state changes and network sync require approval.";
    }

    # Nix - builds and environment changes
    {
      pattern = [
        "nix"
        [
          "build"
          "develop"
          "run"
          "shell"
        ]
      ];
      justification = "Nix builds and environments can execute project code.";
    }
    {
      pattern = [
        "nix"
        "flake"
        [
          "update"
          "lock"
        ]
      ];
      justification = "Flake lock updates require approval.";
    }
    {
      pattern = [
        "nix"
        "profile"
        [
          "install"
          "remove"
          "upgrade"
          "rollback"
          "wipe-history"
        ]
      ];
      justification = "Profile mutations require approval.";
    }
    {
      pattern = [ "nix-shell" ];
      justification = "Nix shell environments can execute project code.";
    }
    {
      pattern = [ "nix-build" ];
      justification = "Nix builds can execute project code.";
    }
    {
      pattern = [ "nix-env" ];
      justification = "Nix profile mutation requires approval.";
    }
    {
      pattern = [ "home-manager" ];
      justification = "Home Manager activation requires approval.";
    }
    {
      pattern = [ "nixos-rebuild" ];
      justification = "NixOS rebuilds require approval.";
    }
    {
      pattern = [ "darwin-rebuild" ];
      justification = "nix-darwin rebuilds require approval.";
    }

    # Common language and application toolchains
    #
    # Several alternative-list rules below were shrunk after `build`, `test`,
    # and `fmt` were promoted to allow. Codex resolves overlapping matches
    # via `Forbidden > Prompt > Allow` (max), so a parent prompt would still
    # win against a more-specific allow; splitting the alternatives removes
    # that conflict.
    {
      pattern = [
        "go"
        [
          "run"
          "generate"
          "get"
          "install"
        ]
      ];
      justification = "Go execution and out-of-workspace installation require approval.";
    }
    {
      pattern = [
        "go"
        "mod"
        "tidy"
      ];
      justification = "Go module file updates require approval.";
    }
    {
      pattern = [
        "npm"
        [
          "install"
          "run"
          "publish"
        ]
      ];
      justification = "npm execution and package changes require approval.";
    }
    {
      pattern = [
        "pnpm"
        [
          "install"
          "run"
        ]
      ];
      justification = "pnpm execution and package changes require approval.";
    }
    {
      pattern = [
        "yarn"
        [
          "add"
          "install"
        ]
      ];
      justification = "Yarn package changes require approval.";
    }
    {
      pattern = [ "vite" ];
      justification = "Development servers and builds require approval.";
    }
    {
      pattern = [ "hugo" ];
      justification = "Site builds and servers require approval.";
    }
    {
      pattern = [ "convert" ];
      justification = "Image processing can overwrite files.";
    }
    {
      pattern = [ "magick" ];
      justification = "Image processing can overwrite files.";
    }
    {
      pattern = [ "mogrify" ];
      justification = "Image processing can overwrite files.";
    }
    {
      pattern = [ "compare" ];
      justification = "Image comparison can write outputs.";
    }
    {
      pattern = [ "composite" ];
      justification = "Image composition can write outputs.";
    }
    {
      pattern = [ "lua" ];
      justification = "Lua execution requires approval.";
    }
    {
      pattern = [ "love" ];
      justification = "LÖVE execution requires approval.";
    }
    {
      pattern = [
        "luarocks"
        [
          "install"
          "remove"
        ]
      ];
      justification = "Lua package changes require approval.";
    }
    {
      pattern = [
        "cargo"
        [
          "run"
          "install"
          "publish"
          "update"
        ]
      ];
      justification = "Cargo execution and package changes require approval.";
    }
    {
      pattern = [
        "rustup"
        [
          "update"
          "default"
        ]
      ];
      justification = "Rust toolchain changes require approval.";
    }
    {
      pattern = [
        "pip"
        [
          "install"
          "uninstall"
        ]
      ];
      justification = "Python package changes require approval.";
    }
    # Note: bare `[ "python" ]` and `[ "python3" ]` prompt rules were
    # intentionally removed. Codex resolves overlapping rules via
    # `Forbidden > Prompt > Allow` (max), so a parent `python` prompt would
    # win against the more-specific `python -m pytest` allow above. Bare
    # `python script.py` invocations now fall through to Codex's heuristics
    # fallback rather than to a static prompt rule. `pytest`, `mypy`, and
    # `ruff` were also moved to allowedRules above.
    {
      pattern = [
        "uv"
        "pip"
        "install"
      ];
      justification = "Python package changes require approval.";
    }
    {
      pattern = [
        "uv"
        [
          "sync"
          "run"
        ]
      ];
      justification = "uv execution and environment changes require approval.";
    }
    {
      pattern = [
        "svelte-kit"
        [
          "sync"
          "build"
        ]
      ];
      justification = "SvelteKit build and generated file updates require approval.";
    }
    {
      pattern = [
        "wails"
        [
          "build"
          "dev"
          "init"
          "generate"
        ]
      ];
      justification = "Wails project commands require approval.";
    }
    {
      pattern = [
        "wrangler"
        [
          "dev"
          "deploy"
          "publish"
          "secret"
          "kv"
          "r2"
          "d1"
        ]
      ];
      justification = "Cloudflare development and deployment commands require approval.";
    }
  ];

  forbiddenRules = [
    # Privilege escalation
    {
      pattern = [ "sudo" ];
      justification = "Privilege escalation is never permitted.";
    }

    # Wrapper-leading bypasses. prefix_rule matches positional tokens, so a
    # bare `[ "sudo" ]` forbidden does not cover invocations such as
    # `xargs sudo rm` where the first token is the wrapper. Each common
    # wrapper-plus-target combination needs its own explicit entry.
    # `timeout` is omitted intentionally: it takes a duration as its first
    # positional argument (e.g. `timeout 5s sudo rm`), which positional
    # token matching cannot capture cleanly.
    {
      pattern = [
        "xargs"
        "sudo"
      ];
      justification = "Wrapper-disguised privilege escalation is forbidden.";
    }
    {
      pattern = [
        "xargs"
        "rm"
      ];
      justification = "Wrapper-disguised destructive deletion is forbidden.";
    }
    {
      pattern = [
        "xargs"
        "dd"
      ];
      justification = "Wrapper-disguised disk write is forbidden.";
    }
    {
      pattern = [
        "xargs"
        "shred"
      ];
      justification = "Wrapper-disguised secure deletion is forbidden.";
    }
    {
      pattern = [
        "nohup"
        "sudo"
      ];
      justification = "Wrapper-disguised privilege escalation is forbidden.";
    }
    {
      pattern = [
        "nohup"
        "rm"
      ];
      justification = "Wrapper-disguised destructive deletion is forbidden.";
    }
    {
      pattern = [
        "env"
        "sudo"
      ];
      justification = "Wrapper-disguised privilege escalation is forbidden.";
    }
    {
      pattern = [
        "setsid"
        "sudo"
      ];
      justification = "Wrapper-disguised privilege escalation is forbidden.";
    }

    # Secure deletion / truncation
    {
      pattern = [ "shred" ];
      justification = "Secure deletion bypasses recovery; use rm instead.";
    }
    {
      pattern = [ "wipe" ];
      justification = "Secure deletion bypasses recovery.";
    }
    {
      pattern = [ "srm" ];
      justification = "Secure deletion bypasses recovery.";
    }
    {
      pattern = [ "truncate" ];
      justification = "Truncating files is destructive and irreversible.";
    }

    # System modification
    {
      pattern = [ "sysctl" ];
      justification = "Kernel parameter modification is not permitted.";
    }
    {
      pattern = [ "modprobe" ];
      justification = "Kernel module loading is not permitted.";
    }
    {
      pattern = [ "insmod" ];
      justification = "Kernel module insertion is not permitted.";
    }
    {
      pattern = [ "rmmod" ];
      justification = "Kernel module removal is not permitted.";
    }

    # Boot / firmware
    {
      pattern = [ "grub-install" ];
      justification = "Bootloader modification is not permitted.";
    }
    {
      pattern = [ "update-grub" ];
      justification = "Bootloader modification is not permitted.";
    }
    {
      pattern = [ "efibootmgr" ];
      justification = "EFI firmware modification is not permitted.";
    }

    # Disk operations
    {
      pattern = [ "fdisk" ];
      justification = "Disk partitioning is not permitted.";
    }
    {
      pattern = [ "parted" ];
      justification = "Disk partitioning is not permitted.";
    }
    {
      pattern = [ "gparted" ];
      justification = "Disk partitioning is not permitted.";
    }
    {
      pattern = [ "mkfs" ];
      justification = "Filesystem creation is not permitted.";
    }
    {
      pattern = [ "mkfs.ext2" ];
      justification = "Filesystem creation is not permitted.";
    }
    {
      pattern = [ "mkfs.ext3" ];
      justification = "Filesystem creation is not permitted.";
    }
    {
      pattern = [ "mkfs.ext4" ];
      justification = "Filesystem creation is not permitted.";
    }
    {
      pattern = [ "mkfs.xfs" ];
      justification = "Filesystem creation is not permitted.";
    }
    {
      pattern = [ "mkfs.btrfs" ];
      justification = "Filesystem creation is not permitted.";
    }
    {
      pattern = [ "mkfs.vfat" ];
      justification = "Filesystem creation is not permitted.";
    }
    {
      pattern = [ "mkfs.fat" ];
      justification = "Filesystem creation is not permitted.";
    }
    {
      pattern = [ "mkfs.ntfs" ];
      justification = "Filesystem creation is not permitted.";
    }
    {
      pattern = [ "mkfs.exfat" ];
      justification = "Filesystem creation is not permitted.";
    }
    {
      pattern = [ "mkswap" ];
      justification = "Swap creation is not permitted.";
    }
    {
      pattern = [ "swapon" ];
      justification = "Swap activation is not permitted.";
    }
    {
      pattern = [ "swapoff" ];
      justification = "Swap deactivation is not permitted.";
    }
    {
      pattern = [ "mount" ];
      justification = "Filesystem mounting is not permitted.";
    }
    {
      pattern = [ "umount" ];
      justification = "Filesystem unmounting is not permitted.";
    }
    # dd is extremely dangerous - can destroy disks
    {
      pattern = [ "dd" ];
      justification = "dd can destroy disks; it is never permitted.";
    }

    # Subshell execution bypasses - arbitrary code execution risk
    {
      pattern = [
        "bash"
        "-c"
      ];
      justification = "Subshell -c bypasses per-command approval.";
    }
    {
      pattern = [
        "sh"
        "-c"
      ];
      justification = "Subshell -c bypasses per-command approval.";
    }
    {
      pattern = [
        "fish"
        "-c"
      ];
      justification = "Subshell -c bypasses per-command approval.";
    }
    {
      pattern = [
        "zsh"
        "-c"
      ];
      justification = "Subshell -c bypasses per-command approval.";
    }
    {
      pattern = [
        "dash"
        "-c"
      ];
      justification = "Subshell -c bypasses per-command approval.";
    }
    {
      pattern = [
        "bash"
        "-lc"
      ];
      justification = "Login subshell -lc bypasses per-command approval.";
    }
    {
      pattern = [
        "sh"
        "-lc"
      ];
      justification = "Login subshell -lc bypasses per-command approval.";
    }

    # Direct interpreter code execution bypasses
    {
      pattern = [
        "python"
        "-c"
      ];
      justification = "Direct interpreter execution bypasses approval.";
    }
    {
      pattern = [
        "python3"
        "-c"
      ];
      justification = "Direct interpreter execution bypasses approval.";
    }
    {
      pattern = [
        "python2"
        "-c"
      ];
      justification = "Direct interpreter execution bypasses approval.";
    }
    {
      pattern = [
        "node"
        "-e"
      ];
      justification = "Direct interpreter execution bypasses approval.";
    }
    {
      pattern = [
        "node"
        "--eval"
      ];
      justification = "Direct interpreter execution bypasses approval.";
    }
    {
      pattern = [
        "perl"
        "-e"
      ];
      justification = "Direct interpreter execution bypasses approval.";
    }
    {
      pattern = [
        "ruby"
        "-e"
      ];
      justification = "Direct interpreter execution bypasses approval.";
    }
    {
      pattern = [
        "lua"
        "-e"
      ];
      justification = "Direct interpreter execution bypasses approval.";
    }
    {
      pattern = [
        "php"
        "-r"
      ];
      justification = "Direct interpreter execution bypasses approval.";
    }

    # Systemd power management
    {
      pattern = [
        "systemctl"
        "poweroff"
      ];
      justification = "System shutdown is not permitted.";
    }
    {
      pattern = [
        "systemctl"
        "reboot"
      ];
      justification = "System reboot is not permitted.";
    }
    {
      pattern = [
        "systemctl"
        "halt"
      ];
      justification = "System halt is not permitted.";
    }
    {
      pattern = [
        "systemctl"
        "suspend"
      ];
      justification = "System suspend is not permitted.";
    }
    {
      pattern = [
        "systemctl"
        "hibernate"
      ];
      justification = "System hibernate is not permitted.";
    }

    # Docker mass destruction
    {
      pattern = [
        "docker"
        "system"
        "prune"
      ];
      justification = "Mass Docker resource deletion is not permitted.";
    }
    {
      pattern = [
        "docker"
        "volume"
        "prune"
      ];
      justification = "Mass Docker volume deletion is not permitted.";
    }
    {
      pattern = [
        "docker"
        "container"
        "prune"
      ];
      justification = "Mass Docker container deletion is not permitted.";
    }
    {
      pattern = [
        "docker"
        "image"
        "prune"
      ];
      justification = "Mass Docker image deletion is not permitted.";
    }

    # GitHub - destructive
    {
      pattern = [
        "gh"
        "repo"
        "delete"
      ];
      justification = "Repository deletion is not permitted.";
    }

    # Git history rewriting / destructive
    {
      pattern = [
        "git"
        "push"
        "--force"
      ];
      justification = "Force push rewrites history; it is not permitted.";
    }
    {
      pattern = [
        "git"
        "push"
        "-f"
      ];
      justification = "Force push rewrites history; it is not permitted.";
    }
    {
      pattern = [
        "git"
        "push"
        "--force-with-lease"
      ];
      justification = "Force push with lease still rewrites history; it is not permitted.";
    }
    {
      pattern = [
        "git"
        "reset"
        "--hard"
      ];
      justification = "Hard reset destroys uncommitted changes.";
    }
    {
      pattern = [
        "git"
        "clean"
      ];
      justification = "git clean destroys untracked files.";
    }
    {
      pattern = [
        "git"
        "filter-branch"
      ];
      justification = "History rewriting is not permitted.";
    }

    # Nix garbage collection
    {
      pattern = [ "nix-collect-garbage" ];
      justification = "Nix garbage collection is not permitted.";
    }
    {
      pattern = [
        "nix"
        "store"
        "gc"
      ];
      justification = "Nix store garbage collection is not permitted.";
    }
    {
      pattern = [
        "nix"
        "store"
        "delete"
      ];
      justification = "Nix store deletion is not permitted.";
    }
    {
      pattern = [
        "nix"
        "upgrade-nix"
      ];
      justification = "Upgrading Nix itself is not permitted.";
    }
    {
      pattern = [
        "nix-store"
        "--gc"
      ];
      justification = "Legacy Nix garbage collection is not permitted.";
    }
    {
      pattern = [
        "nix-store"
        "--delete"
      ];
      justification = "Legacy Nix store deletion is not permitted.";
    }

    # JavaScript cache corruption
    {
      pattern = [
        "npm"
        "cache"
        "clean"
        "--force"
      ];
      justification = "Forcing npm cache deletion is not permitted.";
    }

    # Cloudflare - resource deletion
    {
      pattern = [
        "wrangler"
        "delete"
      ];
      justification = "Cloudflare resource deletion is not permitted.";
    }
  ];

  # Render exec policy rules to Starlark prefix_rule() calls.
  renderRule =
    decision: rule:
    let
      renderToken =
        token:
        if builtins.isList token then
          "[${builtins.concatStringsSep ", " (map (nestedToken: "\"${nestedToken}\"") token)}]"
        else
          "\"${token}\"";
      patternStr = builtins.concatStringsSep ", " (map renderToken rule.pattern);
    in
    ''
      prefix_rule(
          pattern = [${patternStr}],
          decision = "${decision}",
          justification = "${rule.justification}",
      )
    '';

  rulesFileContent = ''
    # Codex exec policy rules - generated by Nix.
    #
    # approval_policy = "never" suppresses interactive prompts in trusted
    # workspaces. These rules still provide explicit allow/prompt/forbidden
    # command prefixes so dangerous commands remain blocked and the policy
    # shape stays aligned with Claude Code and OpenCode.
    #
    # decision precedence: forbidden > prompt > allow

  ''
  + builtins.concatStringsSep "\n" (map (renderRule "allow") allowedRules)
  + "\n"
  + builtins.concatStringsSep "\n" (map (renderRule "prompt") promptRules)
  + "\n"
  + builtins.concatStringsSep "\n" (map (renderRule "forbidden") forbiddenRules);

  # Codex config.toml settings. These are written via activation script (not
  # home.file) so the deployed file is a real mutable file. codex edits
  # config.toml in-place when writing back trust decisions and other runtime
  # state; a symlink into the read-only nix store silently swallows those
  # writes, which causes the trust prompt to appear on every launch.
  codexSettings = {
    # codex_apps (a built-in ChatGPT-hosted connector) cannot be overridden
    # from user config: any [mcp_servers.codex_apps] entry without command
    # or url is rejected by Codex's config parser with "invalid transport",
    # and runtime code unconditionally rebuilds the built-in entry on top of
    # any user-supplied stub. Its 30s startup timeout is hard-coded in
    # codex-rs/codex-mcp/src/mcp/mod.rs and there is no user-facing knob.
    # See openai/codex#18068 for the underlying TUI routing bug; max_threads
    # below caps sub-agent concurrency so the codex_apps ceiling applies
    # once per sub-agent rather than overlapping in the leader's status header.
    mcp_servers = mcpServerDefs.codexServers;

    # Approval policy: never lets trusted workspace sessions run without
    # interactive approval prompts. Dangerous command prefixes remain blocked
    # by the generated exec policy rules.
    approval_policy = "never";

    # Sandbox: workspace-write confines writes to the current project, /tmp,
    # and the explicit writable roots below. Do not use default_permissions
    # here on Linux: Codex split permission profiles cannot currently combine
    # custom filesystem rules with normal Unix-socket network access for Nix.
    sandbox_mode = "workspace-write";

    # Codex can reject login-shell requests before command policy evaluation.
    # This complements the explicit shell -c/-lc forbids in default.rules.
    allow_login_shell = false;

    # Explicitly enable every generated skill. Codex loads instruction-only
    # skills without an approval prompt; skill_approval in granular policies is
    # for skill-script approval prompts and false would auto-reject, not allow.
    skills = {
      config = map (skillName: {
        path = "${codexDir}/skills/${skillName}/SKILL.md";
        enabled = true;
      }) codexSkillNames;
    };

    # Extend the writable sandbox to the personal development directories
    # where code actually lives, mirroring the Edit() allow list in
    # claude-code/default.nix.
    sandbox_workspace_write = {
      writable_roots = [
        "${config.home.homeDirectory}/Chainguard"
        "${config.home.homeDirectory}/Development"
        "${config.home.homeDirectory}/Volatile"
        "${config.home.homeDirectory}/Zero"
        # Nix writes per-user flake fetcher locks here before it talks to the
        # daemon. Without this root, `just eval` fails inside workspace-write.
        "${config.xdg.cacheHome}/nix"
      ];
      # Keep /tmp writable (Codex default behaviour).
      exclude_slash_tmp = false;
      # Allow outbound network from within the sandbox so CLI tools such as
      # gh can reach their upstream services directly.
      network_access = true;
    };

    # Filesystem read denials. These are appended to the effective
    # FileSystemSandboxPolicy after sandbox_mode resolves, so reads of the
    # listed paths and globs are blocked even though sandbox_mode =
    # "workspace-write" otherwise permits reads anywhere. This complements
    # OpenCode's read.{path} = "deny" rules and Claude Code's Read(...) hook
    # gating, keeping the credential read-tier consistent across the three
    # agents without switching to default_permissions (which would break Nix
    # daemon socket access on Linux).
    #
    # No allow_read counterpart is required: workspace-write defaults
    # ReadOnlyAccess::FullAccess, so unlisted paths (including the immutable
    # /nix/store and other system locations) are already readable. The other
    # two assistants need explicit rules because their default policies
    # restrict reads outside the workspace.
    #
    # Glob support in deny_read is limited to `*` and `**`. Patterns are
    # expanded against the live filesystem at config load, so brand new
    # secret files created mid-session are not retroactively covered until
    # Codex reloads its config.
    permissions = {
      filesystem = {
        deny_read = [
          # Environment files
          ".env"
          ".env.local"
          # Bare-glob match: Codex limits globs to * and **, so we cover
          # arbitrary suffixes with a single trailing wildcard.
          ".env.*"
          ".env.*.local"

          # Secrets directories (workspace-relative and absolute mirrors)
          "**/secrets/**"
          "**/.secrets/**"
          "secrets/**"
          ".secrets/**"

          # SSH keys and key-shaped filenames
          "${config.home.homeDirectory}/.ssh/**"
          "**/id_rsa"
          "**/id_rsa.*"
          "**/id_ed25519"
          "**/id_ed25519.*"
          "**/id_ecdsa"
          "**/id_ecdsa.*"
          "**/*_rsa"
          "**/*_rsa.*"
          "**/*_ed25519"
          "**/*_ed25519.*"
          "**/*_ecdsa"
          "**/*_ecdsa.*"
          "*.pem"
          "*.key"

          # GPG keys
          "${config.home.homeDirectory}/.gnupg/**"

          # Cloud credentials
          "${config.home.homeDirectory}/.aws/**"
          "${config.home.homeDirectory}/.azure/**"
          "${config.xdg.configHome}/gcloud/**"

          # VCS credentials
          "${config.xdg.configHome}/gh/hosts.yml"
          "${config.home.homeDirectory}/.git-credentials"
          "${config.home.homeDirectory}/.netrc"

          # Container and Kubernetes secrets
          "${config.home.homeDirectory}/.docker/config.json"
          "${config.home.homeDirectory}/.kube/**"

          # Shell history (often contains credentials pasted on the CLI)
          "${config.home.homeDirectory}/.bash_history"
          "${config.home.homeDirectory}/.zsh_history"
          "${config.home.homeDirectory}/.fish_history"
          "${config.xdg.dataHome}/fish/fish_history"
        ];
      };
    };

    # Shell environment policy: strip secrets from every subprocess
    # environment. The default "core" baseline keeps PATH, HOME, and a
    # small set of essential variables; the exclude patterns then remove
    # credentials that core would otherwise pass through.
    shell_environment_policy = {
      "inherit" = "core";
      set = {
        NIX_REMOTE = "daemon";
      };
      # Exclude common credential variable patterns.
      exclude = [
        "AWS_*"
        "AZURE_*"
        "GOOGLE_*"
        "GCLOUD_*"
        "GH_TOKEN"
        "GITHUB_TOKEN"
        "ANTHROPIC_API_KEY"
        "OPENAI_API_KEY"
        "GEMINI_API_KEY"
        "*_API_KEY"
        "*_SECRET"
        "*_TOKEN"
        "SSH_AUTH_SOCK"
        "SSH_AGENT_PID"
        "GPG_AGENT_INFO"
      ];
    };

    # Pre-seed project trust for all personal development directories so
    # codex does not prompt "Do you trust this directory?" on every launch.
    #
    # codex matches the cwd (or git repo root) exactly against these keys -
    # it does NOT walk parent directories. Each git repository you work in
    # must have its own entry; the parent directory alone is insufficient.
    #
    # codex writes new trust decisions back to config.toml at runtime; the
    # file is deployed as a real mutable file so those writes succeed.
    projects = {
      "${config.home.homeDirectory}/Chainguard" = {
        trust_level = "trusted";
      };
      "${config.home.homeDirectory}/Development" = {
        trust_level = "trusted";
      };
      "${config.home.homeDirectory}/Volatile" = {
        trust_level = "trusted";
      };
      "${config.home.homeDirectory}/Zero" = {
        trust_level = "trusted";
      };
      "${config.home.homeDirectory}/Zero/nix-config" = {
        trust_level = "trusted";
      };
    };
  };

  # Generate the config.toml content in the nix store, then deploy it as a real
  # mutable file during activation.
  #
  # Why a real file, not a symlink: codex resolves codex_home from the path of
  # the config file it loaded, then writes trust decisions back to that same
  # path. A symlink into the read-only nix store causes every write to fail
  # with "failed to persist config.toml at /nix/store/...", so the trust prompt
  # reappears every session despite correct [projects] entries.
  #
  # Why merge instead of copy-once: codex appends new [projects] entries and may
  # persist other runtime preferences. Home Manager must still apply later
  # declarative changes. The activation step merges any existing mutable file
  # with the declarative baseline, preserving unknown runtime keys while the
  # managed settings in codexSettings take precedence.
  codexConfigToml = (pkgs.formats.toml { }).generate "codex-config.toml" codexSettings;
  codexConfigMergeScriptFixed = pkgs.writeText "merge-codex-config.py" (
    builtins.concatStringsSep "\n" [
      "import copy"
      "import pathlib"
      "import sys"
      "import tomllib"
      ""
      "import tomli_w"
      ""
      "def load_toml(path_str: str) -> dict:"
      "    path = pathlib.Path(path_str)"
      "    if not path.exists():"
      "        return {}"
      ""
      "    try:"
      "        with path.open(\"rb\") as handle:"
      "            data = tomllib.load(handle)"
      "    except (tomllib.TOMLDecodeError, OSError):"
      "        return {}"
      ""
      "    return data if isinstance(data, dict) else {}"
      ""
      "def merge_config(existing, desired):"
      "    if not isinstance(existing, dict) or not isinstance(desired, dict):"
      "        return copy.deepcopy(desired)"
      ""
      "    merged = copy.deepcopy(existing)"
      "    # These keys are fully declarative. If they disappear from the Nix"
      "    # baseline, remove stale runtime copies instead of preserving them."
      "    for managed_key in (\"default_permissions\", \"permissions\"):"
      "        if managed_key not in desired:"
      "            merged.pop(managed_key, None)"
      ""
      "    for key, desired_value in desired.items():"
      "        existing_value = merged.get(key)"
      ""
      "        if key == \"projects\" and isinstance(desired_value, dict):"
      "            project_entries = copy.deepcopy(existing_value) if isinstance(existing_value, dict) else {}"
      "            project_entries.update(copy.deepcopy(desired_value))"
      "            merged[key] = project_entries"
      "            continue"
      ""
      "        if key in {\"mcp_servers\", \"permissions\"}:"
      "            merged[key] = copy.deepcopy(desired_value)"
      "            continue"
      ""
      "        if isinstance(existing_value, dict) and isinstance(desired_value, dict):"
      "            merged[key] = merge_config(existing_value, desired_value)"
      "            continue"
      ""
      "        merged[key] = copy.deepcopy(desired_value)"
      ""
      "    return merged"
      ""
      "desired_path, target_path = sys.argv[1:3]"
      "desired = load_toml(desired_path)"
      "existing = load_toml(target_path)"
      "merged = merge_config(existing, desired)"
      ""
      "target = pathlib.Path(target_path)"
      "target.parent.mkdir(parents=True, exist_ok=True)"
      "tmp = target.with_name(f\"{target.name}.tmp\")"
      "tmp.write_text(tomli_w.dumps(merged), encoding=\"utf-8\")"
      "tmp.replace(target)"
    ]
    + "\n"
  );
  codexConfigActivationScript = ''
    install_codex_binary() {
      target="$1"
      mkdir -p "$(dirname "$target")"
      codex_tmp="$(mktemp "$(dirname "$target")/codex.XXXXXX")"
      cp "${codexPackage}/bin/codex" "$codex_tmp"
      chmod 755 "$codex_tmp"
      mv -f "$codex_tmp" "$target"
    }

    merge_codex_config() {
      target_dir="$1"
      mkdir -p "$target_dir"
      # Replace a symlink first, then merge runtime state with the declarative baseline.
      if [ -L "$target_dir/config.toml" ]; then
        rm "$target_dir/config.toml"
      fi
      ${tomlMergePython}/bin/python ${codexConfigMergeScriptFixed} ${codexConfigToml} "$target_dir/config.toml"
      chmod 644 "$target_dir/config.toml"
    }

    mkdir -p "${codexDir}"
    mkdir -p "${config.xdg.cacheHome}/nix/fetcher-locks"
    # Keep all plausible Codex homes seeded. The active home depends on
    # Codex's own config discovery, the Home Manager module, and whether an
    # older ~/.codex tree already exists.
    install_codex_binary "${codexStableBin}"
    install_codex_binary "${codexLegacyStableBin}"
    install_codex_binary "${codexXdgStableBin}"
    merge_codex_config "${codexDir}"
    merge_codex_config "${codexLegacyDir}"
    merge_codex_config "${codexXdgDir}"
  '';
in
{
  home = {
    packages = codexRuntimePackages ++ [ codexAcpPackage ];
    file."${codexDir}/rules/default.rules".text = rulesFileContent;
    # config.toml is written as a real mutable file (not a symlink) so that
    # codex can edit it in-place at runtime. See codexConfigActivationScript.
    activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] codexConfigActivationScript;
  };

  programs.codex = {
    enable = true;
    package = codexLauncherPackage;
    # The assistants mixin writes AGENTS.md after sops-nix renders Traya's
    # bonded prompt, keeping secret-derived content out of the Nix store.
    custom-instructions = "";
  };
}
