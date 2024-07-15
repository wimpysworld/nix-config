{
  fetchzip,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "digital_7";
  version = "1.020";

  src = fetchzip {
    url = "https://dl.dafont.com/dl/?f=${pname}";
    hash = "sha256-gufM+ofcUvCnc7vjBH3lA7IvcEBCd9xetZwFy3H0SHY=";
    extension = "zip";
    stripRoot = false;
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/truetype/${pname} *.ttf
  '';

  meta = {
    description = "Digital 7 Font";
    longdescription = "Digital 7, a seven-segment font.";
    homepage = "https://www.dafont.com/${pname}.font";
    license = lib.licenses.free;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
