{
  lib,
  appimageTools,
  makeWrapper,
  requireFile,
}:
let
  version = "2.6.1";
  pname = "Cider";
  src = requireFile rec {
    name = "cider-linux-x64.AppImage";
    url= "https://cidercollective.itch.io/cider";
    # nix-store --add-fixed sha256 pkgs/cider/cider-linux-x64.AppImage
    # sha256sum /nix/store/deadb33f-cider-linux-x64.AppImage
    sha256 = "6ee1ee9d4b45419d7860d1e7831dc7c2a9b94689f013a0bf483876c6b4d65062";
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
    downloadPage = "https://cidercollective.itch.io/cider";
    homepage = "https://cider.sh/";
    license = lib.licenses.unfree;
    mainProgram = "Cider";
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
