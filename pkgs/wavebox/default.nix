{
  fetchurl,
  lib,
  makeWrapper,
  patchelf,
  stdenv,
  stdenvNoCC,
  writeScript,

  # Linked dynamic libraries.
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gcc-unwrapped,
  gdk-pixbuf,
  glib,
  gtk3,
  gtk4,
  libdrm,
  libglvnd,
  libkrb5,
  libX11,
  libxcb,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libxkbcommon,
  libXrandr,
  libXrender,
  libXScrnSaver,
  libxshmfence,
  libXtst,
  libgbm,
  nspr,
  nss,
  pango,
  pipewire,
  vulkan-loader,
  wayland, # ozone/wayland

  # Command line programs
  coreutils,

  # command line arguments which are always set e.g "--disable-gpu"
  commandLineArgs ? "",

  # Will crash without.
  systemd,

  # Loaded at runtime.
  libexif,
  pciutils,

  # Additional dependencies according to other distros.
  ## Ubuntu
  curl,
  liberation_ttf,
  util-linux,
  wget,
  xdg-utils,
  ## Arch Linux.
  flac,
  harfbuzz,
  icu,
  libopus,
  libpng,
  snappy,
  speechd-minimal,
  ## Gentoo
  bzip2,
  libcap,

  # Necessary for USB audio devices.
  libpulseaudio,
  pulseSupport ? true,

  adwaita-icon-theme,
  gsettings-desktop-schemas,

  # For video acceleration via VA-API (--enable-features=VaapiVideoDecoder)
  libva,
  libvaSupport ? true,

  # For Vulkan support (--enable-features=Vulkan)
  addDriverRunpath,
  undmg,

  # For QT support
  qt6,
}:

