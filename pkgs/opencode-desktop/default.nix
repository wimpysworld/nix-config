{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  addDriverRunpath,
  zstd,

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
  libdrm,
  libglvnd,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  vulkan-loader,
  wayland,
  xorg,

  # Additional runtime dependencies.
  libexif,
  pciutils,
  libcap,

  # Text rendering.
  harfbuzz,
  icu,

  # Media.
  libopus,

  # Tauri-specific dependencies.
  webkitgtk_4_1,
  libsoup_3,
  glib-networking,

  # Desktop integration.
  adwaita-icon-theme,
  gsettings-desktop-schemas,

  # GStreamer for media handling (required for Tauri desktop app)
  gst_all_1,

}:
let
  version = "1.1.1";
  pname = "opencode-desktop";

  # Fetch the actual OpenCode CLI from the tarball release
  # The bundled opencode-cli in the .deb is actually bun, not the real CLI
  # See: https://github.com/anomalyco/opencode/issues/6168
  opencode-cli-tarball = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64.tar.gz";
    hash = "sha256-w4IAXJfkRwWWMmZ1tda6W7lWXGGGZunuRAJsFjNhx70=";
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/${pname}-linux-amd64.deb";
    hash = "sha256-zD8kZoO47840rkI/S650RBBt0GniFXGXr2aXlr59LhY=";
  };

  nativeBuildInputs = [
    makeWrapper
    autoPatchelfHook
    addDriverRunpath
    zstd
  ];

  # The tarball containing the actual opencode CLI binary
  inherit opencode-cli-tarball;

  buildInputs = [
    # Desktop integration
    adwaita-icon-theme
    gsettings-desktop-schemas

    # Core libraries
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gcc-unwrapped.lib
    gdk-pixbuf
    glib
    glib-networking
    gtk3
    harfbuzz
    icu
    libcap
    libdrm
    libexif
    libglvnd
    libopus
    libsoup_3
    libxkbcommon
    mesa
    nspr
    nss
    pango
    pciutils
    vulkan-loader
    wayland

    # Tauri WebView engine
    webkitgtk_4_1

    # GStreamer for media (required for Tauri WebKitGTK)
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-libav
    gst_all_1.gst-plugins-ugly

    # X11 libraries
    xorg.libX11
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
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
    mkdir -p $out/{bin,share/{applications,icons/hicolor}}

    # Copy binaries (OpenCode is the main binary)
    cp usr/bin/OpenCode $out/bin/

    # Install desktop integration
    cp -r usr/share/applications/* $out/share/applications/

    # Install icons (preserving hicolor structure)
    cp -r usr/share/icons/hicolor/* $out/share/icons/hicolor/

    runHook postInstall
  '';

  postInstall = ''
    # Add driver paths for GPU acceleration
    addDriverRunpath $out/bin/OpenCode
  '';

  postFixup = ''
    # Create library path for OpenGL/Vulkan support
    libPath="${
      lib.makeLibraryPath [
        libglvnd
        mesa
      ]
    }"

    # XDG data directories for GTK, icons, and GStreamer
    xdgDataPath="${adwaita-icon-theme}/share:${gsettings-desktop-schemas}/share"

    # GStreamer plugin path - include all plugin directories
    gstPluginPath="${gst_all_1.gst-plugins-base}/lib/gstreamer-1.0:${gst_all_1.gst-plugins-good}/lib/gstreamer-1.0:${gst_all_1.gst-plugins-bad}/lib/gstreamer-1.0:${gst_all_1.gst-libav}/lib/gstreamer-1.0:${gst_all_1.gst-plugins-ugly}/lib/gstreamer-1.0"

    # Extract and install the actual OpenCode CLI from the tarball
    # The bundled opencode-cli in the .deb is actually bun, not the real CLI
    # This fixes the "Script not found 'serve'" error
    # See: https://github.com/anomalyco/opencode/issues/6168#issuecomment-3705997000
    tar -xzf ${opencode-cli-tarball} -C $TMPDIR
    cp $TMPDIR/opencode $out/bin/opencode-cli
    chmod +x $out/bin/opencode-cli

    # Wrap the CLI binary with necessary environment
    wrapProgram $out/bin/opencode-cli \
      --prefix LD_LIBRARY_PATH : "$libPath"

    # Wrap the main application (binary is named OpenCode)
    wrapProgram $out/bin/OpenCode \
      --prefix LD_LIBRARY_PATH : "$libPath" \
      --prefix XDG_DATA_DIRS : "$xdgDataPath" \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "$gstPluginPath" \
      --set LIBGL_DRIVERS_PATH "${mesa}/lib/dri" \
      --set __EGL_VENDOR_LIBRARY_DIRS "${mesa}/share/glvnd/egl_vendor.d" \
      --set VK_LAYER_PATH "${vulkan-loader}/share/vulkan/explicit_layer.d" \
      --set WEBKIT_DISABLE_DMABUF_RENDERER "1" \
      --set WEBKIT_DISABLE_GPU_THREAD "1" \
      --set LIBGL_DRI3_DISABLE "1" \
      --set OC_ALLOW_WAYLAND "1"

    # Create a convenience symlink with lowercase name
    ln -s $out/bin/OpenCode $out/bin/opencode-desktop

    # Note: Removed Ozone flags as Tauri uses GTK/WebKitGTK, not Chromium
    # Tauri handles Wayland automatically through GTK
  '';

  meta = {
    description = "OpenCode Desktop - The open source AI coding agent";
    downloadPage = "https://opencode.ai/download";
    homepage = "https://opencode.ai/";
    license = lib.licenses.asl20;
    mainProgram = "opencode-desktop";
    maintainers = with lib.maintainers; [ flexiondotorg ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
