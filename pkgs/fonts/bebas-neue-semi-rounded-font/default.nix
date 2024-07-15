{
  fetchzip,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "bebas_neue_semi_rounded";
  version = "1.000";

  src = fetchzip {
    url = "https://www.dfonts.org/wp-content/uploads/fonts/Bebas_Neue_SemiRounded.zip";
    hash = "sha256-UV6HN8ECfvwnWtvPxdKLmBeV99w/r/DClBBBd4+MmEA=";
    stripRoot = false;
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/opentype/${pname} Bebas_Neue_SemiRounded/bebas-neue-semirounded.otf
  '';

  meta = {
    description = "Bebas Neue Semi-Rounded Font";
    longdescription = ''
      Bebas Neue Semi Rounded is the Bebas Neue with rounded corners.
      This semi-rounded version proportion are same as Bebas Neue but rounded
      shape gives a warm, soft and natural impression. A bit more rigid than
      Bebas Neue Rounded.
    '';
    homepage = "https://dharmatype.com/bebas-neue";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