let
  pname = "wavebox";

  opusWithCustomModes = libopus.override { withCustomModes = true; };

  deps =
    [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      bzip2
      cairo
      coreutils
      cups
      curl
      dbus
      expat
      flac
      fontconfig
      freetype
      gcc-unwrapped.lib
      gdk-pixbuf
      glib
      harfbuzz
      icu
      libcap
      libdrm
      liberation_ttf
      libexif
      libglvnd
      libkrb5
      libpng
      libX11
      libxcb
      libXcomposite
      libXcursor
      libXdamage
      libXext
      libXfixes
      libXi
      libxkbcommon
      libXrandr
      libXrender
      libXScrnSaver
      libxshmfence
      libXtst
      libgbm
      nspr
      nss
      opusWithCustomModes
      pango
      pciutils
      pipewire
      snappy
      speechd-minimal
      systemd
      util-linux
      vulkan-loader
      wayland
      wget
    ]
    ++ lib.optional pulseSupport libpulseaudio
    ++ lib.optional libvaSupport libva
    ++ [
      gtk3
      gtk4
      qt6.qtbase
      qt6.qtwayland
    ];

  linux = stdenv.mkDerivation (finalAttrs: {
    inherit pname meta passthru;
    version = "10.137.12-2";

    src = fetchurl {
      url = "https://download.wavebox.app/stable/linux/deb/amd64/wavebox_${finalAttrs.version}_amd64.deb";
      hash = "sha256-hijSbNmiO+veUcal/50WopbSnNpDkHO0gxCPjrB0Kas=";
    };

    # With strictDeps on, some shebangs were not being patched correctly
    # ie, $out/share/wavebox.io/wavebox/wavebox-launcher
    strictDeps = false;

    nativeBuildInputs = [
      makeWrapper
      patchelf
    ];

    buildInputs = [
      # needed for XDG_ICON_DIRS
      adwaita-icon-theme
      glib
      gtk3
      gtk4
      # needed for GSETTINGS_SCHEMAS_PATH
      gsettings-desktop-schemas
    ];

    unpackPhase = ''
      runHook preUnpack
      ar x $src
      tar xf data.tar.xz
      runHook postUnpack
    '';

    rpath = lib.makeLibraryPath deps + ":" + lib.makeSearchPathOutput "lib" "lib64" deps;
    binpath = lib.makeBinPath deps;

    installPhase = ''
      runHook preInstall

      exe=$out/bin/wavebox

      mkdir -p $out/bin $out/share
      cp -v -a opt/* $out/share
      cp -v -a usr/share/* $out/share

      # replace bundled vulkan-loader
      rm -v $out/share/wavebox.io/wavebox/libvulkan.so.1
      ln -v -s -t "$out/share/wavebox.io/wavebox" "${lib.getLib vulkan-loader}/lib/libvulkan.so.1"

      substituteInPlace $out/share/wavebox.io/wavebox/wavebox-launcher \
        --replace-fail 'CHROME_WRAPPER' 'WRAPPER'
      substituteInPlace $out/share/applications/wavebox.desktop \
        --replace-fail /opt/wavebox.io/wavebox/wavebox-launcher $exe
      substituteInPlace $out/share/menu/wavebox.menu \
        --replace-fail /opt $out/share \
        --replace-fail $out/share/wavebox.io/wavebox/wavebox $exe

      for icon_file in $out/share/wavebox.io/wavebox/product_logo_[0-9]*.png; do
        num_and_suffix="''${icon_file##*logo_}"
        icon_size="''${num_and_suffix%.*}"
        logo_output_prefix="$out/share/icons/hicolor"
        logo_output_path="$logo_output_prefix/''${icon_size}x''${icon_size}/apps"
        mkdir -p "$logo_output_path"
        mv "$icon_file" "$logo_output_path/wavebox.png"
      done

      makeWrapper "$out/share/wavebox.io/wavebox/wavebox" "$exe" \
        --prefix QT_PLUGIN_PATH  : "${qt6.qtbase}/lib/qt-6/plugins" \
        --prefix QT_PLUGIN_PATH  : "${qt6.qtwayland}/lib/qt-6/plugins" \
        --prefix NIXPKGS_QT6_QML_IMPORT_PATH : "${qt6.qtwayland}/lib/qt-6/qml" \
        --prefix LD_LIBRARY_PATH : "$rpath" \
        --prefix PATH            : "${lib.makeBinPath deps}" \
        --suffix PATH            : "${lib.makeBinPath [ xdg-utils ]}" \
        --prefix XDG_DATA_DIRS   : "$XDG_ICON_DIRS:$GSETTINGS_SCHEMAS_PATH:${addDriverRunpath.driverLink}/share" \
        --set CHROME_WRAPPER "wavebox" \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
        --add-flags ${lib.escapeShellArg commandLineArgs}

      # Make sure that libGL and libvulkan are found by ANGLE libGLESv2.so
      patchelf --set-rpath $rpath $out/share/wavebox.io/wavebox/lib*GL*

      for elf in $out/share/wavebox.io/wavebox/{wavebox,chrome-sandbox,chrome_crashpad_handler}; do
        patchelf --set-rpath $rpath $elf
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $elf
      done

      runHook postInstall
    '';
  });

  darwin = stdenvNoCC.mkDerivation (finalAttrs: {
    inherit pname meta passthru;
    version = "10.137.12.2";

    src = fetchurl {
      url = "https://download.wavebox.app/stable/macuniversal/Install%20Wavebox%20${finalAttrs.version}.dmg";
      hash = "sha256-PclTKITgJfSAdo7uc69jFZ5Ls35Yv4LXjG0jEC0oepE=";
    };

    dontPatch = true;
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    nativeBuildInputs = [
      makeWrapper
      undmg
    ];

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p $out/Applications
      cp -r *.app $out/Applications

      mkdir -p $out/bin

      makeWrapper $out/Applications/Wavebox.app/Contents/MacOS/Wavebox $out/bin/wavebox \
        --add-flags ${lib.escapeShellArg commandLineArgs}
      runHook postInstall
    '';
  });

  passthru = {
    updateScript = writeScript "update-wavebox.sh" ''
      #!/usr/bin/env nix-shell
      #!nix-shell -i bash -p curl gawk gnused jq

      set -euo pipefail

      DEFAULT_NIX="$(realpath "./pkgs/by-name/wa/wavebox/package.nix")"

      linux_json="https://download.wavebox.app/stable/linux/latest.json"
      darwin_json="https://download.wavebox.app/stable/macuniversal/latest.json"

      current_version="$(awk "/stdenv.mkDerivation/,/});/ { if (\$0 ~ /version = \"/) { match(\$0, /version = \"([^\"]+)\"/, arr); print arr[1]; exit } }" "$DEFAULT_NIX")"
      linux_version=$(curl -fsSL "$linux_json" | jq --raw-output '.["urls"]["deb"] | match("https://download.wavebox.app/stable/linux/deb/amd64/wavebox_(.+)_amd64.deb").captures[0]["string"]')
      darwin_version=$(curl -fsSL "$darwin_json" | jq --raw-output '.["url"] | match("https://download.wavebox.app/stable/macuniversal/Install%20Wavebox%20(.+).dmg").captures[0]["string"]')

      # All architectures are released together, therefore we check the latest Linux version
      if [[ "$current_version" = "$linux_version" ]]; then
        echo "[Nix] Linux wavebox: same version"
        exit 0
      fi

      linux_deb=$(curl -fsSL "$linux_json" | jq --raw-output '.["urls"]["deb"]')
      linux_hash=$(nix-hash --sri --type sha256 "$(nix-prefetch-url --print-path --unpack "$linux_deb" | tail -n1)")
      sed -i "/^  linux = stdenv.mkDerivation/,/^  });/s/version = \".*\"/version = \"$linux_version\"/" "$DEFAULT_NIX"
      sed -i "/^  linux = stdenv.mkDerivation/,/^  });/s|hash = \".*\"|hash = \"$linux_hash\"|" "$DEFAULT_NIX"

      darwin_dmg=$(curl -fsSL "$darwin_json" | jq --raw-output '.["url"]')
      darwin_hash=$(nix-hash --sri --type sha256 "$(nix-prefetch-url --print-path --unpack "$darwin_dmg" | tail -n1)")
      sed -i "/^  darwin = stdenvNoCC.mkDerivation/,/^  });/s/version = \".*\"/version = \"$darwin_version\"/" "$DEFAULT_NIX"
      sed -i "/^  darwin = stdenvNoCC.mkDerivation/,/^  });/s|hash = \".*\"|hash = \"$dawin_version\"|" "$DEFAULT_NIX"
    '';
  };

  meta = {
    changelog = "https://wavebox.io/blog/releases/";
    description = "Wavebox Productivity Browser";
    homepage = "https://wavebox.io";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = lib.platforms.darwin ++ [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "wavebox";
  };
in
if stdenvNoCC.hostPlatform.isDarwin then darwin else linux
