{
  fetchzip,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "commodore_64_pixelized";
  version = "1.2";

  src = fetchzip {
    url = "https://dl.dafont.com/dl/?f=${pname}";
    hash = "sha256-DAnToB/EIzCF45+ebOu7cq3cpsQg5j4xxnVHTOMapBA=";
    extension = "zip";
    stripRoot = false;
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/truetype/${pname} *.ttf
  '';

  meta = {
    description = "Commodore 64 Pixelized Font";
    longdescription = "The Commodore 64 font.";
    homepage = "https://www.dafont.com/${pname}.font";
    license = lib.licenses.free;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
