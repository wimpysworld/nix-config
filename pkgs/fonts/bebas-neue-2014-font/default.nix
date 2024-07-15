{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "bebas_neue_2014";
  version = "1.003";

  src = fetchFromGitHub {
    owner = "dharmatype";
    repo = "Bebas-Neue";
    rev = "46e72cec95ee599f72c0de4a12cfe64828949236";
    hash = "sha256-ADPZSBRobd1gNnWvablm2B16p6hEIzYCwK4itYEqog4=";
    sparseCheckout = [ "fonts/BebasNeue(2014)ByFontFabric" ];
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/opentype/${pname} fonts/BebasNeue\(2014\)ByFontFabric/*.otf
  '';

  meta = {
    description = "Bebas Neue Family (2014)";
    longdescription = ''
      Bebas Neue Font Family is a sans-serif font family based on the original
      free Bebas Neue Font by Ryoichi Tsunekawa; a display font for
      headline, caption, and titling that is uniformly proper for web, print,
      commerce, and art. The Bebas Neue Font Family is among display
      fonts that support Extended Latin (English) & Cyrillic.

      "Bebas Neue Family(2014)" vs "Bebas Neue (2018)"

      - "Bebas Neue Family (2014)" is based on the "Bebas Neue version 1.xxx (2010)"
        created by Fontfabric. Styles: Bold, Book, Light, Regular, Thin.

      - "Bebas Neue (2018)" is a newer version of "Bebas Neue version 1.xxx (2010)".
        Some glyphs were newly added, some glyphs were improved, some spacing and
        kernings were regulated. Styles: Regular.

      Be careful when using these fonts together. Some parts of the design,
      character set, style name and setting between "Bebas Neue Family(2014)" and
      "Bebas Neue (2018)" are slightly different. They have same family name, but
      they are not the same fonts.
    '';
    homepage = "https://bebasneue.com/";
    license = lib.licenses.ofl;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
