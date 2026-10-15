{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
let
  pluginDir = "herdr-telegram-agents";
in
buildGoModule (finalAttrs: {
  pname = "herdr-telegram-agents";
  version = "0.17.2";

  src = fetchFromGitHub {
    owner = "permgps";
    repo = "herdr-telegram-agents";
    tag = "v${finalAttrs.version}";
    hash = "sha256-HGShGs5I3sAJD0GF3lb8ggs/46CAW5QpRF+/IrAZD+s=";
  };

  vendorHash = "sha256-BHHQlARGtvZiZ5BQqZYrz4gD3E0Xr/TybAD5LpSvX0M=";

  subPackages = [ "cmd/herdr-tg" ];

  # Upstream builds every release without cgo.
  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  # Herdr does not run `[[build]]` commands for a linked plugin, so the tree
  # below takes the place of the release binary that `scripts/install.sh`
  # downloads. Every manifest command runs `bin/herdr-tg` relative to the
  # plugin root.
  postInstall = ''
    pluginRoot="$out/share/herdr/plugins/${pluginDir}"
    mkdir -p "$pluginRoot/bin"
    cp herdr-plugin.toml LICENSE README.md "$pluginRoot/"
    mv "$out/bin/herdr-tg" "$pluginRoot/bin/herdr-tg"
    ln -s "$pluginRoot/bin/herdr-tg" "$out/bin/herdr-tg"
  '';

  # Check that the plugin manifest matches the package version after a
  # freshener bump, and that the binary reports the same version.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    pluginRoot="$out/share/herdr/plugins/${pluginDir}"
    grep -qx 'version = "${finalAttrs.version}"' "$pluginRoot/herdr-plugin.toml"
    "$pluginRoot/bin/herdr-tg" version | grep -qF '${finalAttrs.version}'
    runHook postInstallCheck
  '';

  passthru = {
    inherit pluginDir;
    pluginId = "permgps.telegram-agents";
    pluginRoot = "${finalAttrs.finalPackage}/share/herdr/plugins/${pluginDir}";
  };

  meta = {
    description = "Herdr plugin that mirrors each agent into a Telegram forum topic";
    homepage = "https://github.com/permgps/herdr-telegram-agents";
    changelog = "https://github.com/permgps/herdr-telegram-agents/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "herdr-tg";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
