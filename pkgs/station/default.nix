{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
  writeScript,
}:
let
  version = "3.3.0";
  pname = "station";
  src = fetchurl {
    url = "https://github.com/getstation/desktop-app/releases/download/v${version}/Station-x86_64.AppImage";
    hash = "sha256-OiUVRKpU2W1dJ6z9Dqvxd+W4/oNpG+Zolj43ZHpKaO0=";
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
    install -m 444 -D ${appimageContents}/station-desktop-app.desktop \
      $out/share/applications/station-desktop-app.desktop
    install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/512x512/apps/station-desktop-app.png \
      $out/share/icons/hicolor/512x512/apps/station-desktop-app.png
    substituteInPlace $out/share/applications/station-desktop-app.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=station'
  '';

  passthru = {
    updateScript = writeScript "update.sh" ''
      #!/usr/bin/env nix-shell
      #!nix-shell -i bash -p curl gnugrep gnused nix-update
      version=$(curl -s https://api.github.com/repos/getstation/desktop-app/releases/latest | grep -oP '"tag_name": "\K(v?)(.*)(?=")' | sed 's/^v//')
      nix-update station --version "$version"
    '';
  };

  meta = {
    changelog = "https://github.com/getstation/desktop-app/releases/tag/v${version}";
    description = "Open-source smart browser for busy people. A single place for all of your web applications.";
    downloadPage = "https://github.com/getstation/desktop-app/releases";
    homepage = "https://getstation.com/";
    license = lib.licenses.asl20;
    mainProgram = "station";
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
