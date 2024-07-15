{
  fetchzip,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "impact_label";
  version = "2.000";

  src = fetchzip {
    url = "https://dl.dafont.com/dl/?f=${pname}";
    hash = "sha256-zIUPsEpd+vJZNcgvSbEIF1efO0GCXyVHK0w07DQz7Ug=";
    extension = "zip";
    stripRoot = false;
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/truetype/${pname} *.ttf
  '';

  meta = {
    description = "Impact Label Font";
    longdescription = "Label everything. Just like your Dad used to in the 1970's!";
    homepage = "https://www.dafont.com/${pname}.font";
    license = lib.licenses.free;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
