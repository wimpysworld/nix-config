{
  fetchzip,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "bw_fusiona";
  version = "1.000";

  src = fetchzip {
    url = "https://ifonts.xyz/core/ifonts-files/downloads/559747/bw-fusiona-font-family.zip";
    hash = "sha256-8FNKeTJTumpkGqj1aIvuXdkODPhWg2D0rF6k137/IOI=";
    stripRoot = false;
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/opentype/${pname} *.otf
  '';

  meta = {
    description = "Bw Fusiona";
    longdescription = ''
      Bw Fusiona brings in a distinct approach to contrast to the familiarity
      of the grotesque shapes. This creates a subtle yet very distinct feel,
      providing brands with a typographic asset for differentiation while
      staying relevant and familiar.
    '';
    homepage = "https://brandingwithtype.com/typefaces/bw-fusiona-collection";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
