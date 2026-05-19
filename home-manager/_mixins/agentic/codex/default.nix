{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;

  # Codex re-execs std::env::current_exe() when launching the Linux sandbox.
  # Nix store paths can disappear after a Home Manager generation switch, and
  # CODEX_HOME/.codex paths are special protected paths inside the Linux
  # sandbox. The interactive entry point must therefore exec a stable
  # user-owned binary copy outside CODEX_HOME.
  # Keep the source package unwrapped so that copied binary remains self-same
  # for arg0 dispatch, including codex-linux-sandbox.
  codexPackage = inputs.llm-agents.packages.${system}.codex.overrideAttrs (_oldAttrs: {
    postFixup = "";
  });
  fencePackage = import ../fence/package.nix { inherit inputs pkgs; };

  # ACP adapter that lets Zed drive Codex over the Agent Client Protocol.
  # The binary is `codex-acp`, pinned via the llm-agents flake input so the
  # adapter version stays in lockstep with the codex CLI it speaks to.
  codexAcpPackage = inputs.llm-agents.packages.${system}.codex-acp;
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
  codexFencedPackage = pkgs.writeShellApplication {
    name = "codex-fenced";
    runtimeInputs = [ fencePackage ];
    text = ''
      exec fence -- ${lib.getExe' codexLauncherPackage "codex"} --dangerously-bypass-approvals-and-sandbox "$@"
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

    # Plain `codex` remains usable without Fence by keeping Codex's native
    # workspace-write sandbox and non-interactive approval defaults. The
    # `codex-fenced` entry point bypasses these at launch so Fence owns that
    # mode's filesystem, network, and command policy.
    approval_policy = "never";

    # Sandbox: workspace-write confines writes to the current project, /tmp,
    # and the explicit writable roots below. Do not use default_permissions
    # here on Linux: Codex split permission profiles cannot currently combine
    # custom filesystem rules with normal Unix-socket network access for Nix.
    sandbox_mode = "workspace-write";

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

    allow_login_shell = false;

    # Explicitly enable every generated skill so command/agent skills are
    # always available from the generated ~/.codex/skills tree.
    skills = {
      config = map (skillName: {
        path = "${codexDir}/skills/${skillName}/SKILL.md";
        enabled = true;
      }) codexSkillNames;
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
      "    managed_keys = ("
      "        \"allow_login_shell\","
      "        \"default_permissions\","
      "        \"permissions\","
      "        \"shell_environment_policy\","
      "    )"
      "    for managed_key in managed_keys:"
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
      "        if key == \"mcp_servers\":"
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
      rm -f "$target_dir/rules/default.rules"
      rmdir "$target_dir/rules" 2>/dev/null || true
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
    packages = [
      codexAcpPackage
    ]
    ++ lib.optional pkgs.stdenv.hostPlatform.isLinux codexFencedPackage;
    # config.toml is written as a real mutable file (not a symlink) so that
    # codex can edit it in-place at runtime. See codexConfigActivationScript.
    activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] codexConfigActivationScript;
  };

  programs = {
    bash.shellAliases = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      codex-fenced = lib.getExe codexFencedPackage;
    };
    codex = {
      enable = true;
      package = codexLauncherPackage;
      # The assistants mixin writes AGENTS.md from the canonical global prompt.
      custom-instructions = "";
    };
    fish.shellAliases = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      codex-fenced = lib.getExe codexFencedPackage;
    };
    zsh.shellAliases = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      codex-fenced = lib.getExe codexFencedPackage;
    };
  };
}
