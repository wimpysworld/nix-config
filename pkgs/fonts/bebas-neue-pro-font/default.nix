{
  fetchzip,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "bebas_neue_pro";
  version = "1.100";

  src = fetchzip {
    url = "https://globalfonts.pro/global_files/5dcb09cf6e1d366bf1dd9d85/bebas-neue-pro.zip";
    hash = "sha256-xxQaa4Ck3q2Ly4atybjIeqcoA+mmTlL1DUDIyRPh5sw=";
    stripRoot = false;
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/truetype/${pname} *.ttf
  '';

  meta = {
    description = "Bebas Neue Pro";
    longdescription = ''
      Finally, Bebas Neue has got lowercases and italics. New lowercases are
      designed to carefully match the uppercases. Three widths from Normal to
      Expanded are available for more usability. Almost all European languages
      are supported.
    '';
    homepage = "https://dharmatype.com/bebas-neue-pro";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
