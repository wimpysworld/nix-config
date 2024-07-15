{
  fetchzip,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "mocha_mattari";
  version = "1.000";

  src = fetchzip {
    url = "https://www.dfonts.org/wp-content/uploads/fonts/Mocha_Mattari.zip";
    hash = "sha256-wsP0SKbO71Z0kwHBqOc+CQZ0XHoWjHCtKOqQ1Zs0FeU=";
    stripRoot = false;
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/opentype/${pname} "Mocha_Mattari/Mocha_Mattari/Mocha Mattari.otf"
  '';

  meta = {
    description = "Mocha Mattari Font";
    longdescription = ''
      Mocha Mattari is a distressed font designed based on Bebas Neue released
      as a free font in 2010. Mocha Mattari was made by damaging the original
      and tweaked by handwork. Basically, Mocha Mattari does not have lowercase
      but alternative uppercases.
    '';
    homepage = "https://dharmatype.com/mocha-mattari";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
