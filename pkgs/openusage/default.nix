{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  glibc,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "openusage";
  version = "0.26.3";

  src =
    finalAttrs.passthru.sources.${stdenvNoCC.hostPlatform.system}
      or (throw "openusage: no binary available for ${stdenvNoCC.hostPlatform.system}");

  strictDeps = true;
  sourceRoot =
    if stdenvNoCC.hostPlatform.isDarwin then
      "openusage_${finalAttrs.version}_darwin_${
        if stdenvNoCC.hostPlatform.isAarch64 then "arm64" else "amd64"
      }"
    else
      ".";

  nativeBuildInputs = [
    writableTmpDirAsHomeHook
  ]
  ++ lib.optional stdenvNoCC.hostPlatform.isLinux autoPatchelfHook;
  buildInputs = lib.optional stdenvNoCC.hostPlatform.isLinux glibc;

  installPhase = ''
    runHook preInstall
    install -Dm0755 openusage "$out/bin/openusage"
    install -Dm0644 LICENSE "$out/share/licenses/openusage/LICENSE"
    runHook postInstall
  '';

  doInstallCheck = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckKeepEnvironment = [ "HOME" ];
  versionCheckProgramArg = "--version";

  passthru.sources =
    let
      base = "https://github.com/janekbaraniewski/openusage/releases/download/v${finalAttrs.version}";
    in
    {
      x86_64-linux = fetchurl {
        url = "${base}/openusage_${finalAttrs.version}_linux_amd64.tar.gz";
        hash = "sha256-FxquIQ/5P0I7Cntr4nahzNogRcU+vp22NiNkuEEiWWA=";
      };
      aarch64-linux = fetchurl {
        url = "${base}/openusage_${finalAttrs.version}_linux_arm64.tar.gz";
        hash = "sha256-z4rHRi0sJyeN7GpJMfxDA1wok/Ld+QvnyWNgrqCbXnU=";
      };
      x86_64-darwin = fetchurl {
        url = "${base}/openusage_${finalAttrs.version}_darwin_amd64.tar.gz";
        hash = "sha256-JNGYM0KInK6xonwye4iwsgalUk7FiwjOFOjnRiP0T4E=";
      };
      aarch64-darwin = fetchurl {
        url = "${base}/openusage_${finalAttrs.version}_darwin_arm64.tar.gz";
        hash = "sha256-pQ8ENLncQXePnyHZrM1smrZdcgvqgrmonUnnvV/Y8Qc=";
      };
    };

  meta = {
    description = "Terminal dashboard for AI coding tool usage and spend";
    homepage = "https://github.com/janekbaraniewski/openusage";
    downloadPage = "https://github.com/janekbaraniewski/openusage/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ flexiondotorg ];
    mainProgram = "openusage";
    platforms = lib.attrNames finalAttrs.passthru.sources;
  };
})
