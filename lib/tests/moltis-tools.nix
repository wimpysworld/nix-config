# Run by checks.x86_64-linux.moltis-tools.
{
  lib,
  pkgs,
  homeConfigurations,
}:
let
  mcporter =
    lib.findFirst (package: (package.pname or "") == "mcporter")
      (throw "Moltis requires the pinned MCPorter package")
      homeConfigurations."martin@skrye".config.home.packages;
  checkHost =
    host:
    let
      c = homeConfigurations."martin@${host}".config;
      context = c.agentic.moltis.toolsContext;
      files = c.agentic.assistants.ownedSpec.files;
      tools = builtins.filter (
        entry:
        lib.hasSuffix "/TOOLS.md" entry.path && lib.hasPrefix "${c.home.homeDirectory}/.moltis/" entry.path
      ) files;
      root = builtins.head tools;
      body = builtins.readFile root.source;
      darwin = context.platform == "darwin";
      gemini = context.provider == "gemini";
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
    assert cli.mcpServers == defs.moltisMcporterServers;
    assert cli.mcpServers.linear.headers.Authorization == "Bearer \${LINEAR_API_KEY}";
    assert cli.mcpServers.context7.headers.Authorization == "Bearer \${CONTEXT7_API_KEY}";
    assert !(lib.hasInfix "<SOPS:" c.xdg.configFile."moltis/mcporter.json".text);
    assert lib.elem "LINEAR_API_KEY" envNames;
    assert settings.env ? LINEAR_API_KEY;
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
    assert builtins.all
      (
        name:
        let
          preset = settings.agents.presets.${name};
        in
        preset.model == context.auxiliaryModel
        && preset.reasoning_effort == (if host == "momin" then "high" else "medium")
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
    assert lib.hasInfix "systemctl --user" body == !darwin;
    assert lib.hasInfix "journalctl --user" body == !darwin;
    assert lib.hasInfix "Linux Fence mounts" body == !darwin;
    assert
      lib.hasInfix "`.git/config` and `.git/hooks` read-only, including in maintenance checkouts" body
      == !darwin;
    true;
in
assert builtins.all checkHost [
  "skrye"
  "zannah"
  "momin"
];
pkgs.runCommand "moltis-tools" { } ''
  ${pkgs.python3}/bin/python3 ${../../home-manager/_mixins/agentic/assistants/owned-files}/test_deploy.py
  PYTHONDONTWRITEBYTECODE=1 ${pkgs.python3}/bin/python3 ${../../home-manager/_mixins/agentic/moltis/mcp-cli-migration}/test_migrate.py
  PYTHONDONTWRITEBYTECODE=1 ${pkgs.python3}/bin/python3 ${../../home-manager/_mixins/agentic/moltis/mcp-cli-migration}/test_mcporter.py ${lib.getExe mcporter}
  touch "$out"
''
