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
    sha256 = "05b4ba6e938327242ed35376da3e2d899f2a31d9cd33018b96d6c51689397ea1";
  };
  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;
  extraInstallCommands = ''
    source "${makeWrapper}/nix-support/setup-hook"
      wrapProgram $out/bin/${pname} \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"
      install -m 444 -D ${appimageContents}/Cider.desktop \
        $out/share/applications/Cider.desktop
      install -m 444 -D ${appimageContents}/cider-linux----arch-------version---.png \
        $out/share/icons/hicolor/256x256/apps/cider-genten-client.png
      substituteInPlace $out/share/applications/Cider.desktop \
        --replace-fail 'Exec=Cider' 'Exec=cider'
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
