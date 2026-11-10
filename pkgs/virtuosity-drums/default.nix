{
  lib,
  fetchurl,
  python3,
  sfizz,
  stdenvNoCC,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "virtuosity-drums";
  version = "0.925";

  src = fetchurl {
    url = "https://github.com/sfzinstruments/virtuosity_drums/releases/download/v${finalAttrs.version}/Virtuosity_Drums_v${finalAttrs.version}.zip";
    hash = "sha256-xsXQ/hGjlOlL4xRqlQwzd+wQLLV9GJ1aI87CYYPRljo=";
  };

  nativeBuildInputs = [
    python3
    unzip
  ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/sfz/${finalAttrs.pname}"
    unzip -q "$src" -d "$out/share/sfz/${finalAttrs.pname}"
    python ${./prepare-sfizz.py} "$out/share/sfz/${finalAttrs.pname}"
    runHook postInstall
  '';

  doInstallCheck =
    stdenvNoCC.hostPlatform.isLinux && stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
  nativeInstallCheckInputs = [ sfizz ];
  installCheckPhase = ''
    runHook preInstallCheck
    python ${./check-sfizz.py} ${lib.getLib sfizz}/lib/libsfizz.so "$out/share/sfz/${finalAttrs.pname}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Sampled jazz drum kit with six microphone positions in SFZ format";
    homepage = "https://versilian-studios.com/virtuosity-drums/";
    license = lib.licenses.cc0;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
  };
})
