{
  lib,
  fetchurl,
  stdenvNoCC,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "karoryfer-growlybass";
  version = "1.002";

  src = fetchurl {
    url = "https://github.com/sfzinstruments/karoryfer.growlybass/releases/download/v${finalAttrs.version}/Karoryfer.Growlybass.v${finalAttrs.version}.zip";
    hash = "sha256-uS3KdUlPo51ujYuK3aq/5wxaqlm1+aD2JL5t5RojdLw=";
  };

  nativeBuildInputs = [ unzip ];
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/sfz/karoryfer-growlybass"
    cp -r ./. "$out/share/sfz/karoryfer-growlybass/"
    runHook postInstall
  '';

  meta = {
    description = "Sampled Jazz Bass with sustain, staccato and release SFZ programs";
    homepage = "https://github.com/sfzinstruments/karoryfer.growlybass";
    license = lib.licenses.cc0;
    platforms = lib.platforms.all;
  };
})
