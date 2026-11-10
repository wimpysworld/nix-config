{
  lib,
  fetchurl,
  stdenvNoCC,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "karoryfer-pastabass";
  version = "1.101";

  src = fetchurl {
    url = "https://github.com/sfzinstruments/karoryfer.pastabass/releases/download/v${finalAttrs.version}/Karoryfer.Pastabass.v${finalAttrs.version}.zip";
    hash = "sha256-3yvxIlbiS7NAfSBBBTZc8p9LjZAhEiXuGp1QfwZwgFw=";
  };

  nativeBuildInputs = [ unzip ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/sfz/${finalAttrs.pname}"
    unzip -q "$src" -d "$out/share/sfz/${finalAttrs.pname}"
    runHook postInstall
  '';

  meta = {
    description = "Sampled six-string bass with roundwound and flatwound strings in SFZ format";
    homepage = "https://github.com/sfzinstruments/karoryfer.pastabass";
    license = lib.licenses.cc0;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
  };
})
