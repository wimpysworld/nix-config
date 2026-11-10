{
  lib,
  fetchurl,
  python3,
  stdenvNoCC,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "karoryfer-black-and-blue-basses";
  version = "1.002";

  src = fetchurl {
    url = "https://github.com/sfzinstruments/karoryfer.black-and-blue-basses/releases/download/v${finalAttrs.version}/Black_And_Blue_Basses_1002.zip";
    hash = "sha256-z3f8eCq/mWgm/nXP2UjTVpaN58i5Z8RxxqQzg10rT1U=";
  };

  nativeBuildInputs = [ unzip ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/sfz/${finalAttrs.pname}"
    unzip -q "$src" -d "$out/share/sfz/${finalAttrs.pname}"
    ${python3.interpreter} ${./prepare-sfizz.py} "$src" "$out/share/sfz/${finalAttrs.pname}"
    runHook postInstall
  '';

  meta = {
    description = "Sampled fingered hollow-body and picked solid-body basses in SFZ format";
    homepage = "https://github.com/sfzinstruments/karoryfer.black-and-blue-basses";
    license = lib.licenses.cc0;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
  };
})
