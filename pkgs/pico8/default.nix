{
  autoPatchelfHook,
  copyDesktopItems,
  lib,
  makeDesktopItem,
  requireFile,
  stdenv,
  SDL2,
  unzip,
}:
stdenv.mkDerivation rec {
  pname = "pico8";
  version = "0.2.7";
  src = requireFile rec {
    name = "pico-8_${version}_amd64.zip";
    url = "https://www.lexaloffle.com/pico-8.php";
    sha256 = "edf2ce854740585b0f98884ee09d63f9ab8e6c8772e0148a902927b6408c9eaa";
  };

  unpackCmd = ''${unzip}/bin/unzip "$src"'';

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
  ];
  buildInputs = [
    SDL2
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share
    # The pico8_dyn is dynamically linked and requires the SDL2 library.
    install -m 755 -D pico8_dyn $out/bin/pico8
    install -m 444 -D pico8.dat $out/bin/pico8.dat
    install -m 444 -D lexaloffle-pico8.png \
        $out/share/icons/hicolor/128x128/apps/pico8.png
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem rec {
      name = "pico-8";
      desktopName = "PICO-8";
      keywords = [
        "Game"
        "Retro"
        "Development"
      ];
      exec = "pico8";
      terminal = false;
      type = "Application";
      icon = "pico8";
      categories = [
        "Development"
        "IDE"
        "Game"
      ];
      startupNotify = true;
      actions = {
        "Windowed" = {
          name = "Open windowed";
          exec = "pico8 -windowed 1";
        };
      };
    })
  ];

  meta = {
    description = "PICO-8 is a fantasy console for making, sharing and playing tiny games and other computer programs.";
    homepage = "https://www.lexaloffle.com/pico-8.php";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "pico8";
  };
}
