{
  lib,
  fetchurl,
  stdenvNoCC,
  python3,
  unzip,
}:

stdenvNoCC.mkDerivation {
  pname = "tchackpoum-ludwig-black-cortex";
  version = "0-unstable-2026-09-14";

  src = fetchurl {
    name = "tchackpoum-ludwig-black-cortex.zip";
    url = "https://tchackpoum.com/ReaperDrummer%20Ludwig%20Black%20Cortex.zip";
    hash = "sha256-5rbOQoEI9stQdVueJMSFdc1uIxq/kNG0728B2XPzW94=";
    curlOptsList = [
      "--referer"
      "https://tchackpoum.com/Eng.html"
    ];
    meta.license = lib.licenses.unfree;
  };

  nativeBuildInputs = [
    python3
    unzip
  ];
  dontConfigure = true;
  dontBuild = true;
  preferLocalBuild = true;
  allowSubstitutes = false;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/tchackpoum-ludwig-black-cortex"
    cp -r ./. "$out/share/tchackpoum-ludwig-black-cortex/"
    python ${./adapt-templates.py} "$out"
    runHook postInstall
  '';

  meta = {
    description = "Ludwig Black Cortex acoustic drums with native REAPER 7 templates";
    homepage = "https://tchackpoum.com/Eng.html";
    # Upstream permits free, royalty-free use but does not identify its Creative Commons licence variant.
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
  };
}
