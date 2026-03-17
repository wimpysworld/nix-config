{
  fetchurl,
  lib,
  makeWrapper,
  stdenvNoCC,
  undmg,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "openchamber-desktop";
  version = "1.8.7";

  src = fetchurl {
    url = "https://github.com/btriapitsyn/openchamber/releases/download/v${finalAttrs.version}/OpenChamber_${finalAttrs.version}_darwin-aarch64.dmg";
    hash = "sha256-fxTBIP8Cz4/hKJCDFC4a1APsesK3hj4nba43n1Xy9A8=";
  };

  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  nativeBuildInputs = [
    makeWrapper
    undmg
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    chmod -R +x OpenChamber.app/Contents/MacOS/
    cp -r *.app $out/Applications

    mkdir -p $out/bin
    makeWrapper "$out/Applications/OpenChamber.app/Contents/MacOS/openchamber-desktop" "$out/bin/openchamber-desktop"

    runHook postInstall
  '';

  meta = {
    description = "OpenChamber Desktop";
    homepage = "https://github.com/btriapitsyn/openchamber";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "openchamber-desktop";
  };
})
