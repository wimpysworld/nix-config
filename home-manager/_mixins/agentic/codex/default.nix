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
  fenceAgentShare = import ../fence/agent-share.nix { inherit config pkgs; };
  fenceGit = import ../fence/git.nix { inherit config pkgs; };
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
  herdrIntegrations = pkgs.herdr-integrations;
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
  codexHerdrScript = "${herdrIntegrations}/home/.codex/herdr-agent-state.sh";
  codexDeployedHerdrScript = "${codexDir}/herdr-agent-state.sh";
  codexHerdrScriptPaths = map (targetDir: "${targetDir}/herdr-agent-state.sh") codexDirs;
  # Codex runs a command hook through `/bin/sh -c` with the session PATH.
  # Inside fence that PATH has no `bash`, and no `mktemp` or `cat` either, so a
  # bare `bash '<script>'` command fails with "bash: command not found" and the
  # herdr POSIX script would exit early even if it did start. This wrapper puts
  # the tools the script needs on PATH and runs it by absolute path. The script
  # is skipped when it is not deployed yet, so a first activation cannot report
  # a hook error.
  codexHerdrHookPackage = pkgs.writeShellApplication {
    name = "codex-herdr-agent-state";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.python3
    ];
    text = ''
      script=${lib.escapeShellArg codexDeployedHerdrScript}
      [[ -x "$script" ]] || exit 0
      exec "$script" "$@"
    '';
  };
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
    ++ fenceAgentShare.runtimeInputs
    ++ fenceWaylandBridge.runtimeInputs
    ++ fenceChromium.runtimeInputs
    ++ fenceLogging.runtimeInputs;
    text = ''
      if [[ "''${FENCE_SANDBOX:-0}" == 1 ]]; then
        export HERDR_AGENT=codex
        export NOUGHTY_CODEX_BYPASS=1
        exec ${lib.getExe' codexLauncherPackage "codex"} "$@"
      fi

      ${fenceAgentShare.captureShell}
      ${fenceWaylandBridge.setupShell}
      ${fenceAgentShare.setupShell}
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
  # Codex writes one rollout transcript per session under
  # $CODEX_HOME/sessions/<year>/<month>/<day>/ and never prunes them. There is
  # no retention setting in config.toml, and `codex delete` removes a single
  # named session only, so retention is enforced here. Rollouts older than the
  # window are removed, then the date directories they leave empty are removed
  # too. Pass a number of days to override the window. Set
  # CODEX_PRUNE_DRY_RUN=1 to list what would go without deleting anything.
  #
  # This deletes session transcripts permanently. `codex resume` and the
  # session picker can only reach what survives the window.
  rolloutRetentionDays = 14;
  codexPruneRolloutsPackage = pkgs.writeShellApplication {
    name = "codex-prune-rollouts";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      retention_days="''${1:-${toString rolloutRetentionDays}}"
      case "$retention_days" in
        "" | *[!0-9]*)
          echo "codex-prune-rollouts: retention days must be a whole number, got '$retention_days'" >&2
          exit 1
          ;;
      esac

      dry_run="''${CODEX_PRUNE_DRY_RUN:-0}"
      if [[ "$dry_run" == 1 ]]; then
        action="listed"
      else
        action="removed"
      fi

      # `-mmin +N` is true when the age in whole minutes exceeds N, so this is
      # exactly "older than $retention_days days" with no rounding surprise.
      retention_minutes="$((retention_days * 1440))"
      count=0

      for sessions_dir in ${
        lib.concatStringsSep " " (map (dir: lib.escapeShellArg "${dir}/sessions") codexDirs)
      }; do
        [[ -d "$sessions_dir" ]] || continue

        while IFS= read -r -d "" rollout; do
          if [[ "$dry_run" == 1 ]]; then
            printf 'would remove %s\n' "$rollout"
          else
            rm -f -- "$rollout"
          fi
          count=$((count + 1))
        done < <(find "$sessions_dir" -type f -name 'rollout-*.jsonl' -mmin "+$retention_minutes" -print0)

        if [[ "$dry_run" != 1 ]]; then
          find "$sessions_dir" -mindepth 1 -type d -empty -delete
        fi
      done

      printf 'codex-prune-rollouts: %s %d rollout file(s) older than %s day(s)\n' \
        "$action" "$count" "$retention_days"
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
    # No Communication Rules SessionStart or SubagentStart reminder hook is
    # registered here on purpose. Codex loads the Communication Rules skill
    # through the explicit reference in its root instructions. Codex also has no
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
  codexHerdrHookEvents = {
    SessionStart = [
      {
        hooks = [
          {
            type = "command";
            command = "${lib.getExe codexHerdrHookPackage} session";
            timeout = 10;
          }
        ];
      }
    ];
  };
  codexHookEvents =
    (lib.optionalAttrs communicationRules.enable codexTripwireHookEvents) // codexHerdrHookEvents;
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
      ) codexHookEvents
    );
  codexHookState = lib.listToAttrs (
    lib.concatMap codexHookStateEntriesForConfigPath codexConfigPaths
  );
  codexHooks = {
    hooks = codexHookEvents // {
      state = codexHookState;
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
    # These are the user MCP servers only. The built-in codex_apps server is
    # not declared here and cannot be overridden through this table: an entry
    # without `command` or `url` fails the config parser with "invalid
    # transport". It is switched off through `features.apps` below instead.
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
    # `code_mode_host` is on by default upstream, but state it here so the
    # feature stays on if that default changes. The activation script installs
    # the `codex-code-mode-host` helper the feature needs.
    features = {
      # Disable the built-in codex_apps MCP server, the ChatGPT-hosted app
      # connector. It is on by default and adds a 30s hard-coded startup
      # timeout that no user setting shortens, so removing the server is the
      # only fix. Codex drops codex_apps before it tries to connect when this
      # flag is false, so the timeout never applies. The user MCP servers in
      # `mcp_servers` above and the ChatGPT login are both unaffected. What
      # stops working: every hosted app connector, the /apps command, and
      # ChatGPT-hosted plugins, which route through the same server.
      # See https://developers.openai.com/codex/config-reference
      apps = false;
      code_mode_host = true;
      hooks = true;
      # Disable Codex memories, the cross-session note system that summarises
      # past rollouts and injects them into later sessions. A centralised memory
      # system replaces it, matching the Claude Code opt-out. This flag is the
      # master gate; the [memories] table below repeats the opt-out per
      # direction so it holds if the gate default changes. The feature became
      # stable in Codex 0.145.0 and ships off by default, so this pins the
      # current default rather than changing behaviour. There is no environment
      # variable equivalent. See https://developers.openai.com/codex/memories
      memories = false;
      skill_mcp_dependency_install = false;
    };

    # Belt and braces alongside `features.memories` above. `use_memories` stops
    # existing memories being injected into a session; `generate_memories` stops
    # new ones being recorded. Codex writes these same keys itself when the
    # feature is toggled from the TUI, so declaring them keeps activation
    # authoritative over a runtime change.
    memories = {
      use_memories = false;
      generate_memories = false;
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

    model = "gpt-5.6-sol";
    model_reasoning_effort = "high";

    # Bound Codex subagent fan-out.
    agents = {
      max_threads = 10;
      max_depth = 2;
    };

    # Apply no vendor personality. The Communication Rules skill and tripwire
    # gate own the prose policy for this setup.
    # `personality` is an enum (none/friendly/pragmatic) and cannot carry the
    # rules text, so "none" keeps the vendor tone block from competing.
    personality = "none";

    # Inject the Communication Rules at the developer role, so the prose policy
    # applies from the first turn without waiting for a skill load. This is
    # additive: `model_instructions_file` is deliberately left unset, so Codex
    # keeps its built-in coding prompt, and `personality` deliberately stays
    # "none" above rather than carrying any of this text.
    developer_instructions = assistantCompose.houseStyleBody;

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
      # `project-name` shows only the project root's name, matching the
      # basename-only directory segment on the Claude Code and Pi lines. It
      # is omitted outside a detected project, where `current-dir` would
      # have shown the full path.
      status_line = [
        "model-with-reasoning"
        "fast-mode"
        "project-name"
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
  // lib.optionalAttrs (mcpServerDefs.codexOAuthCallbackPort != null) {
    mcp_oauth_callback_port = mcpServerDefs.codexOAuthCallbackPort;
    mcp_oauth_callback_url = mcpServerDefs.codexOAuthCallbackUrl;
  }
  // codexHooks;

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
    install_stable_binary() {
      source="$1"
      target="$2"
      mkdir -p "$(dirname "$target")"
      binary_tmp="$(mktemp "$(dirname "$target")/.install.XXXXXX")"
      cp "$source" "$binary_tmp"
      chmod 755 "$binary_tmp"
      mv -f "$binary_tmp" "$target"
    }

    install_codex_binary() {
      target="$1"
      if [ -x "${codexPackage}/bin/.codex-wrapped" ]; then
        install_stable_binary "${codexPackage}/bin/.codex-wrapped" "$target"
      else
        install_stable_binary "${codexPackage}/bin/codex" "$target"
      fi
      # Codex resolves the code-mode host as a sibling of current_exe(), so the
      # helper must sit beside every stable copy. Without it, code mode fails
      # closed and Codex falls back to direct tools.
      install_stable_binary \
        "${codexPackage}/bin/codex-code-mode-host" \
        "$(dirname "$target")/codex-code-mode-host"
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
    ${lib.concatMapStringsSep "\n" (
      target: ''install_stable_binary "${codexHerdrScript}" "${target}"''
    ) codexHerdrScriptPaths}
    ${lib.concatMapStringsSep "\n" (targetDir: ''merge_codex_config "${targetDir}"'') codexDirs}
  '';
in
lib.mkIf (isDeveloper && !host.is.server) {
  # Report whether Codex carries the house style in its system prompt. The
  # `developer_instructions` key in codexSettings is the carriage, so the flag
  # is read back from it: drop or empty that key and the Communication Rules
  # tripwire falls back to injecting the full rules on a fresh session. A Codex
  # sub-agent gets the full rules either way, since no developer instructions
  # reach a sub-agent context.
  agentic.houseStyle.inSystemPrompt.codex =
    config.programs.codex.enable
    && (codexSettings ? developer_instructions)
    && codexSettings.developer_instructions != "";

  home = {
    packages = [
      codexAcpPackage
      codexPruneRolloutsPackage
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

  # Enforce the rollout retention window on a daily schedule. macOS gets the
  # `codex-prune-rollouts` command but no timer, matching the agentsview mixin,
  # which also schedules on Linux only.
  systemd.user.services.codex-prune-rollouts = lib.mkIf host.is.linux {
    Unit.Description = "Prune Codex session rollouts older than ${toString rolloutRetentionDays} days";

    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe codexPruneRolloutsPackage;
    };
  };

  systemd.user.timers.codex-prune-rollouts = lib.mkIf host.is.linux {
    Unit.Description = "Prune Codex session rollouts on a schedule";

    Timer = {
      OnCalendar = "daily";
      RandomizedDelaySec = "1h";
      Persistent = true;
      Unit = "codex-prune-rollouts.service";
    };

    Install.WantedBy = [
      "timers.target"
    ];
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
