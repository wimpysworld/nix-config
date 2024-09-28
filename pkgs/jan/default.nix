{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
  writeScript,
}:
let
  version = "0.5.4";
  pname = "jan";
  name = "${pname}-${version}";
  src = fetchurl {
    url = "https://github.com/janhq/jan/releases/download/v${version}/jan-linux-x86_64-${version}.AppImage";
    hash = "sha256-BrNfpf9v8yAs4y3vaPlqtOI9SE7IFfZm/CYegcuZT3c=";
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
    install -m 444 -D ${appimageContents}/${pname}.png \
      $out/share/icons/hicolor/512x512/apps/${pname}.png
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
  '';

  passthru = {
    updateScript = writeScript "update.sh" ''
      #!/usr/bin/env nix-shell
      #!nix-shell -i bash -p curl gnugrep gnused nix-update
      version=$(curl -s https://api.github.com/repos/janhq/jan/releases/latest | grep -oP '"tag_name": "\K(v?)(.*)(?=")' | sed 's/^v//')
      nix-update jan --version "$version"
    '';
  };

  meta = {
    description = "Jan is an open source alternative to ChatGPT that runs 100% offline on your computer";
    homepage = "https://jan.ai/";
    downloadPage = "https://github.com/janhq/jan/releases";
    license = lib.licenses.agpl3Only;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [ "x86_64-linux" ];
  };
}
