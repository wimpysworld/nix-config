{
  coreutils,
  herdr,
  jq,
  lib,
  runCommand,
  stdenvNoCC,
  writeShellApplication,
}:

let
  eventScript = writeShellApplication {
    name = "herdr-work-layout";
    runtimeInputs = [
      coreutils
      jq
    ];
    text = builtins.readFile ./herdr-work-layout.sh;
  };

  test = runCommand "herdr-work-layout-test" {
    nativeBuildInputs = [
      coreutils
      jq
    ];
    script = "${eventScript}/bin/herdr-work-layout";
    fakeHerdr = ./tests/fake-herdr.sh;
  } (builtins.readFile ./tests/test.sh);
in
assert lib.assertMsg (
  herdr.version == "0.8.2"
) "herdr-work-layout requires the Herdr v0.8.2 event schema";
stdenvNoCC.mkDerivation {
  pname = "herdr-work-layout";
  version = "0.3.1";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    pluginRoot="$out/share/herdr/plugins/work-layout"
    install -Dm644 ${./herdr-plugin.toml} "$pluginRoot/herdr-plugin.toml"
    mkdir -p "$out/bin" "$pluginRoot/bin"
    ln -s ${eventScript}/bin/herdr-work-layout "$out/bin/herdr-work-layout"
    ln -s ${eventScript}/bin/herdr-work-layout "$pluginRoot/bin/herdr-work-layout"

    runHook postInstall
  '';

  passthru.tests.herdr-work-layout = test;

  meta = {
    description = "Workspace layout and worktree commands for Herdr";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "herdr-work-layout";
    platforms = lib.platforms.linux;
  };
}
