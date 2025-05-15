{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
}:
let
  version = "3.0.2";
  pname = "Cider";
  src = fetchurl {
    url = "https://warez.wimpys.world/cider-v${version}-linux-x64.AppImage";
    hash = "sha256-XVBhMgSNJAYTRpx5GGroteeOx0APIzuHCbf+kINT2eU=";
  };
  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;
  # Disable UseMultiPlaneFormatForSoftwareVideo on Wayland
  # https://github.com/Legcord/Legcord/issues/741
  # Disable GPU memory buffer for video frames
  # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1077345#10
  extraInstallCommands = ''
    source "${makeWrapper}/nix-support/setup-hook"
      wrapProgram $out/bin/Cider \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --disable-features=UseMultiPlaneFormatForSoftwareVideo --disable-gpu-memory-buffer-video-frames}}"
      install -m 444 -D ${appimageContents}/Cider.desktop \
        $out/share/applications/Cider.desktop
      install -m 444 -D ${appimageContents}/cider.png \
        $out/share/icons/hicolor/256x256/apps/cider.png
  '';

  meta = {
    description = "Cider is a new cross-platform Apple Music experience";
    downloadPage = "https://taproom.cider.sh/downloads";
    homepage = "https://cider.sh/";
    license = lib.licenses.unfree;
    mainProgram = "Cider";
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
