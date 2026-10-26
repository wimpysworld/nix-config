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
  version = "0.26.1";

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
        hash = "sha256-v99G0l0paNeqZINmwO19ey0ueMPx0x5o1enUQR5atvk=";
      };
      aarch64-linux = fetchurl {
        url = "${base}/openusage_${finalAttrs.version}_linux_arm64.tar.gz";
        hash = "sha256-TflkXFS9iilFyPX9g9mh4JHSv5QY3IpEhef7Mtx0DCM=";
      };
      x86_64-darwin = fetchurl {
        url = "${base}/openusage_${finalAttrs.version}_darwin_amd64.tar.gz";
        hash = "sha256-qqki9HUAEPe616oLaCae0r99/7/n4Bs1/N1hEhdrXgU=";
      };
      aarch64-darwin = fetchurl {
        url = "${base}/openusage_${finalAttrs.version}_darwin_arm64.tar.gz";
        hash = "sha256-UTjc9/oBMvLuJgk7gtMdceFXaLf3YoO6sDj+2QHBeV4=";
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
