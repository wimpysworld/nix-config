{
  fetchzip,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "poppins";
  version = "4.003";

  src = fetchzip {
    url = "https://github.com/itfoundry/Poppins/raw/master/products/Poppins-${version}-GoogleFonts-TTF.zip";
    hash = "sha256-7rzn20dUlrOUQCm+nXneWGIU+N+Gfy0FvqZw+b4uoVI=";
    stripRoot = false;
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/truetype/${pname} *.ttf
  '';

  meta = {
    description = "Poppins Font";
    longdescription = "Poppins, a Devanagari + Latin family for Google Fonts.";
    homepage = "https://github.com/itfoundry/Poppins";
    license = lib.licenses.ofl;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
