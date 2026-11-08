# Run by checks.x86_64-linux.moltis-tools.
{
  lib,
  pkgs,
  homeConfigurations,
}:
let
  hosts = [
    "skrye"
    "zannah"
    "traya"
  ];
  # Expose the nested script without building or running either launcher.
  launcherScripts =
    host:
    let
      home = homeConfigurations."martin@${host}";
      module = import ../../home-manager/_mixins/agentic/moltis {
        inherit (home) config;
        pkgs = home.pkgs // {
          writeScript =
            name: text:
            let
              drv = home.pkgs.writeScript name text;
            in
            if name == "moltis-tts-shim" then
              "MOLTIS_TEST_TTS_SHIM_START${text}MOLTIS_TEST_TTS_SHIM_END${drv}"
            else if name == "moltis-matrix-council-hook" then
              "MOLTIS_TEST_COUNCIL_HOOK_START${text}MOLTIS_TEST_COUNCIL_HOOK_END${drv}"
            else
              drv;
        };
        inherit (home._module.specialArgs) inputs;
        inherit (home._module.args) noughtyLib;
        lib = lib // {
          hm = home.config.lib;
          getExe =
            package:
            if (package.name or "") == "moltis-in-fence" then
              "MOLTIS_TEST_INNER_START${package.text}MOLTIS_TEST_INNER_END"
            else if (package.name or "") == "moltis-matrix-companion" then
              "MOLTIS_TEST_COMPANION_START${package.text}MOLTIS_TEST_COMPANION_END${lib.getExe package}"
            else if (package.name or "") == "moltis-github-companion" then
              "MOLTIS_TEST_GITHUB_COMPANION_START${package.text}MOLTIS_TEST_GITHUB_COMPANION_END${lib.getExe package}"
            else
              lib.getExe package;
        };
      };
      outer = lib.findFirst (
        package: package.name == "moltis-fenced"
      ) (throw "Missing Moltis launcher") module.config.content.home.packages;
      parts = lib.splitString "MOLTIS_TEST_INNER_START" outer.text;
      rawInner = builtins.head (lib.splitString "MOLTIS_TEST_INNER_END" (builtins.elemAt parts 1));
      ttsParts = lib.splitString "MOLTIS_TEST_TTS_SHIM_START" rawInner;
      ttsTail = lib.splitString "MOLTIS_TEST_TTS_SHIM_END" (builtins.elemAt ttsParts 1);
      afterTtsInner = "${builtins.head ttsParts}${builtins.elemAt ttsTail 1}";
      companionParts = lib.splitString "MOLTIS_TEST_COMPANION_START" afterTtsInner;
      companionTail = lib.splitString "MOLTIS_TEST_COMPANION_END" (builtins.elemAt companionParts 1);
      afterMatrixInner = "${builtins.head companionParts}${builtins.elemAt companionTail 1}";
      githubParts = lib.splitString "MOLTIS_TEST_GITHUB_COMPANION_START" afterMatrixInner;
      githubTail = lib.splitString "MOLTIS_TEST_GITHUB_COMPANION_END" (builtins.elemAt githubParts 1);
      councilHookEntry =
        lib.findFirst (entry: (entry.name or "") == "matrix-council-context")
          (throw "Missing matrix-council-context hook")
          module.config.content.agentic.moltis.settings.hooks.hooks;
      hookParts = lib.splitString "MOLTIS_TEST_COUNCIL_HOOK_START" councilHookEntry.command;
      hookTail = lib.splitString "MOLTIS_TEST_COUNCIL_HOOK_END" (builtins.elemAt hookParts 1);
    in
    assert builtins.length ttsParts == 2;
    assert builtins.length companionParts == 2;
    assert builtins.length githubParts == 2;
    assert builtins.length hookParts == 2;
    {
      outer = builtins.head parts;
      inner = "${builtins.head githubParts}${builtins.elemAt githubTail 1}";
      ttsShim = builtins.head ttsTail;
      councilHook = builtins.head hookTail;
      companion = builtins.head companionTail;
      githubCompanion = builtins.head githubTail;
    };
  launcherFixtures = map (
    host:
    let
      c = homeConfigurations."martin@${host}".config;
    in
    {
      inherit host;
      inherit (launcherScripts host) inner outer;
      paths = lib.mapAttrs (_: secret: secret.path) c.sops.secrets // {
        template = c.sops.templates."moltis.toml".path;
      };
    }
  ) hosts;
  mcporter =
    lib.findFirst (package: (package.pname or "") == "mcporter")
      (throw "Moltis requires the pinned MCPorter package")
      homeConfigurations."martin@skrye".config.home.packages;
  linearWrapper = pkgs.callPackage ../../home-manager/_mixins/agentic/moltis/linear-token {
    inherit mcporter;
    clientIdPath = "/synthetic/client-id";
    clientSecretPath = "/synthetic/client-secret";
    cacheDirectory = "/synthetic/cache";
    configPath = "/synthetic/mcporter.json";
    linearUrl = "https://example.invalid/mcp";
  };
  cloudflareWrapper = pkgs.callPackage ../../home-manager/_mixins/agentic/mcp/cloudflare-api {
    apiTokenPath = "/synthetic/cloudflare-token";
  };
  companionWrapper = pkgs.callPackage ../../home-manager/_mixins/agentic/moltis/matrix-companion {
    agentName = "skrye";
    mainModel = "gemini::gemini-4-argon";
    passwordPath = "/synthetic/matrix-password";
    dataDir = "/synthetic/moltis";
    stateDir = "/synthetic/state";
  };
  githubCompanionWrapper =
    pkgs.callPackage ../../home-manager/_mixins/agentic/moltis/github-companion
      {
        agentName = "skrye";
        mainModel = "gemini::gemini-4-argon";
        passwordPath = "/synthetic/matrix-password";
        telegramBotTokenPath = "/synthetic/telegram-bot-token";
        telegramAllowedUsersPath = "/synthetic/telegram-allowed-users";
        dataDir = "/synthetic/moltis";
        stateDir = "/synthetic/github-state";
      };
  checkRestartInputs =
    host:
    let
      home = homeConfigurations."martin@${host}";
      c = home.config;
      restartState =
        config:
        if c.noughty.host.is.darwin then
          config.home.activation.restartMoltis.data
        else
          config.systemd.user.services.moltis.Unit.X-Restart-Triggers;
      withChanges = changes: restartState (home.extendModules { modules = [ changes ]; }).config;
      original = restartState c;
      # The heartbeat hash is read-only, so vary it at the module boundary.
      withHeartbeat =
        heartbeatHash:
        let
          module = import ../../home-manager/_mixins/agentic/moltis {
            config = lib.recursiveUpdate c {
              agentic.assistants.moltis = { inherit heartbeatHash; };
            };
            inherit (home) pkgs;
            inherit (home._module.specialArgs) inputs;
            inherit (home._module.args) noughtyLib;
            lib = lib // {
              hm = c.lib;
            };
          };
        in
        if c.noughty.host.is.darwin then
          module.config.content.home.activation.restartMoltis.content.data
        else
          module.config.content.systemd.user.services.moltis.content.Unit.X-Restart-Triggers;
    in
    assert withChanges { } == original;
    assert
      withChanges {
        sops.secrets.GH_TOKEN.key = lib.mkForce "moltis-restart-test";
      } != original;
    assert
      withChanges {
        sops.secrets.GH_TOKEN.sopsFile = lib.mkForce (
          builtins.toFile "moltis-restart-test.yaml" "synthetic encrypted source change\n"
        );
      } != original;
    assert
      withChanges {
        sops.secrets.MOLTIS_LINEAR_CLIENT_SECRET.key = lib.mkForce "moltis/restart-test/client_secret";
      } != original;
    assert withHeartbeat c.agentic.assistants.moltis.heartbeatHash == original;
    assert withHeartbeat "moltis-restart-test" != original;
    assert
      withChanges {
        sops.templates."moltis.toml".file = lib.mkForce (
          builtins.toFile "moltis-restart-test.toml" "test = true\n"
        );
      } != original;
    assert
      withChanges {
        xdg.configFile."moltis/mcporter.json".text = lib.mkForce "{}";
      } != original;
    assert
      withChanges {
        noughty.host.gpu.compute.acceleration = lib.mkForce (
          if (c.noughty.host.gpu.compute.acceleration or null) == "vulkan" then "cuda" else "vulkan"
        );
      } != original;
    true;
  checkHost =
    host:
    let
      home = homeConfigurations."martin@${host}";
      c = home.config;
      disabled =
        (home.extendModules {
          modules = [ { noughty.host.tags = lib.mkForce (lib.remove "moltis" c.noughty.host.tags); } ];
        }).config;
      scripts = launcherScripts host;
      context = c.agentic.moltis.toolsContext;
      files = c.agentic.assistants.ownedSpec.files;
      tools = builtins.filter (
        entry:
        lib.hasSuffix "/TOOLS.md" entry.path && lib.hasPrefix "${c.home.homeDirectory}/.moltis/" entry.path
      ) files;
      guidelines = builtins.filter (
        entry:
        lib.hasSuffix "/GUIDELINES.md" entry.path
        && lib.hasPrefix "${c.home.homeDirectory}/.moltis/" entry.path
      ) files;
      agents = builtins.filter (
        entry:
        lib.hasSuffix "/AGENTS.md" entry.path && lib.hasPrefix "${c.home.homeDirectory}/.moltis/" entry.path
      ) files;
      heartbeats = builtins.filter (
        entry:
        lib.hasSuffix "/HEARTBEAT.md" entry.path
        && lib.hasPrefix "${c.home.homeDirectory}/.moltis/" entry.path
      ) files;
      guidelinesSource = (builtins.head guidelines).source;
      agentsBody = builtins.readFile (builtins.head agents).source;
      heartbeatBody = builtins.readFile (builtins.head heartbeats).source;
      generalFindingWithdrawClause = "post a substantive `General` or unanchored finding (`gh pr review <pr-url> --comment --body-file <file>`, excluding approval text and comments that report no defect)";
      root = builtins.head tools;
      body = builtins.readFile root.source;
      darwin = context.platform == "darwin";
      gemini = context.provider == "gemini";
      agentName = host;
      expectedMainModel =
        if host == "traya" then "openai-codex::gpt-6-astra" else "gemini::gemini-4-argon";
      settings = c.agentic.moltis.settings;
      cli = builtins.fromJSON (
        builtins.unsafeDiscardStringContext c.xdg.configFile."moltis/mcporter.json".text
      );
      defs = import ../../home-manager/_mixins/agentic/mcp/servers.nix {
        config = c;
        pkgs = homeConfigurations."martin@${host}".pkgs;
      };
      expectedServers = [
        "cloudflare-api"
        "cloudflare-docs"
        "context7"
        "exa"
        "linear"
      ];
      envNames = map (entry: entry.name) c.agentic.moltis.envPlumbing;
      builtinPresets = import ../../home-manager/_mixins/agentic/moltis/builtin-presets.nix;
    in
    assert builtins.length tools == 2;
    assert
      map (entry: entry.path) tools == [
        "${c.home.homeDirectory}/.moltis/TOOLS.md"
        "${c.home.homeDirectory}/.moltis/agents/main/TOOLS.md"
      ];
    assert builtins.all (
      entry: entry.kind == "file" && entry.mode == "0600" && entry.source == root.source
    ) tools;
    assert
      map (entry: entry.path) guidelines == [
        "${c.home.homeDirectory}/.moltis/docs/moltis/GUIDELINES.md"
        "${c.home.homeDirectory}/.moltis/agents/main/GUIDELINES.md"
      ];
    assert builtins.match "[[:space:]]*" (builtins.readFile guidelinesSource) == null;
    assert builtins.all (
      entry:
      entry.kind == "file"
      && entry.mode == "0600"
      && entry.source == guidelinesSource
      && (entry.bootstrapSources or [ ]) == [ ]
    ) guidelines;
    assert builtins.length agents == 2;
    assert builtins.length heartbeats == 2;
    assert lib.hasInfix generalFindingWithdrawClause agentsBody;
    assert lib.hasInfix "gh-review-withdraw-approval <pr-url>" agentsBody;
    assert lib.hasInfix generalFindingWithdrawClause heartbeatBody;
    assert lib.hasInfix "gh-review-withdraw-approval <pr-url>" heartbeatBody;
    assert builtins.all (
      entry: !(lib.hasPrefix "${c.home.homeDirectory}/.moltis/" entry.path)
    ) disabled.agentic.assistants.ownedSpec.files;
    assert !(lib.elem "${c.home.homeDirectory}/.moltis" disabled.agentic.assistants.ownedSpec.roots);
    assert !(disabled.home.activation ? moltisAssistantBootstrap);
    assert !(disabled.xdg.configFile ? "moltis/mcporter.json");
    assert !(disabled.launchd.agents ? llama-swap);
    assert !(lib.any (package: (package.name or "") == "moltis-fenced") disabled.home.packages);
    assert (c.launchd.agents ? llama-swap) == darwin;
    assert !darwin || c.launchd.agents.llama-swap.config.Label == "org.moltis.llama-swap";
    assert
      settings.models == {
        gemini-4-argon.context_window = 1000000;
        gpt-6-astra.context_window = 384000;
        gpt-6-luna.context_window = 384000;
      };
    assert
      settings.memory == {
        provider = "custom";
        base_url = "http://127.0.0.1:8080/v1";
        model = "qwen3-embedding-0.6b";
      };
    assert lib.hasInfix "WHERE model != 'qwen3-embedding-0.6b'" scripts.inner;
    assert builtins.all
      (
        name:
        lib.hasInfix ''
          ${name}="$(< ${lib.escapeShellArg c.sops.secrets.${name}.path})"
          export ${name}
        '' scripts.inner
      )
      [
        "CONTEXT7_API_KEY"
      ];
    assert builtins.all
      (
        name:
        lib.hasInfix "&& -r ${lib.escapeShellArg c.sops.secrets.${name}.path}" scripts.outer
        && lib.hasInfix "|| ! -r ${lib.escapeShellArg c.sops.secrets.${name}.path}" scripts.outer
      )
      (
        lib.remove "LINEAR_API_KEY" (defs.requiredSecretsForConsumers [ "moltis" ])
        ++ [
          "MOLTIS_LINEAR_CLIENT_ID"
          "MOLTIS_LINEAR_CLIENT_SECRET"
          "CLOUDFLARE_API_TOKEN"
          "MATRIX_PASSWORD"
        ]
      );
    assert builtins.all
      (pkgName: lib.any (package: (package.name or package.pname or "") == pkgName) c.home.packages)
      [
        "gh-review-resolve"
        "gh-review-unresolve"
        "gh-review-withdraw-approval"
      ];
    assert context.mainModel == expectedMainModel;
    assert c.agentic.moltis.matrix.enable;
    assert c.agentic.moltis.githubCompanion.enable;
    assert settings.heartbeat.enabled == false;
    assert settings.heartbeat.every == "360m";
    assert lib.hasInfix "/bin/moltis-matrix-companion &" scripts.inner;
    assert lib.hasInfix "def martin_requested_voice" scripts.ttsShim;
    assert lib.hasInfix "fmt == \"ogg\"" scripts.ttsShim;
    assert lib.hasInfix "ogg TTS rejected for short assessment badge" scripts.ttsShim;
    assert lib.hasInfix "ogg TTS rejected: Martin did not request audio/voice in Matrix"
      scripts.ttsShim;
    assert lib.hasInfix "${c.xdg.stateHome}/moltis/matrix-companion-${agentName}/state.json"
      scripts.ttsShim;
    assert lib.hasInfix "import companion" scripts.councilHook;
    assert lib.hasInfix "STATE_FILENAME = companion.STATE_FILENAME" scripts.councilHook;
    assert lib.hasInfix "companion.run_council_hook_cli(" scripts.councilHook;
    assert lib.hasInfix
      "DEFAULT_STATE_DIR = ${builtins.toJSON "${c.xdg.stateHome}/moltis/matrix-companion-${agentName}"}"
      scripts.councilHook;
    assert lib.hasInfix "/bin/moltis-matrix-companion &\nchildren+=(\"$!\")" scripts.inner == darwin;
    assert lib.hasInfix "/bin/moltis-github-companion &" scripts.inner;
    assert lib.hasInfix "/bin/moltis-github-companion &\nchildren+=(\"$!\")" scripts.inner == darwin;
    assert lib.hasInfix "/bin/moltis-github-companion &\n\nexec " scripts.inner == !darwin;
    assert lib.hasInfix "export MOLTIS_COMPANION_AGENT_NAME=${lib.escapeShellArg agentName}"
      scripts.companion;
    assert lib.hasInfix "export MOLTIS_COMPANION_MAIN_MODEL=${lib.escapeShellArg expectedMainModel}"
      scripts.companion;
    assert lib.hasInfix
      "export MOLTIS_COMPANION_SELF_USER_ID=${lib.escapeShellArg "@${agentName}:matrix.wimpys.world"}"
      scripts.companion;
    assert lib.hasInfix
      "export MOLTIS_COMPANION_ROOM_ID=${lib.escapeShellArg c.agentic.moltis.matrix.roomId}"
      scripts.companion;
    assert lib.hasInfix
      "export MOLTIS_COMPANION_PASSWORD_PATH=${lib.escapeShellArg c.sops.secrets.MATRIX_PASSWORD.path}"
      scripts.companion;
    assert lib.hasInfix
      "export MOLTIS_COMPANION_DATA_DIR=${lib.escapeShellArg "${c.home.homeDirectory}/.moltis"}"
      scripts.companion;
    assert lib.hasInfix
      "export MOLTIS_COMPANION_STATE_DIR=${lib.escapeShellArg "${c.xdg.stateHome}/moltis/matrix-companion-${agentName}"}"
      scripts.companion;
    assert lib.hasInfix
      "export MOLTIS_COMPANION_RPC_URL=${lib.escapeShellArg "https://127.0.0.1:13131/api/rpc"}"
      scripts.companion;
    assert lib.hasInfix "companion.py" scripts.companion;
    assert lib.hasInfix "export MOLTIS_GITHUB_COMPANION_AGENT_NAME=${lib.escapeShellArg agentName}"
      scripts.githubCompanion;
    assert lib.hasInfix
      "export MOLTIS_GITHUB_COMPANION_MAIN_MODEL=${lib.escapeShellArg expectedMainModel}"
      scripts.githubCompanion;
    assert lib.hasInfix "export MOLTIS_GITHUB_COMPANION_SCHEDULE_DOW=${
      lib.escapeShellArg (
        if host == "skrye" then
          "1"
        else if host == "zannah" then
          "3"
        else
          "5"
      )
    }" scripts.githubCompanion;
    assert lib.hasInfix "export MOLTIS_GITHUB_COMPANION_SCHEDULE_DAY_NAME=${
      lib.escapeShellArg (
        if host == "skrye" then
          "Monday"
        else if host == "zannah" then
          "Wednesday"
        else
          "Friday"
      )
    }" scripts.githubCompanion;
    assert lib.hasInfix
      "export MOLTIS_GITHUB_COMPANION_MATRIX_SELF_USER_ID=${lib.escapeShellArg "@${agentName}:matrix.wimpys.world"}"
      scripts.githubCompanion;
    assert lib.hasInfix
      "export MOLTIS_GITHUB_COMPANION_MATRIX_ROOM_ID=${lib.escapeShellArg c.agentic.moltis.matrix.roomId}"
      scripts.githubCompanion;
    assert lib.hasInfix
      "export MOLTIS_GITHUB_COMPANION_MATRIX_PASSWORD_PATH=${lib.escapeShellArg c.sops.secrets.MATRIX_PASSWORD.path}"
      scripts.githubCompanion;
    assert lib.hasInfix
      "export MOLTIS_GITHUB_COMPANION_TELEGRAM_BOT_TOKEN_PATH=${lib.escapeShellArg c.sops.secrets.TELEGRAM_BOT_TOKEN.path}"
      scripts.githubCompanion;
    assert lib.hasInfix
      "export MOLTIS_GITHUB_COMPANION_TELEGRAM_ALLOWED_USERS_PATH=${lib.escapeShellArg c.sops.secrets.TELEGRAM_ALLOWED_USERS.path}"
      scripts.githubCompanion;
    assert lib.hasInfix
      "export MOLTIS_GITHUB_COMPANION_TELEGRAM_API_URL=${lib.escapeShellArg "https://api.telegram.org"}"
      scripts.githubCompanion;
    assert lib.hasInfix
      "export MOLTIS_GITHUB_COMPANION_DATA_DIR=${lib.escapeShellArg "${c.home.homeDirectory}/.moltis"}"
      scripts.githubCompanion;
    assert lib.hasInfix
      "export MOLTIS_GITHUB_COMPANION_STATE_DIR=${lib.escapeShellArg "${c.xdg.stateHome}/moltis/github-companion-${agentName}"}"
      scripts.githubCompanion;
    assert lib.hasInfix
      "export MOLTIS_GITHUB_COMPANION_RPC_URL=${lib.escapeShellArg "https://127.0.0.1:13131/api/rpc"}"
      scripts.githubCompanion;
    assert lib.hasInfix "companion.py" scripts.githubCompanion;
    assert !(lib.hasInfix "CLOUDFLARE_API_TOKEN" scripts.inner);
    assert !(lib.hasInfix "export CLOUDFLARE_API_TOKEN" scripts.outer);
    assert !(lib.hasInfix "export LINEAR_API_KEY" scripts.inner);
    assert lib.hasInfix "unset LINEAR_API_KEY" scripts.inner;
    assert c.sops.secrets.MOLTIS_LINEAR_CLIENT_ID.key == "moltis/${host}/client_id";
    assert c.sops.secrets.MOLTIS_LINEAR_CLIENT_SECRET.key == "moltis/${host}/client_secret";
    assert c.sops.secrets.MOLTIS_LINEAR_CLIENT_SECRET.mode == "0400";
    assert !(disabled.sops.secrets ? MOLTIS_LINEAR_CLIENT_ID);
    assert !(disabled.sops.secrets ? MOLTIS_LINEAR_CLIENT_SECRET);
    assert c.sops.secrets.LINEAR_API_KEY.key == disabled.sops.secrets.LINEAR_API_KEY.key;
    assert lib.hasInfix "-systemd-" scripts.inner == !darwin;
    assert
      lib.hasInfix "-moltis-matrix-companion/bin" (
        builtins.head (lib.splitString "export MCPORTER_CONFIG=" scripts.inner)
      ) == c.agentic.moltis.matrix.enable;
    assert lib.hasInfix c.home.homeDirectory body;
    assert lib.hasInfix context.platform body;
    assert context.system == homeConfigurations."martin@${host}".pkgs.stdenv.hostPlatform.system;
    assert lib.hasInfix "`${context.system}`" body;
    assert !(lib.hasInfix "@ENVIRONMENT@" body);
    assert !(lib.hasInfix "<SOPS:" body);
    assert lib.hasInfix "one tool call per response" body == gemini;
    assert lib.hasInfix "Linear is configured on this host." body;
    assert context.mcpServers == expectedServers;
    assert cli.imports == [ ];
    assert builtins.attrNames cli.mcpServers == context.mcpServers;
    assert
      removeAttrs cli.mcpServers [ "linear" ] == removeAttrs defs.moltisMcporterServers [ "linear" ];
    assert cli.mcpServers.linear.lifecycle == "ephemeral";
    assert lib.hasSuffix "/bin/moltis-linear-server" cli.mcpServers.linear.command;
    assert !(cli.mcpServers.linear ? headers);
    assert !(cli.mcpServers.linear ? url);
    assert cli.mcpServers.context7.headers.Authorization == "Bearer \${CONTEXT7_API_KEY}";
    assert !(lib.hasInfix "<SOPS:" c.xdg.configFile."moltis/mcporter.json".text);
    assert !(lib.elem "LINEAR_API_KEY" envNames);
    assert !(settings.env ? LINEAR_API_KEY);
    assert !(settings.env ? MOLTIS_LINEAR_CLIENT_SECRET);
    assert settings.mcp.servers == { };
    assert settings.tools.policy.deny == [ "mcp_*" ];
    assert builtins.all (name: lib.hasPrefix "mcp_" name) (
      context.nativeMcpManagementTools ++ [ "mcp__linear__list_issues" ]
    );
    assert builtins.all (preset: preset.tools.deny == context.nativeMcpManagementTools) (
      builtins.attrValues settings.agents.presets
    );
    assert
      builtins.attrNames builtinPresets == [
        "coder"
        "coordinator"
        "docs"
        "qa"
        "research"
        "reviewer"
        "ux"
      ];
    assert builtins.all (
      name:
      let
        preset = settings.agents.presets.${name};
        original = builtinPresets.${name};
      in
      preset.identity == original.identity
      && preset.max_iterations == original.max_iterations
      && lib.hasPrefix original.system_prompt_suffix preset.system_prompt_suffix
      && preset.delegate_only == original.delegate_only
    ) (lib.remove "coordinator" (builtins.attrNames builtinPresets));
    assert settings.agents.presets.coordinator.delegate_only == false;
    assert settings.agents.presets.coordinator.model == context.mainModel;
    assert builtins.all
      (
        name:
        let
          preset = settings.agents.presets.${name};
        in
        !(preset ? identity)
        && !(preset ? max_iterations)
        && !(preset ? timeout_secs)
        && preset.system_prompt_suffix == context.mcpInstructions
      )
      [
        "coordinator"
        "auxiliary"
        "compression"
        "review"
      ];
    assert settings.agents.presets.coordinator.reasoning_effort == "medium";
    assert settings.agents.presets.review.model == context.mainModel;
    assert settings.agents.presets.review.reasoning_effort == "medium";
    assert settings.heartbeat.model == context.mainModel;
    assert settings.auxiliary.compaction == context.auxiliaryModel;
    assert settings.auxiliary.title_generation == context.auxiliaryModel;
    assert settings.auxiliary.vision == context.auxiliaryModel;
    assert builtins.all
      (
        name:
        let
          preset = settings.agents.presets.${name};
        in
        preset.model == context.auxiliaryModel
        && preset.reasoning_effort == (if host == "traya" then "high" else "medium")
      )
      [
        "auxiliary"
        "compression"
      ];
    assert builtins.all (preset: lib.hasInfix context.mcpInstructions preset.system_prompt_suffix) (
      builtins.attrValues settings.agents.presets
    );
    assert settings.env.MCPORTER_CONFIG == context.mcporterConfig;
    assert context.mcporterConfig == "${c.xdg.configHome}/moltis/mcporter.json";
    assert lib.hasInfix context.mcporterConfig body;
    assert builtins.all (name: lib.hasInfix "`${name}`" body) context.nativeMcpManagementTools;
    assert builtins.attrNames defs.claudeServers == expectedServers;
    assert builtins.attrNames defs.codexServers == expectedServers;
    assert builtins.attrNames defs.piServers == expectedServers;
    assert builtins.all (name: lib.hasInfix "`${name}`" body) context.mcpServers;
    assert lib.hasInfix "launchctl print" body == darwin;
    assert lib.hasInfix "xcrun --find" body == darwin;
    assert lib.hasInfix "target volume's case sensitivity" body == darwin;
    assert lib.hasInfix "Bash executable's version" body == darwin;
    assert !(lib.hasInfix "systemctl --user" body);
    assert lib.hasInfix "journalctl --user" body == !darwin;
    assert lib.hasInfix "Linux Fence mounts" body == !darwin;
    assert
      !c.noughty.host.is.linux
      || (
        builtins.length c.systemd.user.services.moltis.Unit.X-Restart-Triggers == 1
        &&
          builtins.match "[0-9a-f]{64}" (builtins.head c.systemd.user.services.moltis.Unit.X-Restart-Triggers)
          != null
      );
    assert !c.noughty.host.is.linux || lib.elem "reloadSystemd" c.home.activation.refreshSopsNix.before;
    assert
      !c.noughty.host.is.linux || lib.elem "reloadSystemd" c.home.activation.assistantOwnedFiles.before;
    assert
      !darwin
      || builtins.all (step: lib.elem step c.home.activation.restartMoltis.after) [
        "refreshSopsNix"
        "assistantOwnedFiles"
        "setupLaunchAgents"
      ];
    assert
      lib.hasInfix "`.git/config` and `.git/hooks` read-only, including in maintenance checkouts" body
      == !darwin;
    true;
