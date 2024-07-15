{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "fixedsys_core";
  version = "0.6";

  src = fetchFromGitHub {
    owner = "delinx";
    repo = "Fixedsys-Core";
    rev = "01399b8d1e85c74bb8eb97de442fa51c17e39add";
    hash = "sha256-9vP0pRFOgquEZS8TjiHfPmYUX/fcoOtgdCKZlptSY9o=";
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/truetype/${pname} "FixedsysCore-Regular.ttf"
  '';

  meta = {
    description = "Fixedsys Core Font";
    longdescription = ''
      Fixedsys Core is a love letter to the Fixedsys Excelsior font, an attempt
      to reinvent the feel and look of a truly unique font for modern
      high-resolution displays.
    '';
    homepage = "https://github.com/delinx/Fixedsys-Core";
    license = lib.licenses.free;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
