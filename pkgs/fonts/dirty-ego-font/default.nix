# https://yildiz.dev/posts/packing-custom-fonts-for-nixos/
# Bad Voltage brand font
{
  fetchzip,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "dirty_ego";
  version = "2001";

  src = fetchzip {
    url = "https://dl.dafont.com/dl/?f=${pname}";
    hash = "sha256-c56OR5yLXl0HK1wWpxJhHpLOkcj17qaEnANtMdf/hfs=";
    extension = "zip";
    stripRoot = false;
  };

  installPhase = ''
    install -m444 -Dt $out/share/fonts/truetype/${pname} *.TTF
  '';

  meta = {
    description = "Dirty Ego Font";
    longdescription = ''
      A fancy, all-caps, distressed font designed by Misprinted Type for headline,
      caption, and titling. It's a bit dirty, but it's got a lot of ego.
    '';
    homepage = "https://www.misprintedtype.com/freeware";
    license = lib.licenses.free;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
