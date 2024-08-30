{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation rec {
  pname = "fixedsys_excelsior";
  version = "3.022";

  src = lib.cleanSource ./fonts;

  installPhase = ''
    install -m444 -Dt $out/share/fonts/truetype/${pname} *ttf
  '';

  meta = {
    description = "Fixedsys Excelsior Font";
    longdescription = ''
      Fixedsys Excelsior is a modified version of the Fixedsys font; a family of
      raster monospaced fonts. The font was originally authored by Darien
      Valentine and provided via a now-defunct site at fixedsysexcelsior.com.
      This derivative adds programming ligatures and fixes rendering and hinting.

      This version is patched to include Nerd Font and Braille glyphs.
    '';
    homepage = "https://github.com/MARTYR-X-LTD/fixedsys-excelsior";
    license = lib.licenses.free;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
