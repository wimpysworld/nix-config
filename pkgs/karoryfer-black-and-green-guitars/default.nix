{
  lib,
  fetchurl,
  stdenvNoCC,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "karoryfer-black-and-green-guitars";
  version = "1.000";

  src = fetchurl {
    url = "https://github.com/sfzinstruments/karoryfer.black-and-green-guitars/releases/download/v${finalAttrs.version}/Karoryfer_Black_And_Green_Guitars_1000.zip";
    hash = "sha256-upUiHTL7Y4bF0KB5m5OQT9VVIKygF8XxIdopAHXBQMA=";
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
    description = "Sampled electric guitars in SFZ format";
    homepage = "https://shop.karoryfer.com/pages/free-black-and-green-guitars";
    license = lib.licenses.cc0;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
  };
})
