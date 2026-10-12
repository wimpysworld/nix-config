{
  fetchFromGitHub,
  lib,
  python3,
  stdenvNoCC,
}:
let
  pluginDir = "herdr-ctx-bar";
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-ctx-bar";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "pdalinis";
    repo = "herdr-ctx-bar";
    tag = "v${finalAttrs.version}";
    hash = "sha256-jD5XGvWZyf5AYKw9dMSny4lPt8BEhEBVgv0ub783zhg=";
  };

  dontConfigure = true;
  dontBuild = true;

  # The plugin is one standard-library Python script. Every manifest command
  # runs `python3` from PATH, so this pins it to the store interpreter, because
  # the Herdr server does not have Python on its PATH on every host.
  installPhase = ''
    runHook preInstall
    pluginRoot="$out/share/herdr/plugins/${pluginDir}"
    install -Dm644 herdr-plugin.toml "$pluginRoot/herdr-plugin.toml"
    install -Dm755 bin/ctx_bar.py "$pluginRoot/bin/ctx_bar.py"
    install -Dm644 LICENSE README.md -t "$pluginRoot"
    substituteInPlace "$pluginRoot/herdr-plugin.toml" \
      --replace-fail 'command = ["python3",' 'command = ["${lib.getExe python3}",'
    runHook postInstall
  '';

  # Run the upstream unit tests, and check that the manifest matches the
  # package version after a freshener bump and that no command still runs
  # `python3` from PATH.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    pluginRoot="$out/share/herdr/plugins/${pluginDir}"
    grep -qx 'version = "${finalAttrs.version}"' "$pluginRoot/herdr-plugin.toml"
    ! grep -q '"python3"' "$pluginRoot/herdr-plugin.toml"
    HOME="$TMPDIR" ${lib.getExe python3} -I -m unittest discover -s tests
    runHook postInstallCheck
  '';

  passthru = {
    inherit pluginDir;
    pluginId = "herdr-ctx-bar";
    pluginRoot = "${finalAttrs.finalPackage}/share/herdr/plugins/${pluginDir}";
  };

  meta = {
    description = "Herdr plugin that shows a colour-coded context usage bar for each agent";
    homepage = "https://github.com/pdalinis/herdr-ctx-bar";
    changelog = "https://github.com/pdalinis/herdr-ctx-bar/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
