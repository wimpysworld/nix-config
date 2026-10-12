{
  fetchFromGitHub,
  lib,
  python3,
  stdenvNoCC,
}:
let
  pluginDir = "herdr-disp-model";
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-disp-model";
  # Upstream publishes no tags or releases, so the package follows the default
  # branch. The manifest at this revision reports version 0.3.0.
  version = "0-unstable-2026-09-19";

  src = fetchFromGitHub {
    owner = "pdalinis";
    repo = "herdr-disp-model";
    rev = "48a4b9490f71d2d818db145564ca6c31fc2805fa";
    hash = "sha256-6kscnaioPfxexi1Mdz3ySJnw0P3ICAJRI4k1rU5HAWc=";
  };

  # Upstream replaces Herdr's `agent` sidebar name with a label such as
  # `claude - claude-opus-5-5 - high`. This drops `--display-agent` and
  # `--clear-display-agent` from the hook script and the Pi adapter, so `agent`
  # keeps the plain name and the sidebar rows place the `$model` and `$effort`
  # tokens instead. `--agent` stays, because Herdr uses it only as a guard and
  # it does not change the name. The upstream test that asserted the label now
  # asserts that no label is sent. Each replacement fails the build if
  # upstream changes the line.
  postPatch = ''
    substituteInPlace src/model_display.py \
      --replace-fail '        "--display-agent",' "" \
      --replace-fail '        label,' "" \
      --replace-fail '        "--clear-display-agent",' ""
    substituteInPlace adapters/pi-model-display.ts \
      --replace-fail '    "--display-agent", `pi - ''${value}''${compactEffort ? ` - ''${compactEffort}` : ""}`,' "" \
      --replace-fail '    "--clear-display-agent",' ""
    substituteInPlace tests/test_model_display.py \
      --replace-fail 'self.assertIn("codex - gpt-5.6 - med", command)' \
        'self.assertNotIn("--display-agent", command)'
  '';

  dontConfigure = true;
  dontBuild = true;

  # The plugin is one standard-library Python script plus the Pi and Hermes
  # adapters. Every manifest command runs `python3` from PATH, so this pins it
  # to the store interpreter, because the Herdr server does not have Python on
  # its PATH on every host.
  installPhase = ''
    runHook preInstall
    pluginRoot="$out/share/herdr/plugins/${pluginDir}"
    install -Dm644 herdr-plugin.toml "$pluginRoot/herdr-plugin.toml"
    install -Dm755 src/model_display.py "$pluginRoot/src/model_display.py"
    install -Dm644 adapters/pi-model-display.ts "$pluginRoot/adapters/pi-model-display.ts"
    install -Dm644 adapters/hermes/__init__.py adapters/hermes/plugin.yaml \
      -t "$pluginRoot/adapters/hermes"
    install -Dm644 LICENSE README.md -t "$pluginRoot"
    substituteInPlace "$pluginRoot/herdr-plugin.toml" \
      --replace-fail 'command = ["python3",' 'command = ["${lib.getExe python3}",'
    runHook postInstall
  '';

  # Run the upstream unit tests, and check that no manifest command still runs
  # `python3` from PATH.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ! grep -q '"python3"' "$out/share/herdr/plugins/${pluginDir}/herdr-plugin.toml"
    HOME="$TMPDIR" ${lib.getExe python3} -I -m unittest discover -s tests
    runHook postInstallCheck
  '';

  passthru = rec {
    inherit pluginDir;
    pluginId = "dev.pdalinis.model-display";
    pluginRoot = "${finalAttrs.finalPackage}/share/herdr/plugins/${pluginDir}";
    # The agent modules run this with `claude-hook` or `codex-hook`. The script
    # finds Herdr through `HERDR_BIN_PATH`, which Herdr sets in every pane.
    hookCommand = "${lib.getExe python3} ${pluginRoot}/src/model_display.py";
    piExtension = "${pluginRoot}/adapters/pi-model-display.ts";
  };

  meta = {
    description = "Herdr plugin that shows the model and reasoning effort of each agent";
    homepage = "https://github.com/pdalinis/herdr-disp-model";
    changelog = "https://github.com/pdalinis/herdr-disp-model/commits/main";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
