{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
}:
let
  version = "1.8.0";
  pname = "heynote";
  name = "${pname}-${version}";
  src = fetchurl {
    url = "https://github.com/heyman/heynote/releases/download/v${version}/Heynote_${version}_x86_64.AppImage";
    hash = "sha256-NzrXV8HmCPYE+D3tEwVv3rBkLF0/FKW6uJdqhKmH8uw=";
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
    install -m 444 -D ${appimageContents}/heynote.desktop \
      $out/share/applications/heynote.desktop
    install -m 444 -D ${appimageContents}/heynote.png \
      $out/share/icons/hicolor/512x512/apps/heynote.png
    substituteInPlace $out/share/applications/heynote.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
  '';
  meta = {
    description = "A dedicated scratchpad for developers";
    homepage = "https://heynote.com/";
    downloadPage = "https://github.com/heyman/heynote/releases";
    license = lib.licenses.commons-clause;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [ "x86_64-linux" ];
  };
}
