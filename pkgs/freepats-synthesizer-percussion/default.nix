{
  lib,
  fetchurl,
  stdenvNoCC,
  _7zz,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "freepats-synthesizer-percussion";
  version = "2022-07-18";

  src = fetchurl {
    url = "https://freepats.zenvoid.org/Percussion/SynthesizerPercussion/SynthesizerPercussion-SFZ-${
      lib.replaceStrings [ "-" ] [ "" ] finalAttrs.version
    }.7z";
    hash = "sha256-27Llu4JoAi//ptzD0RqTNoMWA4vzroGpZcWOnUkO0js=";
  };

  nativeBuildInputs = [ _7zz ];
  unpackCmd = "7zz x $curSrc";
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/sfz/${finalAttrs.pname}"
    cp -r ./. "$out/share/sfz/${finalAttrs.pname}/"
    runHook postInstall
  '';

  meta = {
    description = "Synthesised electronic drum kit in SFZ format";
    homepage = "https://freepats.zenvoid.org/Percussion/electric-percussion.html";
    license = lib.licenses.cc0;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
  };
})