in
assert builtins.all checkRestartInputs hosts;
assert builtins.all checkHost hosts;
pkgs.runCommand "moltis-tools" { } ''
  test -x ${linearWrapper}/bin/mcporter
  test -x ${lib.getExe linearWrapper.linearServer}
  test -x ${lib.getExe cloudflareWrapper}
  test -x ${lib.getExe companionWrapper}
  test -x ${lib.getExe githubCompanionWrapper}
  ${pkgs.python3}/bin/python3 - ${builtins.toFile "moltis-launcher-fixtures.json" (builtins.unsafeDiscardStringContext (builtins.toJSON launcherFixtures))} ${pkgs.bash}/bin/bash ${pkgs.sqlite}/bin <<'PY'
  import json
  import os
  from pathlib import Path
  import re
  import sqlite3
  import subprocess
  import sys
  import tempfile

  fixtures = json.loads(Path(sys.argv[1]).read_text())
  bash = sys.argv[2]
  sqlite_bin = sys.argv[3]
  for fixture in fixtures:
      with tempfile.TemporaryDirectory() as directory:
          root = Path(directory)
          paths = {name: root / name for name in fixture["paths"]}
          for name, path in paths.items():
              path.write_text("synthetic-" + name)
          inner, outer = fixture["inner"], fixture["outer"]
          for name, original in fixture["paths"].items():
              inner = inner.replace(original, str(paths[name]))
              outer = outer.replace(original, str(paths[name]))
          prologue = inner.split("export MCPORTER_CONFIG=", 1)[1].split("export MOLTIS_DATA_DIR=", 1)[0]
          prologue = "set -euo pipefail\nexport MCPORTER_CONFIG=" + prologue
          child = """
  import os
  from pathlib import Path
  Path(os.environ["HOME"], "child-started").touch()
  assert "LINEAR_API_KEY" not in os.environ
  assert os.environ["CONTEXT7_API_KEY"] == "synthetic-CONTEXT7_API_KEY"
  assert "CLOUDFLARE_API_TOKEN" not in os.environ
  """
          command = prologue + f"{sys.executable} - <<'CHILD'\n{child}\nCHILD\n"
          env = {"HOME": directory, "PATH": os.defpath, "LINEAR_API_KEY": "synthetic-personal"}
          result = subprocess.run([bash, "-c", command], env=env, capture_output=True, timeout=5)
          assert result.returncode == 0, (fixture["host"], result.stderr)
          marker = root / "child-started"
          marker.unlink()
          ready = re.search(r"(\[\[ -r .*?\]\]) && break", outer).group(1)
          failed = re.search(r"if (\[\[ ! -r .*?\]\]); then", outer).group(1)
          for missing in (None, "MOLTIS_LINEAR_CLIENT_ID", "MOLTIS_LINEAR_CLIENT_SECRET", "CONTEXT7_API_KEY", "CLOUDFLARE_API_TOKEN", "MATRIX_PASSWORD"):
              if missing:
                  paths[missing].unlink()
              for condition, expected in ((ready, missing is None), (failed, missing is not None)):
                  result = subprocess.run([bash, "-c", condition], env=env, capture_output=True, timeout=5)
                  assert (result.returncode == 0) == expected, (fixture["host"], missing, condition)
              if missing == "CONTEXT7_API_KEY":
                  result = subprocess.run([bash, "-c", command], env=env, capture_output=True, timeout=5)
                  assert result.returncode != 0, (fixture["host"], missing)
                  assert not marker.exists(), (fixture["host"], missing, "child started without credentials")
              if missing:
                  paths[missing].write_text("synthetic-" + missing)
          readiness_tail = inner.split('mkdir -p "$HOME/.moltis"\n', 1)[1].split('if [[ -f "$MOLTIS_DATA_DIR/memory.db" ]]; then', 1)[0]
          timeout_cmd = "set -euo pipefail\n" + readiness_tail + f"{sys.executable} -c 'from pathlib import Path; import os; Path(os.environ[\"HOME\"], \"reached-cleanup\").touch()'\n"
          timeout_env = dict(env, MOLTIS_EMBEDDING_READY_TIMEOUT_SECS="0")
          result = subprocess.run([bash, "-c", timeout_cmd], env=timeout_env, capture_output=True, text=True, timeout=5)
          assert result.returncode != 0, (fixture["host"], "expected readiness timeout to fail")
          assert "moltis-in-fence: timed out waiting for the embedding model" in result.stderr, (fixture["host"], result.stderr)
          assert not (root / "reached-cleanup").exists(), (fixture["host"], "launcher continued after readiness timeout")
          data_dir = root / ".moltis"
          data_dir.mkdir(exist_ok=True)
          db_path = data_dir / "memory.db"
          with sqlite3.connect(db_path) as conn:
              conn.executescript("""
                  CREATE TABLE files (
                      path TEXT NOT NULL PRIMARY KEY,
                      source TEXT NOT NULL,
                      hash TEXT NOT NULL,
                      mtime INTEGER NOT NULL,
                      size INTEGER NOT NULL
                  );
                  CREATE TABLE chunks (
                      id TEXT NOT NULL PRIMARY KEY,
                      path TEXT NOT NULL,
                      source TEXT NOT NULL,
                      start_line INTEGER NOT NULL,
                      end_line INTEGER NOT NULL,
                      hash TEXT NOT NULL,
                      model TEXT NOT NULL,
                      text TEXT NOT NULL,
                      embedding BLOB,
                      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
                  );
                  CREATE TABLE embedding_cache (
                      provider TEXT NOT NULL,
                      model TEXT NOT NULL,
                      provider_key TEXT NOT NULL,
                      hash TEXT NOT NULL,
                      embedding BLOB NOT NULL,
                      dims INTEGER NOT NULL,
                      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
                      PRIMARY KEY (provider, model, provider_key, hash)
                  );
                  CREATE VIRTUAL TABLE chunks_fts USING fts5(
                      text,
                      content=chunks,
                      content_rowid=rowid
                  );
                  CREATE TRIGGER chunks_ai AFTER INSERT ON chunks BEGIN
                      INSERT INTO chunks_fts(rowid, text) VALUES (new.rowid, new.text);
                  END;
                  INSERT INTO files VALUES
                      ('stale.md', 'memory', 'h1', 1, 10),
                      ('null.md', 'memory', 'h2', 1, 10),
                      ('orphan.md', 'memory', 'h3', 1, 10),
                      ('empty.md', 'memory', 'h4', 1, 0),
                      ('valid.md', 'memory', 'h5', 1, 10);
                  INSERT INTO chunks (id, path, source, start_line, end_line, hash, model, text, embedding) VALUES
                      ('c-stale', 'stale.md', 'memory', 1, 1, 'h1', 'stale-model', 'stale text', X'01'),
                      ('c-null', 'null.md', 'memory', 1, 1, 'h2', 'qwen3-embedding-0.6b', 'null text', NULL),
                      ('c-valid', 'valid.md', 'memory', 1, 1, 'h5', 'qwen3-embedding-0.6b', 'valid text', X'02');
                  INSERT INTO chunks_fts(rowid, text) VALUES (999, 'orphanfts');
                  INSERT INTO embedding_cache (provider, model, provider_key, hash, embedding, dims) VALUES
                      ('custom', 'stale-model', 'k', 'h1', X'01', 1),
                      ('custom', 'qwen3-embedding-0.6b', 'k', 'h5', X'02', 1);
              """)
          cleanup_block = 'if [[ -f "$MOLTIS_DATA_DIR/memory.db" ]]; then' + inner.split('if [[ -f "$MOLTIS_DATA_DIR/memory.db" ]]; then', 1)[1].split("printf '[\"dcg-guard\"]\\n'", 1)[0]
          cleanup_env = dict(env, MOLTIS_DATA_DIR=str(data_dir), PATH=f"{sqlite_bin}:{os.defpath}")
          result = subprocess.run([bash, "-c", "set -euo pipefail\n" + cleanup_block], env=cleanup_env, capture_output=True, text=True, timeout=5)
          assert result.returncode == 0, (fixture["host"], result.stderr)
          with sqlite3.connect(db_path) as conn:
              assert [r[0] for r in conn.execute("SELECT path FROM files ORDER BY path")] == ["empty.md", "valid.md"], fixture["host"]
              assert [r[0] for r in conn.execute("SELECT id FROM chunks ORDER BY id")] == ["c-valid"], fixture["host"]
              assert [r[0] for r in conn.execute("SELECT text FROM chunks_fts WHERE chunks_fts MATCH 'orphanfts'")] == [], fixture["host"]
              assert [r[0] for r in conn.execute("SELECT text FROM chunks_fts WHERE chunks_fts MATCH 'valid'")] == ["valid text"], fixture["host"]
              assert [r[0] for r in conn.execute("SELECT model FROM embedding_cache")] == ["qwen3-embedding-0.6b"], fixture["host"]
  print("Moltis launcher checks passed for all three hosts.")
  PY
  ${pkgs.python3}/bin/python3 ${../../home-manager/_mixins/agentic/assistants/owned-files}/test_deploy.py
  PYTHONDONTWRITEBYTECODE=1 ${pkgs.python3}/bin/python3 ${../../home-manager/_mixins/agentic/moltis/mcp-cli-migration}/test_migrate.py
  PYTHONDONTWRITEBYTECODE=1 ${pkgs.python3}/bin/python3 ${../../home-manager/_mixins/agentic/moltis/mcp-cli-migration}/test_mcporter.py ${lib.getExe mcporter}
  PYTHONDONTWRITEBYTECODE=1 ${pkgs.python3}/bin/python3 ${../../home-manager/_mixins/agentic/moltis/linear-token}/test_linear_token.py
  PYTHONDONTWRITEBYTECODE=1 ${pkgs.python3}/bin/python3 ${../../home-manager/_mixins/agentic/moltis}/matrix-companion/test_companion.py
  PYTHONDONTWRITEBYTECODE=1 ${pkgs.python3}/bin/python3 ${../../home-manager/_mixins/agentic/moltis}/github-companion/test_companion.py
  PATH=${
    lib.makeBinPath [
      pkgs.coreutils
      pkgs.jq
    ]
  }:$PATH ${pkgs.bash}/bin/bash ${../../home-manager/_mixins/development/github/gh-bot-merge}/gh-bot-merge-tests.sh
  PATH=${
    lib.makeBinPath [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.jq
    ]
  }:$PATH ${pkgs.python3}/bin/python3 - ${pkgs.bash}/bin/bash ${../../home-manager/_mixins/development/github/gh-review-unresolve.sh} ${../../home-manager/_mixins/development/github/gh-review-resolve.sh} ${../../home-manager/_mixins/development/github/gh-review-withdraw-approval.sh} <<'PY'
  import json
  import os
  from pathlib import Path
  import subprocess
  import sys
  import tempfile

  bash_bin, unresolve_script, resolve_script, withdraw_script = sys.argv[1:5]
  url = "https://github.com/owner/repo/pull/42#discussion_r987654"

  def check_pagination(script: str, initial_resolved: bool, mutation_field: str, expected_msg: str) -> None:
      with tempfile.TemporaryDirectory() as directory:
          root = Path(directory)
          stub = root / "gh"
          stub.write_text(
              f"#!{bash_bin}\n"
              "set -euo pipefail\n"
              "call=$(($(wc -l <\"$GH_STUB_DIR/calls\") + 1))\n"
              "printf 'call\\n' >>\"$GH_STUB_DIR/calls\"\n"
              ": >\"$GH_STUB_DIR/argv-$call\"\n"
              "for arg in \"$@\"; do printf '%s\\n' \"$arg\" >>\"$GH_STUB_DIR/argv-$call\"; done\n"
              "cat \"$GH_STUB_DIR/response-$call\"\n"
          )
          stub.chmod(0o700)
          (root / "calls").write_text("")
          # Page 1 of reviewThreads: hasNextPage=true and a thread whose comments also have hasNextPage=true.
          (root / "response-1").write_text(json.dumps({
              "data": {
                  "repository": {
                      "pullRequest": {
                          "reviewThreads": {
                              "pageInfo": {"hasNextPage": True, "endCursor": "T1"},
                              "nodes": [{
                                  "id": "PRRT_page1",
                                  "isResolved": initial_resolved,
                                  "comments": {
                                      "pageInfo": {"hasNextPage": True, "endCursor": "C1"},
                                      "nodes": [{"databaseId": 111}],
                                  },
                              }],
                          },
                      },
                  },
              },
          }))
          # Page 2 of PRRT_page1 comments: no match, hasNextPage=false.
          (root / "response-2").write_text(json.dumps({
              "data": {
                  "node": {
                      "id": "PRRT_page1",
                      "isResolved": initial_resolved,
                      "comments": {
                          "pageInfo": {"hasNextPage": False, "endCursor": ""},
                          "nodes": [{"databaseId": 222}],
                      },
                  },
              },
          }))
          # Page 2 of reviewThreads: contains the target comment 987654.
          (root / "response-3").write_text(json.dumps({
              "data": {
                  "repository": {
                      "pullRequest": {
                          "reviewThreads": {
                              "pageInfo": {"hasNextPage": False, "endCursor": ""},
                              "nodes": [{
                                  "id": "PRRT_page2",
                                  "isResolved": initial_resolved,
                                  "comments": {
                                      "pageInfo": {"hasNextPage": False, "endCursor": ""},
                                      "nodes": [{"databaseId": 987654}],
                                  },
                              }],
                          },
                      },
                  },
              },
          }))
          # Mutation reply for PRRT_page2.
          (root / "response-4").write_text(json.dumps({
              "data": {
                  mutation_field: {
                      "thread": {"id": "PRRT_page2", "isResolved": not initial_resolved},
                  },
              },
          }))
          env = dict(
              os.environ,
              GH_STUB_DIR=str(root),
              GH_REVIEW_UNRESOLVE_GH=str(stub),
              GH_REVIEW_RESOLVE_GH=str(stub),
          )
          res = subprocess.run([bash_bin, "-eu", "-o", "pipefail", script, url], env=env, capture_output=True, text=True, timeout=5)
          assert res.returncode == 0, (script, res.returncode, res.stderr)
          assert expected_msg in res.stdout, (script, res.stdout)
          assert len((root / "calls").read_text().splitlines()) == 4, script
          argv3 = (root / "argv-3").read_text().splitlines()
          assert "cursor=T1" in argv3, (script, argv3)
          argv4 = (root / "argv-4").read_text().splitlines()
          assert "threadId=PRRT_page2" in argv4, (script, argv4)

  def check_withdraw_approval() -> None:
      # 1. Dismisses only viewer's own APPROVED review (ignoring another user's APPROVED review).
      with tempfile.TemporaryDirectory() as directory:
          root = Path(directory)
          stub = root / "gh"
          stub.write_text(
              f"#!{bash_bin}\n"
              "set -euo pipefail\n"
              "call=$(($(wc -l <\"$GH_STUB_DIR/calls\") + 1))\n"
              "printf 'call\\n' >>\"$GH_STUB_DIR/calls\"\n"
              ": >\"$GH_STUB_DIR/argv-$call\"\n"
              "for arg in \"$@\"; do printf '%s\\n' \"$arg\" >>\"$GH_STUB_DIR/argv-$call\"; done\n"
              "cat \"$GH_STUB_DIR/response-$call\"\n"
          )
          stub.chmod(0o700)
          (root / "calls").write_text("")
          (root / "response-1").write_text(json.dumps({
              "data": {
                  "viewer": {"login": "sith-zannah"},
                  "repository": {
                      "pullRequest": {
                          "reviews": {
                              "pageInfo": {"hasNextPage": False, "endCursor": ""},
                              "nodes": [
                                  {
                                      "id": "PRR_other",
                                      "databaseId": 1001,
                                      "author": {"login": "sith-skrye"},
                                      "state": "APPROVED",
                                  },
                                  {
                                      "id": "PRR_self",
                                      "databaseId": 1002,
                                      "author": {"login": "sith-zannah"},
                                      "state": "APPROVED",
                                  },
                              ],
                          },
                      },
                  },
              },
          }))
          (root / "response-2").write_text(json.dumps({
              "data": {
                  "dismissPullRequestReview": {
                      "pullRequestReview": {"id": "PRR_self", "state": "DISMISSED"},
                  },
              },
          }))
          env = dict(
              os.environ,
              GH_STUB_DIR=str(root),
              GH_REVIEW_WITHDRAW_APPROVAL_GH=str(stub),
          )
          res = subprocess.run(
              [bash_bin, "-eu", "-o", "pipefail", withdraw_script, "https://github.com/owner/repo/pull/42", "--message", "Custom withdrawal reason"],
              env=env,
              capture_output=True,
              text=True,
              timeout=5,
          )
          assert res.returncode == 0, (res.returncode, res.stderr)
          assert "dismissed APPROVED review PRR_self by sith-zannah" in res.stdout, res.stdout
          assert len((root / "calls").read_text().splitlines()) == 2
          argv2 = (root / "argv-2").read_text().splitlines()
          assert "reviewId=PRR_self" in argv2, argv2
          assert "reviewId=PRR_other" not in argv2, argv2
          assert "message=Custom withdrawal reason" in argv2, argv2

      # 2. Exits 0 without mutating when viewer has no APPROVED review (even if another user has one).
      with tempfile.TemporaryDirectory() as directory:
          root = Path(directory)
          stub = root / "gh"
          stub.write_text(
              f"#!{bash_bin}\n"
              "set -euo pipefail\n"
              "call=$(($(wc -l <\"$GH_STUB_DIR/calls\") + 1))\n"
              "printf 'call\\n' >>\"$GH_STUB_DIR/calls\"\n"
              ": >\"$GH_STUB_DIR/argv-$call\"\n"
              "for arg in \"$@\"; do printf '%s\\n' \"$arg\" >>\"$GH_STUB_DIR/argv-$call\"; done\n"
              "cat \"$GH_STUB_DIR/response-$call\"\n"
          )
          stub.chmod(0o700)
          (root / "calls").write_text("")
          (root / "response-1").write_text(json.dumps({
              "data": {
                  "viewer": {"login": "sith-zannah"},
                  "repository": {
                      "pullRequest": {
                          "reviews": {
                              "pageInfo": {"hasNextPage": False, "endCursor": ""},
                              "nodes": [
                                  {
                                      "id": "PRR_other",
                                      "databaseId": 1001,
                                      "author": {"login": "sith-skrye"},
                                      "state": "APPROVED",
                                  },
                              ],
                          },
                      },
                  },
              },
          }))
          env = dict(
              os.environ,
              GH_STUB_DIR=str(root),
              GH_REVIEW_WITHDRAW_APPROVAL_GH=str(stub),
          )
          res = subprocess.run(
              [bash_bin, "-eu", "-o", "pipefail", withdraw_script, "owner/repo#42"],
              env=env,
              capture_output=True,
              text=True,
              timeout=5,
          )
          assert res.returncode == 0, (res.returncode, res.stderr)
          assert "sith-zannah has no APPROVED reviews on owner/repo pull request 42" in res.stdout, res.stdout
          assert len((root / "calls").read_text().splitlines()) == 1

  check_pagination(unresolve_script, True, "unresolveReviewThread", "unresolved review thread PRRT_page2")
  check_pagination(resolve_script, False, "resolveReviewThread", "resolved review thread PRRT_page2")
  check_withdraw_approval()
  print("gh-review-unresolve, gh-review-resolve, and gh-review-withdraw-approval checks passed.")
  PY
  PYTHONPATH=${../../home-manager/_mixins/agentic/moltis/mcp-cli-migration} PYTHONDONTWRITEBYTECODE=1 ${pkgs.python3}/bin/python3 ${../../home-manager/_mixins/agentic/moltis/linear-token}/test_linear_token.py ${lib.getExe mcporter} ${lib.getExe pkgs.mcp-proxy}
  PYTHONPATH=${../../home-manager/_mixins/agentic/moltis/mcp-cli-migration} PYTHONDONTWRITEBYTECODE=1 ${pkgs.python3}/bin/python3 - ${lib.getExe cloudflareWrapper} ${lib.getExe mcporter} ${lib.getExe pkgs.mcp-proxy} <<'PY'
  import http.server
  import json
  import os
  from pathlib import Path
  import subprocess
  import sys
  import tempfile
  import threading
  from test_mcporter import HttpServer, check_server

  cloudflare_bin, mcporter_bin, proxy_bin = sys.argv[1:4]
  template = Path(cloudflare_bin).read_text()
  with tempfile.TemporaryDirectory() as directory:
      root = Path(directory)
      token_file = root / "cloudflare-token"
      token_file.write_text("synthetic-cloudflare")
      poison = root / "poison-site-packages" / "pydantic_core"
      poison.mkdir(parents=True)
      (poison / "__init__.py").write_text("raise RuntimeError('poisoned PYTHONPATH')\n")
      probe = root / "probe"
      probe.write_text(
          f"#!{sys.executable}\nimport json, os, sys\n"
          "print(json.dumps({k: os.environ.get(k) for k in ("
          "'API_ACCESS_TOKEN', 'PYTHONPATH', 'PYTHONHOME', '_PYTHON_HOST_PLATFORM', '_PYTHON_SYSCONFIGDATA_NAME')}))\n"
      )
      probe.chmod(0o700)
      probe_wrapper = root / "cloudflare-probe"
      probe_wrapper.write_text(
          template.replace("/synthetic/cloudflare-token", str(token_file)).replace(proxy_bin, str(probe))
      )
      probe_wrapper.chmod(0o700)
      ambient = {
          "HOME": directory,
          "PATH": os.defpath,
          "PYTHONPATH": f"/nonexistent/python3.14/site-packages:{poison.parent}",
          "PYTHONHOME": "/nonexistent/python3.14",
          "_PYTHON_HOST_PLATFORM": "linux-x86_64",
          "_PYTHON_SYSCONFIGDATA_NAME": "_sysconfigdata__linux_x86_64-linux-gnu",
      }
      probe_result = subprocess.run([str(probe_wrapper)], env=ambient, capture_output=True, text=True, timeout=5, check=True)
      observed = json.loads(probe_result.stdout)
      assert observed == {
          "API_ACCESS_TOKEN": "synthetic-cloudflare",
          "PYTHONPATH": None,
          "PYTHONHOME": None,
          "_PYTHON_HOST_PLATFORM": None,
          "_PYTHON_SYSCONFIGDATA_NAME": None,
      }, observed
      HttpServer.credentials["/cloudflare"] = "synthetic-cloudflare"
      with http.server.ThreadingHTTPServer(("127.0.0.1", 0), HttpServer) as httpd:
          wrapper = root / "cloudflare-api"
          wrapper.write_text(
              template.replace("/synthetic/cloudflare-token", str(token_file)).replace(
                  "https://mcp.cloudflare.com/mcp", f"http://127.0.0.1:{httpd.server_port}/cloudflare"
              )
          )
          wrapper.chmod(0o700)
          config = root / "mcporter.json"
          config.write_text(json.dumps({
              "imports": [],
              "mcpServers": {"cloudflare-api": {"command": str(wrapper)}},
          }))
          thread = threading.Thread(target=httpd.serve_forever)
          thread.start()
          try:
              check_server(mcporter_bin, config, root, ambient, "cloudflare-api")
          finally:
              httpd.shutdown()
              thread.join()
  print("cloudflare-api PYTHONPATH isolation and transport checks passed.")
  PY
  touch "$out"
''
