{
  fetchzip,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "zx_spectrum_7";
  version = "1.2";

  src = fetchzip {
    url = "https://dl.dafont.com/dl/?f=${pname}";
    hash = "sha256-TqFDh/kmlqL9350Gp/VGUrZNfHifh8uOR6qLCRnI4KM=";
    extension = "zip";
    stripRoot = false;
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/truetype/${pname} *.ttf
  '';

  meta = {
    description = "ZX Spectrum-7 Font";
    longdescription = "ZX Spectrum font.";
    homepage = "https://www.dafont.com/${pname}.font";
    license = lib.licenses.free;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
