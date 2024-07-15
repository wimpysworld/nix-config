{
  fetchzip,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "boycott";
  version = "1.00";

  src = fetchzip {
    url = " https://dl.dafont.com/dl/?f=${pname}";
    hash = "sha256-2n/FXp31n2LVdHW/75vuipb50pMjeVDSKTbBc10XS94=";
    extension = "zip";
    stripRoot = false;
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/truetype/${pname} *.TTF
  '';

  meta = {
    description = "Boycott Font";
    longdescription = ''
      This grungy font with a noisy design that it a little rough around the
      edges; a perfect design for posters and large headlines. Designed based
      on Bebas (2005).
    '';
    homepage = "https://www.dafont.com/${pname}.font";
    license = lib.licenses.free;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
