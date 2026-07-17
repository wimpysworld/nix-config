{
  config,
  inputs,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  inherit (config.noughty) host;
  inherit (pkgs.stdenv.hostPlatform) system;
  isDeveloper = noughtyLib.userHasTag "developer";
  fencedEnabled = !host.is.server;

  # Codex re-execs std::env::current_exe() when launching the Linux sandbox.
  # Nix store paths can disappear after a Home Manager generation switch, and
  # CODEX_HOME/.codex paths are special protected paths inside the Linux
  # sandbox. The interactive entry point must therefore exec a stable
  # user-owned binary copy outside CODEX_HOME.
  # Keep the source package unchanged so Numtide's cache can substitute the
  # large Rust build. On Linux, the upstream wrapper hides the real binary at
  # `bin/.codex-wrapped`; activation copies that binary into a stable user path
  # so current_exe re-exec keeps working after Home Manager generation changes.
  codexPackage = inputs.llm-agents.packages.${system}.codex;
  fencePackage = import ../fence/package.nix { inherit inputs pkgs; };
  fenceGit = import ../fence/git.nix;
  fenceWaylandBridge = import ../fence/wayland-bridge.nix { inherit pkgs; };
  fenceChromium =
    if !(host.is.linux && fencedEnabled) then
      {
        runtimeInputs = [ ];
        setupShell = "";
      }
    else
      import ../fence/chromium.nix { inherit pkgs; };
  fenceLogging = import ../fence/logging.nix { inherit pkgs; };
  communicationRules = config.agentic.communicationRules;

  # ACP adapter that lets Zed drive Codex over the Agent Client Protocol.
  # The binary is `codex-acp`, pinned via the llm-agents flake input so the
  # adapter version stays in lockstep with the codex CLI it speaks to.
  codexAcpPackage = inputs.llm-agents.packages.${system}.codex-acp;
  codexLegacyDir = "${config.home.homeDirectory}/.codex";
  codexXdgDir = "${config.xdg.configHome}/codex";
  codexStableBin = "${config.xdg.dataHome}/codex/bin/codex";
  codexLegacyStableBin = "${codexLegacyDir}/bin/codex";
  codexXdgStableBin = "${codexXdgDir}/bin/codex";

  # Determine CODEX_HOME path, mirroring the Home Manager module logic.
  # The HM module sets CODEX_HOME = xdg.configHome/codex when
  # home.preferXdgDirectories is true (and package >= 0.2.0, which it is).
  codexDir = if config.home.preferXdgDirectories then codexXdgDir else codexLegacyDir;
  codexDirs = lib.unique [
    codexDir
    codexLegacyDir
    codexXdgDir
  ];
  codexConfigPaths = map (targetDir: "${targetDir}/config.toml") codexDirs;
  codexStableBins = lib.unique [
    codexStableBin
    codexLegacyStableBin
    codexXdgStableBin
  ];

  codexLauncherPackage = pkgs.writeShellApplication {
    name = "codex";
    runtimeInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.bubblewrap ];
    text = ''
      export CODEX_HOME=${lib.escapeShellArg codexDir}

      # Resolve the stable user-owned binary copy (see the note above), falling
      # back to the XDG path when none is executable yet.
      codex_bin="${codexXdgStableBin}"
      for candidate in "${codexStableBin}" "${codexLegacyStableBin}" "${codexXdgStableBin}"; do
        if [ -x "$candidate" ]; then
          codex_bin="$candidate"
          break
        fi
      done

      # codex-fenced sets NOUGHTY_CODEX_BYPASS so the sandbox bypass is added
      # here as a top-level flag (before the resume subcommand). Plain `codex`
      # keeps Codex's native workspace-write sandbox.
      bypass=()
      if [ "''${NOUGHTY_CODEX_BYPASS:-0}" = "1" ]; then
        bypass=(--dangerously-bypass-approvals-and-sandbox)
      fi

      # Resume the most recent session by default. The `resume --last`
      # subcommand also accepts a prompt and the interactive flags, so it is
      # injected for bare, prompt, and flag launches. It is skipped for Codex
      # subcommands (mcp, exec, login, ...) and help/version, which must not be
      # wrapped in `resume`.
      codex_resume=(resume --last)
      case "''${1:-}" in
        exec | e | review | login | logout | mcp | plugin | mcp-server | app-server | remote-control | completion | update | doctor | sandbox | debug | apply | a | resume | archive | unarchive | fork | cloud | exec-server | features | help | -h | --help | -V | --version)
          codex_resume=()
          ;;
      esac

      exec "$codex_bin" "''${bypass[@]}" "''${codex_resume[@]}" "$@"
    '';
  };
  codexFencedPackage = pkgs.writeShellApplication {
    name = "codex-fenced";
    runtimeInputs = [
      fencePackage
    ]
    ++ fenceWaylandBridge.runtimeInputs
    ++ fenceChromium.runtimeInputs
    ++ fenceLogging.runtimeInputs;
    text = ''
      ${fenceWaylandBridge.setupShell}
      ${fenceGit.setupShell}
      ${fenceChromium.setupShell}

      fence_log_agent="codex"
      ${fenceLogging.setupShell}

      # herdr identifies a pane's agent from the foreground process group
      # environ. Export the hint host-side so fence and the whole wrapper chain
      # inherit it; an inline post-`--` token would land only inside the sandbox
      # PID namespace, which herdr does not read.
      export HERDR_AGENT=codex

      # Pass the bypass through as an env token so the launcher sees the real
      # first user argument and resumes the most recent session by default.
      fence "''${fence_args[@]}" -- "''${fence_env[@]}" "''${fence_direnv[@]}" "NOUGHTY_CODEX_BYPASS=1" ${lib.getExe' codexLauncherPackage "codex"} "$@"
    '';
  };
  codexTripwireCorrectionPromptFile = pkgs.writeTextFile {
    name = "codex-communication-rules-correction-prompt.md";
    text = communicationRules.correctionPrompt;
  };
  codexHookEventLabels = {
    PreToolUse = "pre_tool_use";
    SessionStart = "session_start";
    Stop = "stop";
    SubagentStart = "subagent_start";
    SubagentStop = "subagent_stop";
    UserPromptSubmit = "user_prompt_submit";
  };
  # Build the command-style hook through the shared helper. The helper exports
  # the environment the core reads (TRIPWIRE_SCANNER, TRIPWIRE_POLICY_JSON,
  # TRIPWIRE_CORRECTION_PROMPT) and runs `scanner.py codex <event>`, so
  # detection, the strike machine, and Tier A re-issue all live in the core.
  # Passing the event labels gives back a `trustedHash` builder that hashes the
  # same identity JSON Codex trusts, so the hash recomputes from the new command.
  codexTripwireAdapter = communicationRules.mkCommandHookAdapter {
    agent = "codex";
    correctionPrompt = codexTripwireCorrectionPromptFile;
    hookEventLabels = codexHookEventLabels;
  };
  # Wrap the helper's per-event hook with Codex's timeout and status message.
  codexTripwireHook =
    event: statusMessage:
    codexTripwireAdapter.mkHook event
    // {
      timeout = 30;
      inherit statusMessage;
    };
  codexTripwireHookEvents = {
    # No SessionStart or SubagentStart reminder hook is registered here on
    # purpose. Codex already loads the full Communication Rules silently
    # through its instructions: the assistants mixin expands the single-source
    # rules at the `<!-- COMMUNICATION_RULES -->` marker into Codex
    # developer_instructions and AGENTS.md via compose.expandCommunicationRules,
    # so the standing rules reach the model at session start. Codex also has no
    # silent SessionStart hook channel: a hook emitting
    # hookSpecificOutput.additionalContext is recorded as a visible developer
    # message in the transcript (see openai/codex#16933), and SubagentStart is
    # likewise reminder-only and cannot gate. Registering either here would only
    # add user-visible noise that duplicates the instructions, so both are
    # omitted. The core shaper keeps its codex_context/remind capability latent.
    # UserPromptSubmit consumes a pending Tier A re-issue flag set by a Stop or
    # SubagentStop breach, injecting the rules as model-only additionalContext on
    # the next turn. Without it the flag is set but never read.
    UserPromptSubmit = [
      {
        hooks = [ (codexTripwireHook "UserPromptSubmit" "Loading Communication Rules") ];
      }
    ];
    PreToolUse = [
      {
        matcher = "^(apply_patch|Edit|Write|Bash|mcp__.*(comment|create|edit|issue|post|pr|publish|release|review|send).*)$";
        hooks = [ (codexTripwireHook "PreToolUse" "Checking Communication Rules") ];
      }
    ];
    Stop = [
      {
        hooks = [ (codexTripwireHook "Stop" "Checking Communication Rules") ];
      }
    ];
    SubagentStop = [
      {
        hooks = [ (codexTripwireHook "SubagentStop" "Checking Communication Rules") ];
      }
    ];
  };
  codexHookStateEntriesForConfigPath =
    configPath:
    lib.flatten (
      lib.mapAttrsToList (
        eventName: groups:
        lib.imap0 (
          groupIndex: group:
          lib.imap0 (handlerIndex: hook: {
            name = "${configPath}:${
              codexHookEventLabels.${eventName}
            }:${toString groupIndex}:${toString handlerIndex}";
            value = {
              enabled = true;
              trusted_hash = codexTripwireAdapter.trustedHash eventName group hook;
            };
          }) group.hooks
        ) groups
      ) codexTripwireHookEvents
    );
  codexTripwireHookState = lib.listToAttrs (
    lib.concatMap codexHookStateEntriesForConfigPath codexConfigPaths
  );
  codexTripwireHooks = lib.optionalAttrs communicationRules.enable {
    hooks = codexTripwireHookEvents // {
      state = codexTripwireHookState;
    };
  };
  tomlMergePython = pkgs.python3.withPackages (ps: [ ps.tomli-w ]);

  # Import shared MCP server definitions and translate them into Codex's
  # native config.toml schema.
  mcpServerDefs = import ../mcp/servers.nix {
    inherit config pkgs;
  };
  assistantCompose = import ../assistants/compose.nix { inherit lib; };

  codexSkillNames =
    let
      sharedSkillNames = builtins.attrNames assistantCompose.skillDirs;
      commandSkillNames = builtins.attrNames assistantCompose.standaloneCommandDirs;
      # Agent-scoped command skills are emitted under the bare `cmdName` to
      # match the Pi prompt convention. The collision guard in the shared
      # assistants composer enforces uniqueness across project skills,
      # standalone commands, and agent-scoped commands, so flattening here
      # is safe.
      agentCommandSkillNames = lib.flatten (
        lib.mapAttrsToList (
          agentName: _: builtins.attrNames (assistantCompose.discoverAgentCommands agentName)
        ) assistantCompose.agentDirs
      );
    in
    lib.sort (a: b: a < b) (sharedSkillNames ++ commandSkillNames ++ agentCommandSkillNames);

  # Codex config.toml settings. These are written via activation script (not
  # home.file) so the deployed file is a real mutable file. Codex can persist
  # edits through symlink chains, but a Home Manager symlink into the read-only
  # Nix store is still the wrong target for runtime config writes.
  codexSettings = {
    # codex_apps (a built-in ChatGPT-hosted connector) cannot be overridden
    # from user config: any [mcp_servers.codex_apps] entry without command
    # or url is rejected by Codex's config parser with "invalid transport",
    # and runtime code unconditionally rebuilds the built-in entry on top of
    # any user-supplied stub. Its 30s startup timeout is hard-coded in
    # codex-rs/codex-mcp/src/mcp/mod.rs and there is no user-facing knob.
    # See openai/codex#18068 for the underlying TUI routing bug.
    mcp_servers = mcpServerDefs.codexServers;

    # Disable first-party telemetry, analytics, and feedback. The [analytics]
    # channel is on by default, and the sample config ships
    # otel.metrics_exporter = "statsig", so set all three OTEL exporters to
    # "none" explicitly.
    analytics = {
      enabled = false;
    };
    otel = {
      exporter = "none";
      metrics_exporter = "none";
      trace_exporter = "none";
      log_user_prompt = false;
    };
    feedback = {
      enabled = false;
    };

    # Disable the startup update check. Nix owns the installed version
    # through the llm-agents flake input, so the check serves no purpose.
    check_for_update_on_startup = false;

    # Do not prompt to install missing MCP dependencies for skills.
    features = {
      skill_mcp_dependency_install = false;
    };

    # Plain `codex` remains usable without Fence by keeping Codex's native
    # workspace-write sandbox and non-interactive approval defaults. The
    # `codex-fenced` entry point bypasses these at launch so Fence owns that
    # mode's filesystem, network, and command policy.
    approval_policy = "never";

    # Disable Codex's built-in web search so web access routes through the
    # Exa MCP server. The built-in tool runs through OpenAI's hosted search,
    # not the sandbox network, so disabling is the only way to stop it and
    # avoid a second, separately-billed web path. There is no separate
    # built-in fetch tool. MCP servers are independent, so Exa is unaffected.
    web_search = "disabled";

    model = "gpt-5.5";
    model_reasoning_effort = "high";

    # Bound Codex subagent fan-out.
    agents = {
      max_threads = 10;
      max_depth = 1;
    };

    # Apply no vendor personality. The Communication Rules are the persona for
    # this setup, expanded into Codex base instructions via the
    # `<!-- COMMUNICATION_RULES -->` marker and enforced by the tripwire gate.
    # `personality` is an enum (none/friendly/pragmatic) and cannot carry the
    # rules text, so "none" keeps the vendor tone block from competing.
    personality = "none";

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

    tui = {
      theme = "catppuccin-mocha";
      status_line = [
        "model-with-reasoning"
        "fast-mode"
        "current-dir"
        "five-hour-limit"
        "weekly-limit"
        "context-window-size"
        "context-used"
        "permissions"
      ];
      status_line_use_colors = true;
      # Disable the built-in TUI notifications.
      notifications = false;
    };

    # Explicitly enable every generated skill so command/agent skills are
    # always available from the generated ~/.codex/skills tree. Disable the
    # bundled SYSTEM skills OpenAI ships (imagegen, openai-docs, plugin-creator,
    # skill-creator, skill-installer): this repository provides its own skills
    # and commands, so the bundled set is noise, mirroring Claude Code's
    # `disableBundledSkills`. The `bundled` and `config` sub-fields are
    # independent, so the generated user skills keep loading.
    skills = {
      bundled = {
        enabled = false;
      };
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
    # codex writes new trust decisions back to config.toml at runtime. The
    # file is writable so those writes succeed during a session, and activation
    # rewrites it from this Nix baseline so only declared trust remains.
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
  }
  // codexTripwireHooks;

  # Generate the config.toml content in the nix store, then deploy it as a real
  # mutable file during activation.
  #
  # Why a real file, not a store-backed symlink: codex follows symlink chains
  # when persisting config.toml. A Home Manager link into the read-only Nix
  # store leaves codex with a target it cannot rewrite.
  #
  # Why merge instead of copy-once: the helper starts from the declarative
  # baseline and can selectively import future allowlisted runtime state. No
  # runtime keys are currently preserved, so activation scrubs config drift.
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
      "def runtime_state_allowlist(existing, _desired):"
      "    if not isinstance(existing, dict):"
      "        return {}"
      ""
      "    # Runtime keys must be explicitly copied here after verifying that"
      "    # Codex still stores them in config.toml and that they are safe to"
      "    # preserve across Home Manager activations."
      "    return {}"
      ""
      "def merge_config(existing, desired):"
      "    if not isinstance(desired, dict):"
      "        return {}"
      ""
      "    merged = copy.deepcopy(desired)"
      "    merged.update(runtime_state_allowlist(existing, desired))"
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
      if [ -x "${codexPackage}/bin/.codex-wrapped" ]; then
        cp "${codexPackage}/bin/.codex-wrapped" "$codex_tmp"
      else
        cp "${codexPackage}/bin/codex" "$codex_tmp"
      fi
      chmod 755 "$codex_tmp"
      mv -f "$codex_tmp" "$target"
    }

    merge_codex_config() {
      target_dir="$1"
      mkdir -p "$target_dir"
      # Replace a symlink first, then rewrite from the declarative baseline.
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
    ${lib.concatMapStringsSep "\n" (target: ''install_codex_binary "${target}"'') codexStableBins}
    ${lib.concatMapStringsSep "\n" (targetDir: ''merge_codex_config "${targetDir}"'') codexDirs}
  '';
in
lib.mkIf (isDeveloper && !host.is.server) {
  home = {
    packages = [
      codexAcpPackage
    ]
    ++ lib.optional communicationRules.enable codexTripwireAdapter.hookPackage
    ++ lib.optional fencedEnabled codexFencedPackage;
    # config.toml is written as a real mutable file (not a symlink) so that
    # codex can edit it in-place at runtime. See codexConfigActivationScript.
    activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] codexConfigActivationScript;
    sessionVariables = {
      CODEX_HOME = codexDir;
    };
  };

  programs = {
    bash.shellAliases = lib.mkIf fencedEnabled {
      codex-fenced = lib.getExe codexFencedPackage;
    };
    codex = {
      enable = true;
      package = codexLauncherPackage;
      # The assistants mixin writes AGENTS.md from the canonical global prompt.
      context = "";
    };
    fish.shellAliases = lib.mkIf fencedEnabled {
      codex-fenced = lib.getExe codexFencedPackage;
    };
    zsh.shellAliases = lib.mkIf fencedEnabled {
      codex-fenced = lib.getExe codexFencedPackage;
    };
  };
}
