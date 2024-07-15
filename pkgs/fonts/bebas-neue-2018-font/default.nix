{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "bebas_neue_2018";
  version = "2.000";

  src = fetchFromGitHub {
    owner = "dharmatype";
    repo = "Bebas-Neue";
    rev = "46e72cec95ee599f72c0de4a12cfe64828949236";
    hash = "sha256-dKn8qSVRg2jc7xURw/X7XX//V5nV4a0qENVLiwLEcTg=";
    sparseCheckout = [ "fonts/BebasNeue(2018)ByDhamraType/ttf" ];
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/truetype/${pname} fonts/BebasNeue\(2018\)ByDhamraType/ttf/BebasNeue-Regular.ttf
  '';

  meta = {
    description = "Bebas Neue (2018)";
    longdescription = ''
      A display font for headline, caption, and titling.

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
