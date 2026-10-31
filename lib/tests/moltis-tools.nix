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
    "momin"
  ];
  # Expose the nested script without building or running either launcher.
  launcherScripts =
    host:
    let
      home = homeConfigurations."martin@${host}";
      module = import ../../home-manager/_mixins/agentic/moltis {
        config = home.config;
        inherit (home) pkgs;
        inherit (home._module.specialArgs) inputs;
        inherit (home._module.args) noughtyLib;
        lib = lib // {
          hm = home.config.lib;
          getExe =
            package:
            if (package.name or "") == "moltis-in-fence" then
              "MOLTIS_TEST_INNER_START${package.text}MOLTIS_TEST_INNER_END"
            else
              lib.getExe package;
        };
      };
      outer = lib.findFirst (
        package: package.name == "moltis-fenced"
      ) (throw "Missing Moltis launcher") module.config.content.home.packages;
      parts = lib.splitString "MOLTIS_TEST_INNER_START" outer.text;
    in
    {
      outer = builtins.head parts;
      inner = builtins.head (lib.splitString "MOLTIS_TEST_INNER_END" (builtins.elemAt parts 1));
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
      guidelinesSource = (builtins.head guidelines).source;
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
    assert builtins.all (
      entry: !(lib.hasPrefix "${c.home.homeDirectory}/.moltis/" entry.path)
    ) disabled.agentic.assistants.ownedSpec.files;
    assert !(lib.elem "${c.home.homeDirectory}/.moltis" disabled.agentic.assistants.ownedSpec.roots);
    assert !(disabled.home.activation ? moltisAssistantBootstrap);
    assert !(disabled.xdg.configFile ? "moltis/mcporter.json");
    assert !(lib.any (package: (package.name or "") == "moltis-fenced") disabled.home.packages);
    assert builtins.all
      (
        name:
        lib.hasInfix ''
          ${name}="$(< ${lib.escapeShellArg c.sops.secrets.${name}.path})"
          export ${name}
        '' scripts.inner
      )
      [
        "LINEAR_API_KEY"
        "CONTEXT7_API_KEY"
      ];
    assert builtins.all (
      name:
      lib.hasInfix "&& -r ${lib.escapeShellArg c.sops.secrets.${name}.path}" scripts.outer
      && lib.hasInfix "|| ! -r ${lib.escapeShellArg c.sops.secrets.${name}.path}" scripts.outer
    ) (defs.requiredSecretsForConsumers [ "moltis" ] ++ [ "CLOUDFLARE_API_TOKEN" ]);
    assert !(lib.hasInfix "CLOUDFLARE_API_TOKEN" scripts.inner);
    assert !(lib.hasInfix "export CLOUDFLARE_API_TOKEN" scripts.outer);
    assert lib.hasInfix "export LINEAR_API_KEY" scripts.inner == (cli.mcpServers ? linear);
    assert lib.hasInfix "-systemd-" scripts.inner == !darwin;
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
  ${pkgs.python3}/bin/python3 - ${builtins.toFile "moltis-launcher-fixtures.json" (builtins.unsafeDiscardStringContext (builtins.toJSON launcherFixtures))} ${pkgs.bash}/bin/bash <<'PY'
  import json
  import os
  from pathlib import Path
  import re
  import subprocess
  import sys
  import tempfile

  fixtures = json.loads(Path(sys.argv[1]).read_text())
  bash = sys.argv[2]
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
  assert os.environ["LINEAR_API_KEY"] == "synthetic-LINEAR_API_KEY"
  assert os.environ["CONTEXT7_API_KEY"] == "synthetic-CONTEXT7_API_KEY"
  assert "CLOUDFLARE_API_TOKEN" not in os.environ
  """
          command = prologue + f"{sys.executable} - <<'CHILD'\n{child}\nCHILD\n"
          env = {"HOME": directory, "PATH": os.defpath}
          result = subprocess.run([bash, "-c", command], env=env, capture_output=True, timeout=5)
          assert result.returncode == 0, (fixture["host"], result.stderr)
          marker = root / "child-started"
          marker.unlink()
          ready = re.search(r"(\[\[ -r .*?\]\]) && break", outer).group(1)
          failed = re.search(r"if (\[\[ ! -r .*?\]\]); then", outer).group(1)
          for missing in (None, "LINEAR_API_KEY", "CONTEXT7_API_KEY", "CLOUDFLARE_API_TOKEN"):
              if missing:
                  paths[missing].unlink()
              for condition, expected in ((ready, missing is None), (failed, missing is not None)):
                  result = subprocess.run([bash, "-c", condition], env=env, capture_output=True, timeout=5)
                  assert (result.returncode == 0) == expected, (fixture["host"], missing, condition)
              if missing in ("LINEAR_API_KEY", "CONTEXT7_API_KEY"):
                  result = subprocess.run([bash, "-c", command], env=env, capture_output=True, timeout=5)
                  assert result.returncode != 0, (fixture["host"], missing)
                  assert not marker.exists(), (fixture["host"], missing, "child started without credentials")
              if missing:
                  paths[missing].write_text("synthetic-" + missing)
  print("Moltis launcher checks passed for all three hosts.")
  PY
  ${pkgs.python3}/bin/python3 ${../../home-manager/_mixins/agentic/assistants/owned-files}/test_deploy.py
  PYTHONDONTWRITEBYTECODE=1 ${pkgs.python3}/bin/python3 ${../../home-manager/_mixins/agentic/moltis/mcp-cli-migration}/test_migrate.py
  PYTHONDONTWRITEBYTECODE=1 ${pkgs.python3}/bin/python3 ${../../home-manager/_mixins/agentic/moltis/mcp-cli-migration}/test_mcporter.py ${lib.getExe mcporter}
  touch "$out"
''
