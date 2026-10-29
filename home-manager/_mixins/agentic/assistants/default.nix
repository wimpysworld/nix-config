{
  config,
  lib,
  noughtyLib,
  pkgs,
  ...
}:
let
  readFileTrim = path: lib.trim (builtins.readFile path);
  codexDir =
    if config.home.preferXdgDirectories then
      "${config.xdg.configHome}/codex"
    else
      "${config.home.homeDirectory}/.codex";
  # Import compose module
  compose = import ./compose.nix {
    inherit lib pkgs;
    gwsEnabled = noughtyLib.userHasTag "developer" && noughtyLib.hostHasTag "cg";
  };
  codingAgentDirs = lib.removeAttrs compose.agentDirs [ "traya" ];

  globalInstructions = readFileTrim ./instructions/global.md;
  piEnabled = noughtyLib.userHasTag "developer";
  diagramPalette = builtins.fromJSON (builtins.readFile ../../../../lib/catppuccin-palette.json);
  diagramColours =
    lib.concatMap
      (
        flavour:
        lib.mapAttrsToList (name: colour: {
          token = "@${flavour}.${name}@";
          value = colour.hex;
        }) diagramPalette.${flavour}.colors
      )
      [
        "latte"
        "mocha"
      ];
  diagramProfile = lib.replaceStrings (map (colour: colour.token) diagramColours) (map (
    colour: colour.value
  ) diagramColours) (builtins.readFile ./diagram-profiles/catppuccin-blue.md);

  # ============ SECRET COMMANDS ============

  # The fixed sops file holding every encrypted assistant prompt body. Each
  # secret command's `command.sops` marker names a top-level key in this file.
  assistantPromptsSopsFile = ../../../../secrets/assistant-prompts.yaml;

  # Collect every secret command with the
  # metadata each platform needs. A command is secret when its directory holds
  # a `command.sops` marker; compose.commandSecretInfo reads the marker and
  # rejects directories that also carry a plaintext command.md. The decrypted
  # body never enters the store: Claude, OpenCode, and Pi receive a sops
  # placeholder substituted at activation; Codex reads the decrypted secret
  # path from its activation script.
  secretCommandList = lib.mapAttrsToList (cmdName: entry: {
    inherit cmdName;
    cmdPath = entry.path;
    info = compose.commandSecretInfo cmdName;
  }) (lib.filterAttrs (_: entry: entry.secret) compose.commandRegistry);

  # sops secret declarations: one per distinct key referenced by a marker.
  secretCommandSecrets = lib.listToAttrs (
    map (
      entry: lib.nameValuePair entry.info.key { sopsFile = assistantPromptsSopsFile; }
    ) secretCommandList
  );

  # Per-platform destination paths for a secret command's rendered file.
  secretClaudePath = cmdName: "${config.home.homeDirectory}/.claude/commands/${cmdName}.md";
  secretOpencodePath = cmdName: "${config.xdg.configHome}/opencode/commands/${cmdName}.md";
  secretPiPath = cmdName: "${config.home.homeDirectory}/.pi/agent/prompts/${cmdName}.md";

  # sops templates for Claude, OpenCode, and Pi render in private sops paths.
  # The ownership helper links them to the explicit client destinations.
  # Pi reuses the subagent-launch prelude assembled for non-secret agent
  # commands so the placeholder body carries identical routing.
  secretCommandTemplates = lib.listToAttrs (
    lib.concatMap (
      entry:
      let
        inherit (entry) cmdName;
        sopsPlaceholder = config.sops.placeholder.${entry.info.key};
        claudeBody = compose.composeCommandFromPrompt "claude" cmdName sopsPlaceholder;
        opencodeBody = compose.composeCommandFromPrompt "opencode" cmdName sopsPlaceholder;
        piBody = compose.composeCommandFromPrompt "pi" cmdName sopsPlaceholder;
      in
      lib.optionals config.programs.claude-code.enable [
        (lib.nameValuePair "assistant-claude-command-${cmdName}" {
          content = claudeBody;
          path = secretClaudePath cmdName;
        })
      ]
      ++ lib.optionals config.programs.opencode.enable [
        (lib.nameValuePair "assistant-opencode-command-${cmdName}" {
          content = opencodeBody;
          path = secretOpencodePath cmdName;
        })
      ]
      ++ lib.optionals piEnabled [
        (lib.nameValuePair "assistant-pi-command-${cmdName}" {
          content = piBody;
          path = secretPiPath cmdName;
        })
      ]
    ) secretCommandList
  );

  # ============ SECRET SKILLS ============

  # Collect every secret skill with the metadata each platform needs. A skill
  # is secret when its directory holds a `SKILL.sops` marker instead of a
  # plaintext `SKILL.md`; supporting `.sops` markers render beside it so
  # progressive disclosure survives encryption. Decrypted bodies stay outside
  # the store. The ownership helper links rendered templates for Claude,
  # OpenCode, and Pi, and copies decrypted files for Codex.
  secretSkillList = lib.mapAttrsToList (skillName: _: {
    name = skillName;
    inherit ((compose.skillSecretInfo skillName)) key;
    supportFiles = compose.secretSkillSupportFiles skillName;
  }) compose.secretSkillDirs;

  # sops secret declarations: one per key referenced by a secret skill's
  # SKILL.sops marker or by any of its supporting markers.
  secretSkillSecrets = lib.listToAttrs (
    lib.concatMap (
      entry:
      [ (lib.nameValuePair entry.key { sopsFile = assistantPromptsSopsFile; }) ]
      ++ map (
        file: lib.nameValuePair file.key { sopsFile = assistantPromptsSopsFile; }
      ) entry.supportFiles
    ) secretSkillList
  );

  # Per-platform destination directory for a secret skill's rendered files.
  secretSkillClaudeDir = name: "${config.home.homeDirectory}/.claude/skills/${name}";
  secretSkillOpencodeDir = name: "${config.xdg.configHome}/opencode/skills/${name}";
  secretSkillPiDir = name: "${config.home.homeDirectory}/.pi/agent/skills/${name}";
  secretSkillMoltisDir = name: "${config.home.homeDirectory}/.moltis/skills/${name}";

  # sops template names double as filenames in the rendered-templates
  # directory, so a supporting file's relative path is flattened into a slug.
  secretSkillFileSlug =
    path:
    lib.replaceStrings
      [
        "/"
        "."
      ]
      [
        "-"
        "-"
      ]
      path;

  # sops templates for one platform. Unlike a secret command there is no public
  # frontmatter or prelude to compose around the body: the encrypted value is
  # the entire file, so each template's content is the placeholder alone.
  mkSecretSkillTemplates =
    platform: skillDir:
    lib.concatMap (
      entry:
      let
        dir = skillDir entry.name;
      in
      [
        (lib.nameValuePair "assistant-${platform}-skill-${entry.name}" {
          content = config.sops.placeholder.${entry.key};
          path = "${dir}/SKILL.md";
        })
      ]
      ++ map (
        file:
        lib.nameValuePair "assistant-${platform}-skill-${entry.name}-${secretSkillFileSlug file.path}" {
          content = config.sops.placeholder.${file.key};
          path = "${dir}/${file.path}";
        }
      ) entry.supportFiles
    ) secretSkillList;

  # Secret destinations follow the same client gates as public files.
  secretSkillTemplates = lib.listToAttrs (
    lib.optionals config.programs.claude-code.enable (
      mkSecretSkillTemplates "claude" secretSkillClaudeDir
    )
    ++ lib.optionals config.programs.opencode.enable (
      mkSecretSkillTemplates "opencode" secretSkillOpencodeDir
    )
    ++ lib.optionals piEnabled (mkSecretSkillTemplates "pi" secretSkillPiDir)
    ++ lib.optionals moltisEnabled (mkSecretSkillTemplates "moltis" secretSkillMoltisDir)
  );

  # ============ CLAUDE CODE ============

  claudeAgents = lib.mapAttrs (name: _: compose.composeAgent "claude" name) codingAgentDirs;
  claudeCommands = compose.composeCommands "claude";
  claudeInstructions = compose.composeInstructions "claude";

  # Claude Code output style carrying the house style. The source file is a
  # complete output style, frontmatter included, so it deploys verbatim with
  # a trailing newline restored after compose.nix trims it.
  claudeHouseStyle = compose.houseStyleOutputStyle + "\n";

  # ============ OPENCODE ============

  # Whether a composed instruction text ends with the house-style body, which is
  # how OpenCode and Pi carry the Communication Rules into their system prompt.
  carriesHouseStyle = text: lib.hasSuffix (compose.houseStyleBody + "\n") text;

  opencodeAgents = lib.mapAttrs (name: _: compose.composeAgent "opencode" name) codingAgentDirs;
  opencodeCommands = compose.composeCommands "opencode";
  # OpenCode has no output-style mechanism, so the house style is appended to
  # the global context instead. The composed instructions already end with a
  # newline, so a single extra newline leaves one blank line between them.
  opencodeInstructions =
    compose.composeInstructions "opencode" + "\n" + compose.houseStyleBody + "\n";

  # ============ PI AGENT ============

  # Pi uses its native Agent tool name. The composer adds the worker contract
  # and shared rules without changing other clients or specialist bodies.
  piAgentFiles = lib.mapAttrs' (
    name: _:
    let
      agentPath = ./agents + "/${name}";
      prompt = readFileTrim (agentPath + "/prompt.md");
    in
    {
      name = ".pi/agent/agents/${name}.md";
      value.text = compose.composeAgentFromPrompt "pi" name (compose.adaptAgentPrompt "pi" prompt);
    }
  ) codingAgentDirs;
  piSkillFiles = lib.mapAttrs' (name: skill: {
    name = ".pi/agent/skills/${name}";
    value.source = skill.path;
  }) piSkills;
  piPromptFiles = lib.mapAttrs' (cmdName: _: {
    name = ".pi/agent/prompts/${cmdName}.md";
    value.text = compose.composeCommand "pi" cmdName;
  }) (lib.filterAttrs (_: entry: !entry.secret) compose.commandRegistry);
  piCommandSources = compose.commandSources;
  piCommandCollisionCheck = compose.assertNoCommandCollisions {
    context = "Pi prompts (~/.pi/agent/prompts/)";
    sources = piCommandSources;
  };
  # Force the collision check before assembling the Pi home files. The
  # `seq` forces evaluation of `piCommandCollisionCheck`, which either
  # returns `true` or throws with the colliding command name and source
  # paths.
  piHomeFiles = builtins.seq piCommandCollisionCheck (
    {
      # Pi has no output-style mechanism, so the house style is appended to
      # the global instructions. `globalInstructions` is trimmed, so two
      # newlines leave one blank line between them.
      ".pi/agent/AGENTS.md".text = globalInstructions + "\n\n" + compose.houseStyleBody + "\n";
    }
    // piAgentFiles
    // piSkillFiles
    // piPromptFiles
  );
  opencodeProviderRouterMap = lib.filterAttrs (_: models: models != { }) (
    lib.mapAttrs (name: _: compose.extractOpenCodeProviderModels name) codingAgentDirs
  );
  opencodeProviderRouterVariantMap = lib.filterAttrs (_: variants: variants != { }) (
    lib.mapAttrs (name: _: compose.extractOpenCodeProviderVariants name) codingAgentDirs
  );
  piProviderRouterMap = lib.filterAttrs (_: models: models != { }) (
    lib.mapAttrs (name: _: compose.extractAgentProviderModels name) codingAgentDirs
  );
  piProviderRouterThinkingMap = lib.filterAttrs (_: levels: levels != { }) (
    lib.mapAttrs (name: _: compose.extractAgentProviderThinking name) codingAgentDirs
  );

  # ============ MOLTIS ============

  # Same host gate that `moltis/default.nix` and `mcp/default.nix` use.
  moltisEnabled =
    noughtyLib.isUser [ "martin" ] && config.noughty.host.is.linux && noughtyLib.hostHasTag "moltis";
  moltisSopsFile = ../../../../secrets/moltis.yaml;
  moltisAgentName = if config.noughty.host.name == "malak" then "traya" else config.noughty.host.name;
  moltisSoulKey = "SOUL_${lib.toUpper moltisAgentName}";
  moltisSoulSecrets = lib.optionalAttrs moltisEnabled {
    ${moltisSoulKey} = {
      sopsFile = moltisSopsFile;
    };
    SOUL_ALL = {
      sopsFile = moltisSopsFile;
    };
    USER = {
      sopsFile = moltisSopsFile;
    };
  };
  moltisSoulTemplates = lib.optionalAttrs moltisEnabled {
    assistant-moltis-soul = {
      content = "${config.sops.placeholder.${moltisSoulKey}}\n\n${config.sops.placeholder.SOUL_ALL}\n";
    };
    assistant-moltis-user = {
      content = "${config.sops.placeholder.USER}\n";
    };
  };
  moltisSoulOwnedFiles = lib.optionals moltisEnabled (
    map
      (path: {
        inherit path;
        source = config.sops.templates."assistant-moltis-soul".path;
        kind = "file";
        mode = "0600";
      })
      [
        "${config.home.homeDirectory}/.moltis/SOUL.md"
        "${config.home.homeDirectory}/.moltis/agents/main/SOUL.md"
      ]
    ++ map
      (path: {
        inherit path;
        source = config.sops.templates."assistant-moltis-user".path;
        kind = "file";
        mode = "0600";
      })
      [
        "${config.home.homeDirectory}/.moltis/USER.md"
        "${config.home.homeDirectory}/.moltis/agents/main/USER.md"
      ]
  );

  # Moltis loads ~/.moltis/AGENTS.md as workspace agent instructions and seeds
  # ~/.moltis/agents/main/AGENTS.md from it on first run, reading the main
  # workspace copy first. Deploy both paths through ownedFiles as regular files
  # so neither copy drifts. Plain markdown, no frontmatter. It carries the
  # house style the same way the Pi and OpenCode system prompts do.
  moltisGlobalInstructions = readFileTrim ../moltis/AGENTS.md;
  moltisInstructions = moltisGlobalInstructions + "\n\n" + compose.houseStyleBody + "\n";
  moltisIdentity = readFileTrim (../moltis + "/IDENTITY_${lib.toUpper moltisAgentName}.md") + "\n";
  moltisSchedule =
    if moltisAgentName == "skrye" then
      {
        agentDisplayName = "Skrye";
        dayName = "Wednesday";
        dow = "3";
      }
    else if moltisAgentName == "zannah" then
      {
        agentDisplayName = "Zannah";
        dayName = "Saturday";
        dow = "6";
      }
    else
      {
        agentDisplayName = "Traya";
        dayName = "Sunday";
        dow = "7";
      };
  moltisHeartbeat =
    lib.replaceStrings
      [
        "@AGENT_NAME@"
        "@SCHEDULE_DAY_NAME@"
        "@SCHEDULE_DOW@"
      ]
      [
        moltisSchedule.agentDisplayName
        moltisSchedule.dayName
        moltisSchedule.dow
      ]
      (readFileTrim ../moltis/HEARTBEAT.md)
    + "\n";
  moltisLegacyInstructionsHash = builtins.hashString "sha256" (
    globalInstructions + "\n\n" + compose.houseStyleBody + "\n"
  );
  moltisCurrentInstructionsHash = builtins.hashString "sha256" moltisInstructions;
  moltisCurrentIdentityHash = builtins.hashString "sha256" moltisIdentity;
  moltisCurrentHeartbeatHash = builtins.hashString "sha256" moltisHeartbeat;
  moltisIdentityLegacyHashes = [
    moltisCurrentIdentityHash
    "67f9aa462e69609eff631923e0c9d5ad8f0cc537046c166d608e9582b7c29e18"
    "cca66bd3ab3ee4a3000793936fe9c3115342e9e74aa1271cc607463a57c0a358"
    "180a03c54a422909bdcb53dabe1534ea8dcde19ff6f978da1911f5d15bf821f4"
    "924884a238b7e291616b4af2cab5071765c0cfa12359a4b78fa58901d570eccf"
    "a78716a36b95031770ea9e59c74b20836a8372f5734e156ef33471b08798a9ce"
    "190b565f161dcdc430f66ea24db8acd1ebe6c4a39dd860a1564c61254db36272"
    "5fb63443e462d916dd22c10238d5034b0bfe9311df2d1fe3e88c97e77c18af1e"
    "05b4233d3e2ce0e14e6c7a8d60cdc6f41f8304a01732615481f0c430282f5e39"
    "7e0c314dce268a5ca40a70c313152dcff2f98ffb517c12769179f031e0bdeb67"
    "ddd74095bc580c6726974d26d73a08fe5db62482103f5a6bf7227fe7744555cb"
    "b60037a32303a617da4fb0d837e9b0e6fc4b3d52800875c7a5069294071cb028"
    "a63f2f59dec8eb31187a313afffbdbc2ba455d30ecad3a358d0a2cdb4e7726d5"
    "5dab0018740233f2df6674d6bc1ef1e5acf0ccc3be6fb830ff5fbfcbdc3ee603"
    "a2e3d16f6b15c2a2acea1dd40a6d9945d6fa936eff7502b4994f49ba9bb9abe2"
    "1ce22fc3176e5dfbfce0ee49a85d313d1f02a5d2ef658bf5815705734eddba4d"
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  ];
  moltisHeartbeatLegacyHashes = [
    moltisCurrentHeartbeatHash
    "f5fbea7130a450caa5acdedadce24aa16a08d4bc2ed42c7ed056612cb790bf5d"
    "2a637af01a613be9b3e6566acf00e2e03573d56cdd30a35c563506a1ba3c4704"
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  ];

  # Recover ownership of Moltis-seeded default workspace files (AGENTS.md,
  # SOUL.md, IDENTITY.md, and HEARTBEAT.md in ~/.moltis and ~/.moltis/agents/main)
  # and prune any leftover /nix/store symlinks under ~/.moltis/skills before
  # assistantOwnedFiles runs.
  moltisBootstrapScript = pkgs.writeText "moltis-assistant-bootstrap.py" ''
    import hashlib
    import json
    import os
    from pathlib import Path
    import stat
    import tempfile

    moltis_root = Path(${builtins.toJSON "${config.home.homeDirectory}/.moltis"})
    bootstrap_path = Path(${builtins.toJSON "${config.xdg.stateHome}/agentic/assistants/bootstrap.json"})
    legacy_hashes = {
        moltis_root / "AGENTS.md": {
            ${builtins.toJSON moltisLegacyInstructionsHash},
            ${builtins.toJSON moltisCurrentInstructionsHash},
            "b49b0d17217e3362d3095907f33f9ca2765e7465095cdc08d44a0ad5470679ea",
            "9dd888f8a07009f4bccc05149a7117819887aa87a49e7be7f8788d4c5ae87b02",
            "f5986e6d8ffd5168a0e00cc4d39b2619e836f56313c0224b5e855872f857a363",
        },
        moltis_root / "agents/main/AGENTS.md": {
            ${builtins.toJSON moltisLegacyInstructionsHash},
            ${builtins.toJSON moltisCurrentInstructionsHash},
            "b49b0d17217e3362d3095907f33f9ca2765e7465095cdc08d44a0ad5470679ea",
            "9dd888f8a07009f4bccc05149a7117819887aa87a49e7be7f8788d4c5ae87b02",
            "f5986e6d8ffd5168a0e00cc4d39b2619e836f56313c0224b5e855872f857a363",
        },
        moltis_root / "SOUL.md": {
            "36ea5d9157979ce51cac0730f4fc4402bbe6944ea8f8e30cfca2ea316e7b7e40",
            "95c467f710183b2c0397c29ec4ef886bb723671a39ee767dc4d59165f723b68f",
        },
        moltis_root / "agents/main/SOUL.md": {
            "36ea5d9157979ce51cac0730f4fc4402bbe6944ea8f8e30cfca2ea316e7b7e40",
            "95c467f710183b2c0397c29ec4ef886bb723671a39ee767dc4d59165f723b68f",
        },
        moltis_root / "IDENTITY.md": set(${builtins.toJSON moltisIdentityLegacyHashes}),
        moltis_root / "agents/main/IDENTITY.md": set(${builtins.toJSON moltisIdentityLegacyHashes}),
        moltis_root / "HEARTBEAT.md": set(${builtins.toJSON moltisHeartbeatLegacyHashes}),
        moltis_root / "agents/main/HEARTBEAT.md": set(${builtins.toJSON moltisHeartbeatLegacyHashes}),
    }


    def is_store_symlink(path):
        if not path.is_symlink():
            return False
        target = Path(os.readlink(path))
        return (
            target.is_absolute()
            and ".." not in target.parts
            and target.is_relative_to("/nix/store")
        )


    if not any(parent.is_symlink() for parent in (moltis_root, *moltis_root.parents)):
        for path in legacy_hashes:
            if not any(parent.is_symlink() for parent in path.parents) and is_store_symlink(path):
                path.unlink()
        skills_dir = moltis_root / "skills"
        if skills_dir.is_dir() and not skills_dir.is_symlink():
            for root, dirnames, filenames in os.walk(
                skills_dir, topdown=False, followlinks=False
            ):
                root_path = Path(root)
                for name in [*filenames, *dirnames]:
                    candidate = root_path / name
                    if is_store_symlink(candidate):
                        candidate.unlink()
                if root_path != skills_dir and not root_path.is_symlink():
                    try:
                        root_path.rmdir()
                    except OSError:
                        pass

    verified = {}
    for path, allowed_hashes in legacy_hashes.items():
        if any(parent.is_symlink() for parent in path.parents):
            continue
        try:
            info = path.lstat()
        except FileNotFoundError:
            continue
        if stat.S_ISREG(info.st_mode):
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if digest in allowed_hashes:
                verified[str(path)] = {"kind": "file", "sha256": digest}

    if verified and not any(
        parent.is_symlink()
        for parent in (bootstrap_path.parent, *bootstrap_path.parent.parents)
    ):
        data = {"version": 1, "files": {}, "directories": []}
        if bootstrap_path.exists():
            info = bootstrap_path.lstat()
            if (
                not stat.S_ISREG(info.st_mode)
                or info.st_uid != os.getuid()
                or stat.S_IMODE(info.st_mode) != 0o600
            ):
                raise ValueError(
                    "Existing bootstrap must be a private regular file owned by the current user"
                )
            loaded = json.loads(bootstrap_path.read_text())
            if (
                isinstance(loaded, dict)
                and loaded.get("version") == 1
                and isinstance(loaded.get("files"), dict)
            ):
                data = loaded
        data["files"].update(verified)
        bootstrap_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.chmod(bootstrap_path.parent, 0o700)
        fd, temporary = tempfile.mkstemp(
            prefix=".bootstrap-", dir=bootstrap_path.parent
        )
        try:
            with os.fdopen(fd, "w") as handle:
                os.fchmod(handle.fileno(), 0o600)
                json.dump(data, handle, sort_keys=True)
                handle.write("\n")
            os.replace(temporary, bootstrap_path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
  '';

  # Moltis agent presets are markdown files under ~/.moltis/agents/ with YAML
  # frontmatter. AgentFrontmatter in Moltis (crates/config/src/agent_defs.rs)
  # has no `description` field; `theme` carries free-text identity text, so the
  # common description deploys there. The body becomes the preset's
  # `system_prompt_suffix`. Deployment stays file by file because Moltis
  # writes runtime agent workspaces into ~/.moltis/agents/.
  moltisAgentPrompt =
    name:
    let
      agentPath = ./agents + "/${name}";
      core = (compose.readHeader agentPath).common.description or "";
      body = lib.concatStringsSep "\n\n" [
        # Moltis sub-agents spawn via `spawn_agent`, matching the Codex
        # adaptation strings in compose.adaptAgentPrompt.
        (lib.replaceStrings
          [
            "Task tool"
            "Permitted tools: Task tool for delegation, direct conversation"
          ]
          [
            "`spawn_agent` tool"
            "Permitted tools: `spawn_agent` for delegation, direct conversation"
          ]
          (readFileTrim (agentPath + "/prompt.md"))
        )
        compose.leafWorkerContract
        ''
          ## Shared safety rules

          Read the applicable project instructions before work in that project.
          Preserve unrelated changes. Do not delete files or backups without explicit consent.
          Do not change external state without explicit authority in the task packet.
          Do not expose secrets, tokens, or credentials.
          Use read, edit, and write for files. Use current reference tools for technical documentation.
          When `mcp__*` direct tools are unavailable in a `spawn_agent` sub-agent, use `mcporter list <server>` and `mcporter call <server>.<tool> ...` via `exec` to query `linear`, `exa`, and `context7`.
          Load required skills before dependent work. Loading a skill grants no additional authority.
        ''
        compose.houseStyleBody
      ];
    in
    "---\nname: ${name}\ntheme: ${core}\n---\n\n${body}\n";

  moltisAgentFiles = lib.mapAttrs' (name: _: {
    name = "${config.home.homeDirectory}/.moltis/agents/${name}.md";
    value.text = moltisAgentPrompt name;
  }) codingAgentDirs;

  # Moltis discovers personal skills one level deep under ~/.moltis/skills/,
  # and `read_skill` (crates/tools/src/skill_tools/read_ops.rs) rejects
  # symlinked skill directories and symlinked sidecar files outside the
  # canonical skill directory. Every Moltis skill file therefore deploys
  # through `ownedFiles` as a regular file (`kind = "file"`).
  moltisSkills = compose.composeSkillsFor "moltis";
  listFilesRecursive =
    dir:
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        if name == "header.toml" then
          [ ]
        else if type == "directory" then
          map (rel: "${name}/${rel}") (listFilesRecursive (dir + "/${name}"))
        else
          [ name ]
      ) (builtins.readDir dir)
    );
  moltisSkillExtraPaths =
    name: skill:
    lib.concatLists (
      lib.mapAttrsToList (
        entryName: entryType:
        if entryType == "directory" then
          map (relPath: "${entryName}/${relPath}") (listFilesRecursive (./skills + "/${name}/${entryName}"))
        else
          [ entryName ]
      ) (skill.extras or { })
    );

  # Moltis has no slash-command surface, so selected commands deploy as
  # skills, mirroring Moltis' own importer (import-core
  # create_skill_from_command). An entry qualifies only when its command.toml
  # proves `caller-context = true` (the body runs in the caller's context, so
  # no dispatch wrapper is needed) and its body assumes no native platform
  # tooling (no Task tool, spawn_agent, gh, Slack, or Herdr references).
  # Body inspection proved these nine: each is a conversational or context
  # command that only references projected skills. Secret commands
  # (draft-self-review, gather-review-data, review-open-source-attestation)
  # and dispatch-bound commands stay unmapped.
  moltisCommandAllowlist = [
    "ack"
    "ahem"
    "ask"
    "call"
    "clarify-plan"
    "gist"
    "handover-fresh"
    "oi"
    "ready"
  ];

  # Render one allowlisted command as a Moltis skill. composeWithFrontmatter
  # is not exported, so the frontmatter wrapper is built inline the way
  # composeCodexCommandSkillFromPrompt does. The description comes from the
  # validated command.toml header rather than the importer's lossy
  # first-paragraph heuristic.
  mkMoltisCommandSkill =
    cmdName:
    let
      entry = compose.commandRegistry.${cmdName};
      description = entry.header.common.description;
    in
    ''
      ---
      name: ${builtins.toJSON cmdName}
      description: ${builtins.toJSON description}
      ---

      <!-- Imported from: agentic command ${cmdName} -->

      ${readFileTrim (entry.path + "/command.md")}
    '';

  # Collision guard for the flat ~/.moltis/skills/ namespace. The deployed
  # names are exactly the project skills (moltisSkills), the secret skills
  # (secretSkillList, deployed from sops templates), the Chainguard skills
  # (deployed from ~/Chainguard/.agents/ when present), and the command-derived
  # skills from the allowlist. Secret commands never map, so the allowlist is
  # the only command source.
  moltisCommandSources =
    map (name: {
      inherit name;
      source = "skill: ${name}";
    }) (builtins.attrNames moltisSkills)
    ++ map (entry: {
      inherit (entry) name;
      source = "skill: ${entry.name}";
    }) secretSkillList
    ++ [
      {
        name = "self-review";
        source = "chainguard-skill: self-review";
      }
    ]
    ++ map (cmdName: {
      name = cmdName;
      source = "command: ${cmdName}";
    }) moltisCommandAllowlist;
  moltisCommandCollisionCheck = compose.assertNoCommandCollisions {
    context = "Moltis skills (~/.moltis/skills/)";
    sources = moltisCommandSources;
  };

  # Force the collision check before assembling the Moltis skill entries in
  # `ownedFiles`. The `seq` forces evaluation of `moltisCommandCollisionCheck`,
  # which either returns `true` or throws with the colliding name and source
  # paths.
  moltisOwnedFiles = builtins.seq moltisCommandCollisionCheck (
    [
      (ownedFile "${config.home.homeDirectory}/.moltis/AGENTS.md" moltisInstructions)
      (ownedFile "${config.home.homeDirectory}/.moltis/agents/main/AGENTS.md" moltisInstructions)
      (ownedFile "${config.home.homeDirectory}/.moltis/IDENTITY.md" moltisIdentity)
      (ownedFile "${config.home.homeDirectory}/.moltis/agents/main/IDENTITY.md" moltisIdentity)
      (ownedFile "${config.home.homeDirectory}/.moltis/HEARTBEAT.md" moltisHeartbeat)
      (ownedFile "${config.home.homeDirectory}/.moltis/agents/main/HEARTBEAT.md" moltisHeartbeat)
    ]
    ++ lib.concatLists (
      lib.mapAttrsToList (
        name: skill:
        [
          (ownedFile "${config.home.homeDirectory}/.moltis/skills/${name}/SKILL.md" skill.content)
        ]
        ++ map (relPath: {
          path = "${config.home.homeDirectory}/.moltis/skills/${name}/${relPath}";
          source = "${skill.path}/${relPath}";
          kind = "file";
          mode = "0600";
        }) (moltisSkillExtraPaths name skill)
      ) moltisSkills
    )
    ++ map (
      cmdName:
      ownedFile "${config.home.homeDirectory}/.moltis/skills/${cmdName}/SKILL.md" (
        mkMoltisCommandSkill cmdName
      )
    ) moltisCommandAllowlist
  );

  # ============ SKILLS ============

  # composeSkills returns { name = { content; path; extras; }; ... }
  # where `extras` enumerates sibling files and subdirectories alongside
  # SKILL.md (e.g. references/, rules/, metadata.json) that must be deployed
  # for the skill to function.
  skills = compose.composeSkillsFor "codex";
  claudeSkills = compose.composeSkillsFor "claude";
  opencodeSkills = compose.composeSkillsFor "opencode";
  piSkills = compose.composeSkillsFor "pi";

  # Codex's activation script expects { name = "SKILL.md content"; ... } so
  # it can merge in command-derived skill texts. Project skills only.
  skillContents = lib.mapAttrs (_: skill: skill.content) skills;

  # Generate home.file entries for Claude Code skills.
  # Symlink the entire skill directory so SKILL.md plus all supporting files
  # and subdirectories (references/, rules/, metadata.json, ...) deploy as
  # a single tree under ~/.claude/skills/<name>/.
  mkClaudeSkillFiles = lib.mapAttrs' (name: skill: {
    name = "${config.home.homeDirectory}/.claude/skills/${name}";
    value.source = skill.path;
  }) claudeSkills;

  # Generate home.file entries for OpenCode skills.
  # Same approach: symlink the whole skill directory under
  # ${XDG_CONFIG_HOME}/opencode/skills/<name>/.
  mkOpencodeSkillFiles = lib.mapAttrs' (name: skill: {
    name = "${config.xdg.configHome}/opencode/skills/${name}";
    value.source = skill.path;
  }) opencodeSkills;

  # Collect all Codex agent name -> TOML content pairs.
  # codex-rs discovers agent roles by scanning the agents/ directory for .toml
  # files using file_type().is_file(), which returns false for symlinks on Linux.
  # home.file creates symlinks, so agents written via home.file are invisible.
  # Content is written as real files via the activation script below.
  codexAgents = lib.mapAttrs (name: _: compose.composeCodexAgent name) codingAgentDirs;

  # Build a Codex skill file (SKILL.md) for a command.
  # Custom prompt support was removed from codex-rs in March 2026. Commands
  # are instead deployed as skills under $CODEX_HOME/skills/ and invoked with
  # $skill-name in the TUI. Each skill requires name and description frontmatter.
  # For agent-bound commands the default is spawn dispatch: the generated
  # skill instructs the parent thread to call `spawn_agent` with the owning
  # agent as `agent_type`, preserving the coordinator and isolating the
  # task in a fresh sub-thread. The owning agent's persona is therefore
  # resolved at runtime by Codex's agent role config, not embedded in the
  # skill body. Opt out of spawn dispatch by setting `spawn-agent = false`
  # in `command.toml`; the composer then embeds the agent's `prompt.md`
  # verbatim before the task body so the skill carries the full persona in
  # the calling thread. Set compose.caller-context to keep the caller's context without
  # a launch wrapper or an embedded specialist persona.
  # The skill name itself is the bare command name, matching the Pi prompt
  # convention. The `codexCommandCollisionCheck` below guards the full native
  # and command-derived skill namespace.
  mkCodexSkillFromPrompt = compose.composeCodexCommandSkillFromPrompt;
  mkCodexSkillText = skillName: _cmdPath: compose.composeCodexCommandSkill skillName;

  # Command-derived skills always require explicit invocation. A header can
  # repeat the false policy but cannot enable implicit invocation.
  mkCodexCommandOpenAiYaml =
    cmdPath: compose.composeCodexCommandCompanion (builtins.baseNameOf cmdPath);

  # Collision guard for the Codex skill namespace. Codex loads every skill
  # from `$CODEX_HOME/skills/<name>/SKILL.md`, so the keyspace is the union
  # of native skills and command-derived skills.
  # Project skills have no single source path, so a synthetic `skill:<name>`
  # identifier is used in the throw message to make the origin obvious. Secret
  # skills are absent from `skillContents`, so they are listed separately;
  # without them a command could silently overwrite a secret skill's directory.
  chainguardAgentsDir = "${config.home.homeDirectory}/Chainguard/.agents";
  chainguardCommands = [
    "draft-self-review"
    "gather-review-data"
    "review-open-source-attestation"
  ];
  chainguardSkillFiles = [
    "skills/self-review/SKILL.md"
    "skills/self-review/references/cycle-mechanics.md"
  ];

  codexCommandSources =
    lib.mapAttrsToList (name: _: {
      inherit name;
      source = "skill: ${name}";
    }) skillContents
    ++ map (entry: {
      inherit (entry) name;
      source = "skill: ${entry.name}";
    }) secretSkillList
    ++ [
      {
        name = "self-review";
        source = "chainguard-skill: self-review";
      }
    ]
    ++ map (name: {
      inherit name;
      source = "chainguard-command: ${name}";
    }) chainguardCommands
    ++ compose.commandSources;
  codexCommandCollisionCheck = compose.assertNoCommandCollisions {
    context = "Codex skills (~/.codex/skills/)";
    sources = codexCommandSources;
  };

  publicCommandRegistry = lib.filterAttrs (_: entry: !entry.secret) compose.commandRegistry;
  codexSkills = builtins.seq codexCommandCollisionCheck (
    skillContents
    // lib.mapAttrs (cmdName: entry: mkCodexSkillText cmdName entry.path) publicCommandRegistry
  );

  codexCommandOpenAiYamls = builtins.seq codexCommandCollisionCheck (
    lib.mapAttrs (_: entry: mkCodexCommandOpenAiYaml entry.path) publicCommandRegistry
  );

  ownedFile = path: content: {
    inherit path;
    kind = "file";
    source = toString (pkgs.writeText (builtins.baseNameOf path) content);
    mode = "0600";
  };

  codexOwnedFiles = [
    (ownedFile "${codexDir}/AGENTS.md" (globalInstructions + "\n"))
  ]
  ++ lib.mapAttrsToList (
    name: content: ownedFile "${codexDir}/agents/${name}.toml" content
  ) codexAgents
  ++ lib.concatLists (
    lib.mapAttrsToList (
      name: content:
      [ (ownedFile "${codexDir}/skills/${name}/SKILL.md" content) ]
      ++ lib.mapAttrsToList (entryName: _: {
        path = "${codexDir}/skills/${name}/${entryName}";
        source = "${skills.${name}.path}/${entryName}";
        kind = "symlink";
      }) (skills.${name}.extras or { })
      ++ lib.optional (codexCommandOpenAiYamls ? ${name}) (
        ownedFile "${codexDir}/skills/${name}/agents/openai.yaml" codexCommandOpenAiYamls.${name}
      )
    ) codexSkills
  );

  codexSecretOwnedFiles =
    lib.concatMap (
      entry:
      let
        inherit (entry) cmdName cmdPath;
        openAiYaml = mkCodexCommandOpenAiYaml cmdPath;
      in
      [
        {
          path = "${codexDir}/skills/${cmdName}/SKILL.md";
          source = config.sops.secrets.${entry.info.key}.path;
          prefix = mkCodexSkillFromPrompt cmdName "";
          kind = "file";
          mode = "0600";
        }
      ]
      ++ lib.optional (openAiYaml != null) (
        ownedFile "${codexDir}/skills/${cmdName}/agents/openai.yaml" openAiYaml
      )
    ) secretCommandList
    ++ lib.concatMap (
      entry:
      let
        file = key: relativePath: {
          path = "${codexDir}/skills/${entry.name}/${relativePath}";
          source = config.sops.secrets.${key}.path;
          kind = "file";
          mode = "0600";
        };
      in
      [ (file entry.key "SKILL.md") ] ++ map (support: file support.key support.path) entry.supportFiles
    ) secretSkillList;

  secretTemplates = secretCommandTemplates // secretSkillTemplates;
  secretOwnedFiles =
    lib.mapAttrsToList (
      name: template:
      let
        isMoltis = lib.hasPrefix "assistant-moltis-skill-" name;
      in
      {
        inherit (template) path;
        source = config.sops.templates.${name}.path;
        kind = if isMoltis then "file" else "symlink";
      }
      // lib.optionalAttrs isMoltis {
        mode = "0600";
      }
    ) secretTemplates
    ++ moltisSoulOwnedFiles;

  optionalSymlink = path: source: {
    inherit path source;
    kind = "symlink";
    optional = true;
  };
  optionalFile = path: source: {
    inherit path source;
    kind = "file";
    mode = "0600";
    optional = true;
  };

  chainguardClientOwnedFiles =
    lib.optionals config.programs.claude-code.enable (
      map (
        cmdName:
        optionalSymlink (secretClaudePath cmdName) "${chainguardAgentsDir}/claude/commands/${cmdName}.md"
      ) chainguardCommands
      ++ map (
        relPath:
        optionalSymlink "${config.home.homeDirectory}/.claude/${relPath}" "${chainguardAgentsDir}/${relPath}"
      ) chainguardSkillFiles
    )
    ++ lib.optionals config.programs.opencode.enable (
      map (
        cmdName:
        optionalSymlink (secretOpencodePath cmdName) "${chainguardAgentsDir}/opencode/commands/${cmdName}.md"
      ) chainguardCommands
      ++ map (
        relPath:
        optionalSymlink "${config.xdg.configHome}/opencode/${relPath}" "${chainguardAgentsDir}/${relPath}"
      ) chainguardSkillFiles
    )
    ++ lib.optionals piEnabled (
      map (
        cmdName: optionalSymlink (secretPiPath cmdName) "${chainguardAgentsDir}/pi/prompts/${cmdName}.md"
      ) chainguardCommands
      ++ map (
        relPath:
        optionalSymlink "${config.home.homeDirectory}/.pi/agent/${relPath}" "${chainguardAgentsDir}/${relPath}"
      ) chainguardSkillFiles
    )
    ++ lib.optionals moltisEnabled (
      map (
        relPath:
        optionalFile "${config.home.homeDirectory}/.moltis/${relPath}" "${chainguardAgentsDir}/${relPath}"
      ) chainguardSkillFiles
    );

  chainguardCodexOwnedFiles =
    lib.concatMap (cmdName: [
      (optionalFile "${codexDir}/skills/${cmdName}/SKILL.md" "${chainguardAgentsDir}/codex/skills/${cmdName}/SKILL.md")
      (optionalFile "${codexDir}/skills/${cmdName}/agents/openai.yaml" "${chainguardAgentsDir}/codex/skills/${cmdName}/agents/openai.yaml")
    ]) chainguardCommands
    ++ map (
      relPath: optionalFile "${codexDir}/${relPath}" "${chainguardAgentsDir}/${relPath}"
    ) chainguardSkillFiles;

  ownedFiles =
    lib.optionals config.programs.codex.enable (
      codexOwnedFiles ++ codexSecretOwnedFiles ++ chainguardCodexOwnedFiles
    )
    ++ lib.optionals moltisEnabled moltisOwnedFiles
    ++ secretOwnedFiles
    ++ chainguardClientOwnedFiles;
  ownedDeployment = import ./owned-deployment.nix {
    inherit
      config
      lib
      pkgs
      ownedFiles
      ;
    # The moltis secret-skill sops templates deploy under ~/.moltis/skills/,
    # so the moltis root joins the spec only when the moltis gate is active;
    # hosts without the deployment keep the previous root set.
    extraRoots = lib.optionals moltisEnabled [ "${config.home.homeDirectory}/.moltis" ];
    requiresSecrets =
      secretOwnedFiles != [ ] || (config.programs.codex.enable && codexSecretOwnedFiles != [ ]);
  };
