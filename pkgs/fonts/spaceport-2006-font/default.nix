{
  fetchzip,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "spaceport_2006";
  version = "1.000";

  src = fetchzip {
    url = "https://dl.dafont.com/dl/?f=${pname}";
    hash = "sha256-TZU5wVPVdg+cvuiOVxmdjJndGyQck/u191uxcawHoS4=";
    extension = "zip";
    stripRoot = false;
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/opentype/${pname} *.otf
  '';

  meta = {
    description = "Spaceport 2006 Font";
    longdescription = ''
      Spaceport 2006 was a low-budget British sci-fi series shot in 1976,
      lasting only a few episodes before being cancelled. This is the font used
      in the series.
    '';
    homepage = "https://www.dafont.com/${pname}.font";
    license = lib.licenses.ofl;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
