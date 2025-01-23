{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
  writeScript,
}:
let
  version = "2.1.1";
  pname = "heynote";
  src = fetchurl {
    url = "https://github.com/heyman/heynote/releases/download/v${version}/Heynote_${version}_x86_64.AppImage";
    hash = "sha256-qiNQtCBERmGyJh9bRmOQEfkjYyZmPrAjAJl+839jO3M=";
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
    install -m 444 -D ${appimageContents}/${pname}.desktop \
      $out/share/applications/${pname}.desktop
    install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/0x0/apps/${pname}.png \
      $out/share/icons/hicolor/512x512/apps/${pname}.png
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
  '';

  passthru = {
    updateScript = writeScript "update.sh" ''
      #!/usr/bin/env nix-shell
      #!nix-shell -i bash -p curl gnugrep nix-update
      version=$(curl -s https://api.github.com/repos/heyman/heynote/releases/latest | grep -oP '"tag_name": "\K(v?)(.*)(?=")' | sed 's/^v//')
      nix-update heynote --version "$version"
    '';
  };

  meta = {
    changelog = "https://github.com/heyman/heynote/releases/tag/v${version}";
    description = "A dedicated scratchpad for developers";
    downloadPage = "https://github.com/heyman/heynote/releases";
    homepage = "https://heynote.com/";
    license = lib.licenses.commons-clause;
    mainProgram = "heynote";
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
