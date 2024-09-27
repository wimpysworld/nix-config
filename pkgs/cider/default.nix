{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
  requireFile,
}:
appimageTools.wrapType2 rec {
  pname = "cider";
  version = "2.5.1";

  src = requireFile rec {
    name = "Cider-linux-appimage-x64.AppImage";
    url= "https://cidercollective.itch.io/cider";
    # sha256sum /nix/store/deadb33f-Cider-linux-appimage-x64.AppImage
    sha256 = "1f07c1c98f1abf502f23eb7bc2768d6e10cb5c1c60cd129888b1b584f52da3da";
  };

  extraInstallCommands =
    let appimageContents = appimageTools.extractType2 { inherit pname version src; };
    in ''
      source "${makeWrapper}/nix-support/setup-hook"
      wrapProgram $out/bin/${pname} \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"
      install -m 444 -D ${appimageContents}/${pname}.desktop \
        $out/share/applications/${pname}.desktop
      install -m 444 -D ${appimageContents}/${pname}.png \
        $out/share/icons/hicolor/1024x1024/apps/${pname}.png
      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=${pname}'
    '';

  meta = with lib; {
    description = "Cider is a new cross-platform Apple Music experience";
    homepage = "https://cider.sh/";
    license = licenses.unfree;
    mainProgram = "cider";
    maintainers = [ maintainers.flexiondotorg ];
    platforms = [ "x86_64-linux" ];
  };
}
