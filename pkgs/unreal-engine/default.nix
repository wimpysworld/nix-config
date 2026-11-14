{
  SDL2,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  avahi,
  buildFHSEnv,
  cairo,
  cups,
  dbus,
  dotnet-sdk_8,
  expat,
  fontconfig,
  freetype,
  gdbm,
  gdk-pixbuf,
  glib,
  gtk3,
  icu,
  lib,
  libGL,
  libGLU,
  libdrm,
  libgbm,
  libnotify,
  libpulseaudio,
  liburing,
  libuuid,
  libx11,
  libxcb,
  libxcomposite,
  libxcrypt-legacy,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxshmfence,
  libxtst,
  lttng-ust_2_12,
  lz4,
  makeDesktopItem,
  mesa,
  ncurses5,
  nspr,
  nss,
  openssl,
  pango,
  pipewire,
  sdl3,
  sqlite,
  stdenv,
  symlinkJoin,
  systemd,
  udev,
  util-linux,
  vulkan-loader,
  vulkan-tools,
  wayland,
  writeShellApplication,
  writeShellScript,
  zlib,
  zstd,
}:
let
  pname = "unreal-engine";
  version = "5.8.4";

  unrealFhs = buildFHSEnv {
    pname = "unreal-fhs";
    inherit version;

    targetPkgs = _pkgs: [
      SDL2
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      avahi
      cairo
      cups
      dbus
      dotnet-sdk_8
      expat
      fontconfig
      freetype
      gdbm
      gdk-pixbuf
      glib
      gtk3
      icu
      libGL
      libGLU
      libdrm
      libgbm
      libnotify
      libpulseaudio
      liburing
      libuuid
      libx11
      libxcb
      libxcomposite
      libxcrypt-legacy
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxkbcommon
      libxrandr
      libxrender
      libxscrnsaver
      libxshmfence
      libxtst
      lttng-ust_2_12
      lz4
      mesa
      ncurses5
      nspr
      nss
      openssl
      pango
      pipewire
      sdl3
      sqlite
      stdenv.cc.cc.lib
      systemd
      udev
      util-linux
      vulkan-loader
      vulkan-tools
      wayland
      zlib
      zstd
    ];

    profile = ''
      export UE_ROOT="''${BEEP_UE_ROOT:-''${UE_ROOT:-$HOME/Development/UnrealEngine/UE_5.8}}"
      export BEEP_UE_ROOT="$UE_ROOT"
      export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
      export SDL_VIDEODRIVER="''${SDL_VIDEODRIVER:-x11}"
    '';

    runScript = writeShellScript "unreal-fhs-init" ''
      if [ "$#" -eq 0 ]; then
        exec bash
      else
        exec "$@"
      fi
    '';
  };

  mkUnrealWrapper =
    name: relativePath:
    writeShellApplication {
      inherit name;
      text = ''
        ue_root="''${BEEP_UE_ROOT:-''${UE_ROOT:-''${HOME}/Development/UnrealEngine/UE_5.8}}"
        if [ ! -f "''${ue_root}/Engine/Build/Build.version" ]; then
          printf 'Unreal Engine 5.8 was not found at %s.\n' "''${ue_root}" >&2
          printf 'Extract Linux_Unreal_Engine_5.8.4.zip into %s/Development/UnrealEngine/UE_5.8 or set BEEP_UE_ROOT.\n' "''${HOME}" >&2
          exit 1
        fi
        target="''${ue_root}/${relativePath}"
        if [ ! -e "''${target}" ]; then
          printf 'Unreal Engine tool was not found at %s.\n' "''${target}" >&2
          exit 1
        fi
        export UE_ROOT="''${ue_root}"
        export BEEP_UE_ROOT="''${ue_root}"
        exec "${unrealFhs}/bin/unreal-fhs" "''${target}" "$@"
      '';
    };

  unrealEditor = mkUnrealWrapper "unreal-editor" "Engine/Binaries/Linux/UnrealEditor";
  unrealEditorCmd = mkUnrealWrapper "unreal-editor-cmd" "Engine/Binaries/Linux/UnrealEditor-Cmd";
  unrealBuild = mkUnrealWrapper "unreal-build" "Engine/Build/BatchFiles/Linux/Build.sh";
  unrealUat = mkUnrealWrapper "unreal-uat" "Engine/Build/BatchFiles/RunUAT.sh";
  unrealPython = mkUnrealWrapper "unreal-python" "Engine/Binaries/ThirdParty/Python3/Linux/bin/python3";

  desktopItem = makeDesktopItem {
    name = "UnrealEditor";
    desktopName = "Unreal Editor";
    genericName = "Game Engine";
    comment = "Unreal Engine 5.8 editor";
    exec = "unreal-editor %f";
    icon = "unreal-engine";
    terminal = false;
    type = "Application";
    categories = [
      "Development"
      "IDE"
    ];
    mimeTypes = [ "application/x-uproject" ];
    startupNotify = true;
    startupWMClass = "UnrealEditor";
  };
in
symlinkJoin {
  inherit pname version;

  paths = [
    unrealFhs
    unrealEditor
    unrealEditorCmd
    unrealBuild
    unrealUat
    unrealPython
    desktopItem
  ];

  passthru = {
    fhs = unrealFhs;
  };

  meta = {
    description = "FHS environment and launchers for Unreal Engine 5.8 on Linux";
    homepage = "https://www.unrealengine.com";
    license = lib.licenses.unfree;
    mainProgram = "unreal-editor";
    platforms = [ "x86_64-linux" ];
  };
}
