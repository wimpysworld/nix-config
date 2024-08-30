{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation rec {
  pname = "fixedsys_core";
  version = "0.6";

  src = lib.cleanSource ./fonts;

  installPhase = ''
    install -m444 -Dt $out/share/fonts/truetype/${pname} *ttf
  '';

  meta = {
    description = "Fixedsys Core Font";
    longdescription = ''
      Fixedsys Core is a love letter to the Fixedsys Excelsior font, an attempt
      to reinvent the feel and look of a truly unique font for modern
      high-resolution displays.

      This version is patched to include Nerd Font and Braille glyphs.
    '';
    homepage = "https://github.com/delinx/Fixedsys-Core";
    license = lib.licenses.free;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
