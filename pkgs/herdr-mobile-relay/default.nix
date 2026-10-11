{
  buildGo127Module,
  fetchFromGitHub,
  lib,
  stdenv,
}:
let
  pluginDir = "herdr-mobile-relay";
  # The in-relay updater refuses any revision that is not a 40-character Git
  # hash, so a non-hex revision keeps the phone update button from replacing
  # this store build with an upstream release.
  revision = "nix-${version}";
  version = "0.22.7";
  target = "${
    if stdenv.hostPlatform.isDarwin then "darwin" else "linux"
  }/${stdenv.hostPlatform.go.GOARCH}";
in
# go.mod declares `go 1.27.0`, which the default Go toolchain is too old for.
buildGo127Module (finalAttrs: {
  pname = "herdr-mobile-relay";
  inherit version;

  src = fetchFromGitHub {
    owner = "0cv";
    repo = "herdr-mobile-relay";
    tag = "v${finalAttrs.version}";
    hash = "sha256-uHKIOgP3OlRHLMS3MvhMTXFM9fNHX7qzCLwPO2cQQMM=";
  };

  vendorHash = "sha256-wczagA/d0yR0hXEfg6ohwlJ/cqBF6zxQL+PlfDD0HFA=";

  subPackages = [ "cmd/herdr-mobile-relay" ];

  # Upstream builds every release without cgo; SQLite is the pure Go modernc
  # driver.
  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
    "-X main.revision=${revision}"
  ];

  # Herdr does not run `[[build]]` commands for a linked plugin, so the tree
  # below takes the place of the release bundle that `relay/plugin-build.sh`
  # downloads. The phone app is the `web/` tree that upstream commits and
  # checks against a fresh frontend build in CI.
  postInstall = ''
    pluginRoot="$out/share/herdr/plugins/${pluginDir}"
    mkdir -p "$pluginRoot"
    cp -r herdr-plugin.toml relay web LICENSE README.md "$pluginRoot/"
    # The release manifest rejects symlinks inside the tree, so the binary
    # lives there as a regular file and bin/ links to it.
    mv "$out/bin/herdr-mobile-relay" "$pluginRoot/herdr-mobile-relay"
    ln -s "$pluginRoot/herdr-mobile-relay" "$out/bin/herdr-mobile-relay"

    # The event hook only looks for a release under ~/.local/share.
    substituteInPlace "$pluginRoot/relay/plugin-on-event.sh" \
      --replace-fail '"$RELEASE_ROOT/current/herdr-mobile-relay"' "\"$pluginRoot/herdr-mobile-relay\""
  '';

  # The manifest hashes every file, so it must follow stripping and shebang
  # patching.
  postFixup = ''
    pluginRoot="$out/share/herdr/plugins/${pluginDir}"
    "$pluginRoot/herdr-mobile-relay" release-manifest \
      "$pluginRoot" ${finalAttrs.version} ${revision} ${target} >/dev/null
  '';

  # The plugin scripts use the binary only when release-manifest.json verifies
  # beside relay/. Check the tree and that the plugin manifest matches the
  # package version after a freshener bump.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    pluginRoot="$out/share/herdr/plugins/${pluginDir}"
    "$pluginRoot/herdr-mobile-relay" verify-release \
      --version ${finalAttrs.version} --revision ${revision} "$pluginRoot" >/dev/null
    grep -qx 'version = "${finalAttrs.version}"' "$pluginRoot/herdr-plugin.toml"
    runHook postInstallCheck
  '';

  passthru = rec {
    inherit pluginDir;
    pluginRoot = "${finalAttrs.finalPackage}/share/herdr/plugins/${pluginDir}";
    webRoot = "${pluginRoot}/web";
  };

  meta = {
    description = "Remote mobile control for Herdr with an installable phone app";
    homepage = "https://github.com/0cv/herdr-mobile-relay";
    changelog = "https://github.com/0cv/herdr-mobile-relay/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Plus;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "herdr-mobile-relay";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
