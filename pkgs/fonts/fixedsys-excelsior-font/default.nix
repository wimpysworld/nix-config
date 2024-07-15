{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "fixedsys_excelsior";
  version = "3.022";

  src = fetchFromGitHub {
    owner = "MARTYR-X-LTD";
    repo = "fixedsys-excelsior";
    rev = "e6be91168935e97b0f07c12a840c8b907ab0d791";
    hash = "sha256-0/zIJppLA9E4Yv6U6JWCMiJ4rnD1OjmPrwb6OiGoo64=";
    sparseCheckout = [ "OTF" ];
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/opentype/${pname} "OTF/Fixedsys Excelsior.otf"
  '';

  meta = {
    description = "Fixedsys Excelsior Font";
    longdescription = ''
      Fixedsys Excelsior is a modified version of the Fixedsys font; a family of
      raster monospaced fonts. The font was originally authored by Darien
      Valentine and provided via a now-defunct site at fixedsysexcelsior.com.
      This derivative adds programming ligatures and fixes rendering and hinting.
    '';
    homepage = "https://github.com/MARTYR-X-LTD/fixedsys-excelsior";
    license = lib.licenses.free;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