in
{
  options.agentic.assistants.ownedSpec = lib.mkOption {
    type = lib.types.attrs;
    internal = true;
    description = "Desired assistant files and permitted ownership roots.";
  };
  options.agentic.assistants.requiresSecrets = lib.mkOption {
    type = lib.types.bool;
    internal = true;
    description = "Whether assistant deployment requires a successful secret refresh.";
  };
  options.agentic.assistants.opencode.providerRouterMap = lib.mkOption {
    type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
    default = { };
    internal = true;
    description = "Exact provider and model routes for the local OpenCode task plugin.";
  };
  options.agentic.assistants.opencode.providerRouterVariantMap = lib.mkOption {
    type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
    default = { };
    internal = true;
    description = "Per-agent provider->variant map for the local OpenCode task plugin, as a sidecar to providerRouterMap.";
  };
  options.agentic.assistants.pi = {
    homeFiles = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      internal = true;
      description = "Home Manager file entries for Pi Agent assistant resources.";
    };
    providerRouterMap = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = { };
      internal = true;
      description = "Per-agent provider->modelId map read from header.toml routing.pi. Consumed by the local pi-provider-router extension.";
    };
    providerRouterThinkingMap = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = { };
      internal = true;
      description = "Per-agent provider->thinking-level map read from header.toml routing.pi. Consumed by the local pi-provider-router extension as a sidecar to providerRouterMap.";
    };
  };

  config = {
    agentic.assistants.opencode.providerRouterMap = opencodeProviderRouterMap;
    agentic.assistants.opencode.providerRouterVariantMap = opencodeProviderRouterVariantMap;
    agentic.assistants.ownedSpec = ownedDeployment.spec;
    agentic.assistants.requiresSecrets = ownedDeployment.requiresSecrets;
    # Report whether OpenCode and Pi carry the house style in their system
    # prompt. Neither has an output-style mechanism, so the carriage is the
    # append to their global instructions below. The flag is read back from the
    # composed text rather than assumed: drop the append and the Communication
    # Rules tripwire falls back to injecting the full rules on a fresh context.
    agentic.houseStyle.inSystemPrompt = {
      opencode = config.programs.opencode.enable && carriesHouseStyle opencodeInstructions;
      pi = piEnabled && carriesHouseStyle piHomeFiles.".pi/agent/AGENTS.md".text;
    };

    agentic.assistants.pi = {
      homeFiles = piHomeFiles;
      providerRouterMap = piProviderRouterMap;
      providerRouterThinkingMap = piProviderRouterThinkingMap;
    };

    # Render secrets privately before the ownership helper installs client files.
    sops = {
      secrets = secretCommandSecrets // secretSkillSecrets // moltisSoulSecrets;
      templates =
        lib.mapAttrs (_: template: builtins.removeAttrs template [ "path" ]) secretTemplates
        // moltisSoulTemplates;
    };

    home = {
      packages = lib.optional (
        config.programs.claude-code.enable
        || config.programs.opencode.enable
        || config.programs.codex.enable
        || piEnabled
        || moltisEnabled
      ) pkgs.python3;

      file = lib.mkMerge [
        (lib.mkIf (noughtyLib.isUser [ "martin" ]) {
          ".diagram-design/preferences".text = lib.mkDefault "profile: catppuccin-blue\n";
          ".diagram-design/profiles/catppuccin-blue.md".text = diagramProfile;
        })
        (lib.mkIf config.programs.claude-code.enable (
          {
            # Claude Code global instructions
            "${config.home.homeDirectory}/.claude/rules/instructions.md".text = claudeInstructions;

            # Claude Code output style carrying the house style.
            "${config.home.homeDirectory}/.claude/output-styles/house-style.md".text = claudeHouseStyle;
          }
          # Claude Code skill files
          // mkClaudeSkillFiles
        ))
        # OpenCode skill files
        (lib.mkIf config.programs.opencode.enable mkOpencodeSkillFiles)
        # Moltis agent presets
        (lib.mkIf moltisEnabled moltisAgentFiles)
      ];

      activation =
        ownedDeployment.activation
        // lib.optionalAttrs moltisEnabled {
          moltisAssistantBootstrap =
            lib.hm.dag.entryBetween
              [ "assistantOwnedFiles" ]
              [
                "writeBoundary"
                "linkGeneration"
                "captureAssistantOwnership"
              ]
              ''
                run ${pkgs.python3}/bin/python ${moltisBootstrapScript}
              '';
        };
    };

    programs = {
      claude-code = lib.mkIf config.programs.claude-code.enable {
        # Custom agents (auto-generated from agents/ directory)
        agents = claudeAgents;

        # Reusable commands (auto-generated from commands/ directories)
        commands = claudeCommands;
      };

      opencode = lib.mkIf config.programs.opencode.enable {
        # Custom agents (auto-generated from agents/ directory)
        agents = opencodeAgents;

        # Reusable commands (auto-generated from commands/ directories)
        commands = opencodeCommands;

        # Global rules
        context = opencodeInstructions;
      };
    };
  };
}
