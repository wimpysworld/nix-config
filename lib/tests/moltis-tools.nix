# Run by checks.x86_64-linux.moltis-tools.
{
  lib,
  pkgs,
  homeConfigurations,
}:
let
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
    assert lib.hasInfix "Linear is configured on this host." body == (host != "momin");
    assert lib.elem "linear" context.mcpServers == (host != "momin");
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
  touch "$out"
''
