{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  addDriverRunpath,
  autoPatchelfHook,
  wrapGAppsHook,
  alsa-lib,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libglvnd,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  vulkan-loader,
  xorg,
}:
let
  version = "3.1.2";
  pname = "cider";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://warez.wimpys.world/cider-v${version}-linux-x64.deb";
    hash = "sha256-iD4ZJ4hZLIZH6d2rPgD04kydLLgeWXMp6UQ372APgo0=";
  };

  nativeBuildInputs = [
    makeWrapper
    autoPatchelfHook
    wrapGAppsHook
    addDriverRunpath
  ];

  buildInputs = [
    alsa-lib
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libglvnd
    libxkbcommon
    mesa
    nspr
    nss
    pango
    vulkan-loader
    xorg.libX11
    xorg.libXext
    xorg.libxcb
  ];

  unpackPhase = ''
    runHook preUnpack
    ar x $src
    tar --no-same-permissions --no-same-owner -xf data.tar.*
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # Create directory structure
    mkdir -p $out/{bin,lib,share/{applications,icons/hicolor/256x256/apps}}

    # Copy the application files
    cp -r usr/lib/cider $out/lib/
    ln -s $out/lib/cider/Cider $out/bin/cider

    # Install desktop integration
    cp usr/share/applications/cider.desktop $out/share/applications/
    cp usr/share/pixmaps/cider.png $out/share/icons/hicolor/256x256/apps/

    runHook postInstall
  '';

  # Enhanced GPU acceleration and driver path setup
  postInstall = ''
    # Add driver paths to the binary for GPU acceleration
    addDriverRunpath $out/lib/cider/Cider
  '';

  postFixup = ''
    # Create comprehensive library path for OpenGL/Vulkan support
    libPath="${
      lib.makeLibraryPath [
        libglvnd
      ]
    }"

    # Enhanced wrapper with proper OpenGL environment
    wrapProgram $out/lib/cider/Cider \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
      --set LD_LIBRARY_PATH "$libPath" \
      --set LIBGL_DRIVERS_PATH "${mesa}/lib/dri" \
      --set __EGL_VENDOR_LIBRARY_DIRS "${mesa}/share/glvnd/egl_vendor.d" \
      --set VK_LAYER_PATH "${vulkan-loader}/share/vulkan/explicit_layer.d"
  '';

  meta = {
    description = "Cider is a new cross-platform Apple Music experience";
    downloadPage = "https://taproom.cider.sh/downloads";
    homepage = "https://cider.sh/";
    license = lib.licenses.unfree;
    mainProgram = "cider";
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
