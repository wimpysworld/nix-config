{
  fetchzip,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "bw_fusiona";
  version = "1.000";

  src = fetchzip {
    # Use the official demo archive directly. The previous third-party mirror
    # started returning intermittent 403 responses to GitHub Actions runners,
    # which made the builder workflow flaky.
    url = "https://brandingwithtype.com/storage/Bw%20Fusiona%20DEMO-4.zip";
    hash = "sha256-iG63fSKK/O1U88mNMgn1tHB+Zvfk8Z3z4VdOUaj+7qc=";
    stripRoot = false;
  };

  installPhase = ''
    install -d $out/share/fonts/opentype/${pname}
    find . -type f -name '*.otf' -exec install -m444 -t $out/share/fonts/opentype/${pname} {} +
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
