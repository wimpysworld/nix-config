{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
  requireFile,
}:
let
  version = "2.6.0";
  pname = "cider";
  src = requireFile rec {
    name = "cider-linux-x64.AppImage";
    url= "https://cidercollective.itch.io/cider";
    # sha256sum /nix/store/deadb33f-cider-linux-x64.AppImage
    sha256 = "ca16d4deeddc59c7be6b55c0d671d2f8590d3576c29c3afb0c1da8ba54fd7776";
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
      wrapProgram $out/bin/${pname} \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --disable-features=UseMultiPlaneFormatForSoftwareVideo --disable-gpu-memory-buffer-video-frames}}"
      install -m 444 -D ${appimageContents}/Cider.desktop \
        $out/share/applications/Cider.desktop
      install -m 444 -D ${appimageContents}/cider.png \
        $out/share/icons/hicolor/256x256/apps/cider.png
  '';

  meta = {
    description = "Cider is a new cross-platform Apple Music experience";
    downloadPage = "https://cidercollective.itch.io/cider";
    homepage = "https://cider.sh/";
    license = lib.licenses.unfree;
    mainProgram = "cider";
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
