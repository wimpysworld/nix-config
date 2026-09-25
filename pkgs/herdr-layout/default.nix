{
  coreutils,
  herdr,
  jq,
  lib,
  runCommand,
  stdenvNoCC,
  writeShellApplication,
  writeText,
  work ? false,
}:

let
  layoutName = if work then "work-layout" else "home-layout";

  # Labels without a command value keep a plain shell pane.
  agentCommands =
    if work then
      {
        Claude = "claude-fenced";
        Codex = "codex-fenced --noughty-fresh";
        Git = "lg";
        Code = "fresh .";
        Shell = "clear";
      }
    else
      {
        OpenCode = "opencode-fenced";
        Pi = "pi-fenced";
        Git = "lg";
        Code = "fresh .";
        Shell = "clear";
      };

  formatCase = label: command: ''[${label}]="${command}"'';

  eventScriptText =
    let
      commandLines = lib.concatStringsSep "\n" (lib.mapAttrsToList formatCase agentCommands);
      initialLabel = if work then "Claude" else "OpenCode";
      extraPanes = if work then "Codex Git Code Shell" else "Pi Git Code Shell";
    in
    builtins.replaceStrings
      [ "@INITIAL_LABEL@" "@EXTRA_PANES@" "@AGENT_COMMANDS@" "@REVIEW_ENABLED@" ]
      [
        initialLabel
        extraPanes
        commandLines
        (if work then "1" else "0")
      ]
      (builtins.readFile ./herdr-layout.sh);

  eventScript = writeShellApplication {
    name = "herdr-${layoutName}";
    runtimeInputs = [
      coreutils
      herdr
      jq
    ];
    text = eventScriptText;
  };

  pluginTitle = if work then "Work layout" else "Home layout";

  pluginManifest = writeText "herdr-plugin-${layoutName}.toml" ''
    id = "local.${layoutName}"
    name = "${pluginTitle}"
    version = "0.4.0"
    min_herdr_version = "0.8.2"
    description = "Prepare workspace tabs and agent panes with a fixed pane set"
    platforms = ["linux"]

    [[events]]
    on = "workspace.created"
    command = ["bin/herdr-${layoutName}"]
  '';

  layoutTest = runCommand "herdr-layout-${layoutName}-test" {
    nativeBuildInputs = [
      coreutils
      jq
    ];
    variant = if work then "work" else "home";
    script = "${eventScript}/bin/herdr-${layoutName}";
    fakeHerdr = ./tests/fake-herdr.sh;
  } (builtins.readFile ./tests/test.sh);

in
assert lib.assertMsg (builtins.elem herdr.version [
  "0.8.2"
  "0.9.0"
  "0.9.1"
]) "herdr-layout requires the Herdr v0.8.2, v0.9.0, or v0.9.1 event schema";
stdenvNoCC.mkDerivation {
  pname = "herdr-${layoutName}";
  version = "0.4.0";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    pluginRoot="$out/share/herdr/plugins/${layoutName}"
    install -Dm644 ${pluginManifest} "$pluginRoot/herdr-plugin.toml"
    mkdir -p "$out/bin" "$pluginRoot/bin"
    ln -s ${eventScript}/bin/herdr-${layoutName} "$out/bin/herdr-${layoutName}"
    ln -s ${eventScript}/bin/herdr-${layoutName} "$pluginRoot/bin/herdr-${layoutName}"

    runHook postInstall
  '';

  passthru = {
    inherit layoutName work;
    pluginDir = layoutName;
    tests.${layoutName} = layoutTest;
  };

  meta = {
    description = "Fixed pane sets and agent autostart for Herdr workspaces";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "herdr-${layoutName}";
    platforms = lib.platforms.linux;
  };
}
