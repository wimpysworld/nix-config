{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  codexPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;

  # Import shared MCP server definitions and translate them into Codex's
  # native config.toml schema.
  mcpServerDefs = import ../mcp/servers.nix {
    inherit config pkgs;
  };

  codexMcpServers = {
    cloudflare = {
      inherit (mcpServerDefs.mcpServers.cloudflare) url;
    };
    context7 = {
      inherit (mcpServerDefs.mcpServers.context7) url;
      bearer_token_env_var = "CONTEXT7_API_KEY";
    };
    exa = {
      inherit (mcpServerDefs.mcpServers.exa) url;
    };
    jina = {
      inherit (mcpServerDefs.mcpServers.jina) url;
      bearer_token_env_var = "JINA_API_KEY";
    };
    nixos = {
      inherit (mcpServerDefs.mcpServers.nixos) command;
      args = [ ];
    };
    svelte = {
      inherit (mcpServerDefs.mcpServers.svelte) url;
    };
  };

  # Determine CODEX_HOME path, mirroring the Home Manager module logic.
  # The HM module sets CODEX_HOME = xdg.configHome/codex when
  # home.preferXdgDirectories is true (and package >= 0.2.0, which it is).
  codexDir =
    if config.home.preferXdgDirectories then
      "${config.xdg.configHome}/codex"
    else
      "${config.home.homeDirectory}/.codex";

  # Forbidden commands - blocked unconditionally, no prompt.
  # These mirror the bashDeny list in claude-code/default.nix, translated to
  # Codex prefix_rule() syntax. Each list entry becomes one rule.
  #
  # Format: each attrset has { pattern = [...]; justification = "..."; }
  # The decision is always "forbidden" for this group.
  forbiddenRules = [
    # Privilege escalation
    {
      pattern = [ "sudo" ];
      justification = "Privilege escalation is never permitted.";
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

  # Render forbidden rules to Starlark prefix_rule() calls.
  renderForbiddenRule =
    rule:
    let
      patternStr = builtins.concatStringsSep ", " (map (t: "\"${t}\"") rule.pattern);
    in
    ''
      prefix_rule(
          pattern = [${patternStr}],
          decision = "forbidden",
          justification = "${rule.justification}",
      )
    '';

  rulesFileContent = ''
    # Codex exec policy rules - generated by Nix.
    #
    # approval_policy = "untrusted" in config.toml already auto-allows the
    # built-in trusted command set (ls, cat, git status, etc.) and prompts for
    # everything else. These rules extend that with unconditional forbids for
    # the most dangerous operations, mirroring the deny list used by Claude
    # Code and OpenCode.
    #
    # decision precedence: forbidden > prompt > allow

  ''
  + builtins.concatStringsSep "\n" (map renderForbiddenRule forbiddenRules);

  # Codex config.toml settings. These are written via activation script (not
  # home.file) so the deployed file is a real mutable file. codex edits
  # config.toml in-place when writing back trust decisions and other runtime
  # state; a symlink into the read-only nix store silently swallows those
  # writes, which causes the trust prompt to appear on every launch.
  codexSettings = {
    mcp_servers = codexMcpServers;

    # Approval policy: "untrusted" auto-allows the built-in trusted command
    # set (read-only shell tools, git queries, etc.) without prompting, and
    # escalates everything else to the user. This mirrors the allow/ask split
    # in the Claude Code and OpenCode permission tables.
    approval_policy = "untrusted";

    # Sandbox: workspace-write confines filesystem access to the current
    # project workspace plus /tmp. Files outside the workspace (SSH keys,
    # GPG keys, cloud credentials, shell history) are inaccessible to the
    # model by construction, replacing the explicit readDeny list used by
    # Claude Code and OpenCode.
    sandbox_mode = "workspace-write";

    # Extend the writable sandbox to the personal development directories
    # where code actually lives, mirroring the Edit() allow list in
    # claude-code/default.nix.
    sandbox_workspace_write = {
      writable_roots = [
        "${config.home.homeDirectory}/Chainguard"
        "${config.home.homeDirectory}/Development"
        "${config.home.homeDirectory}/Volatile"
        "${config.home.homeDirectory}/Zero"
      ];
      # Keep /tmp writable (Codex default behaviour).
      exclude_slash_tmp = false;
      # Disable outbound network from within the sandbox; MCP servers
      # handle all external network access through their own processes.
      network_access = false;
    };

    # Shell environment policy: strip secrets from every subprocess
    # environment. The default "core" baseline keeps PATH, HOME, and a
    # small set of essential variables; the exclude patterns then remove
    # credentials that core would otherwise pass through.
    shell_environment_policy = {
      "inherit" = "core";
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
  # Why preserve an existing real file: codex appends new [projects] entries at
  # runtime when the user trusts a new directory. Overwriting on every switch
  # would wipe those entries, requiring the user to re-trust on next launch.
  # A symlink at the target path is replaced unconditionally (it cannot be
  # written to); a real file is left alone so runtime additions survive.
  codexConfigToml = (pkgs.formats.toml { }).generate "codex-config.toml" codexSettings;
  codexConfigActivationScript = ''
    mkdir -p "${codexDir}"
    # Replace if absent or if a symlink snuck back in; preserve a real file.
    if [ ! -e "${codexDir}/config.toml" ] || [ -L "${codexDir}/config.toml" ]; then
      cp --remove-destination ${codexConfigToml} "${codexDir}/config.toml"
      chmod 644 "${codexDir}/config.toml"
    fi
  '';
in
{
  home = {
    file."${codexDir}/rules/default.rules".text = rulesFileContent;
    # config.toml is written as a real mutable file (not a symlink) so that
    # codex can edit it in-place at runtime. See codexConfigActivationScript.
    activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] codexConfigActivationScript;
  };

  programs.codex = {
    enable = true;
    package = codexPackage;
    custom-instructions = builtins.readFile ../assistants/instructions/global.md;
  };
}
