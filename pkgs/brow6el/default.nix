# Brow6el is a terminal web browser rendering pages with Sixel or Kitty
# graphics. It links against a prebuilt Chromium Embedded Framework (CEF)
# binary distribution, fetched here exactly as upstream's download_cef.sh does.
{
  lib,
  stdenv,
  fetchgit,
  fetchurl,
  cmake,
  pkg-config,
  makeWrapper,
  autoPatchelfHook,

  # Libraries linked by brow6el itself.
  libsixel,
  zlib,

  # Libraries required by the prebuilt libcef.so.
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  libgbm,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libxcb,
  libxkbcommon,
  nspr,
  nss,
  pango,
  systemd,
}:
let
  # Pinned CEF binary distribution, matching upstream's download_cef.sh.
  cefVersion = "148.0.7+g5b12d32+chromium-148.0.7778.96";
  cefPlatform =
    {
      x86_64-linux = "linux64";
      aarch64-linux = "linuxarm64";
    }
    .${stdenv.hostPlatform.system}
      or (throw "brow6el: unsupported system ${stdenv.hostPlatform.system}");
  cefHash =
    {
      x86_64-linux = "sha256-UMkXLcjQ/4yqrvYoJtn2YWihPrpHmKbOP6XOE6VGYYE=";
      aarch64-linux = "sha256-bZRoawMcSNwHX3kJKZv9/noIxUjPyQzeBIsobYibUgc=";
    }
    .${stdenv.hostPlatform.system};
  cefSrc = fetchurl {
    url = "https://cef-builds.spotifycdn.com/cef_binary_${cefVersion}_${cefPlatform}_beta_minimal.tar.bz2";
    hash = cefHash;
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "brow6el";
  version = "0-unstable-2026-07-23";

  src = fetchgit {
    url = "https://tangled.org/janantos.tngl.sh/brow6el";
    rev = "ec0bc3fad3ef1d67e290dddfa82c54862486f84d";
    hash = "sha256-XBmRqQUILhpCz0oFL6y03lrlCRgTn0nL8K57QBHPvDo=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    cmake
    makeWrapper
    pkg-config
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    libgbm
    libsixel
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libxcb
    libxkbcommon
    nspr
    nss
    pango
    (lib.getLib systemd)
    zlib
  ];

  # The prebuilt libcef.so carries DT_NEEDED entries the linker cannot resolve
  # against scattered store paths; autoPatchelfHook verifies them at fixup.
  env.NIX_LDFLAGS = "--allow-shlib-undefined";

  postPatch = ''
    # Git metadata is absent in the sandbox; pin the fallback version string.
    substituteInPlace CMakeLists.txt \
      --replace-fail '0.0.999-dev' "${finalAttrs.version}"
  '';

  # Unpack the CEF distribution and build its static wrapper library where
  # the project's CMakeLists.txt expects to find them.
  preConfigure = ''
    tar xjf ${cefSrc}
    ln -s cef_binary_${cefVersion}_${cefPlatform}_beta_minimal cef_binary
    cmake -S cef_binary -B cef_binary/build -DCMAKE_BUILD_TYPE=Release
    cmake --build cef_binary/build --target libcef_dll_wrapper -j "$NIX_BUILD_CORES"
  '';

  # There is no upstream install target; mirror the layout of the build
  # directory that upstream's run_brow6el.sh launches from. The setuid
  # chrome-sandbox helper is deliberately omitted so CEF falls back to the
  # user-namespace sandbox.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/lib/brow6el"
    cp -r \
      brow6el \
      libcef.so libEGL.so libGLESv2.so libvk_swiftshader.so libvulkan.so.1 \
      vk_swiftshader_icd.json v8_context_snapshot.bin icudtl.dat \
      chrome_100_percent.pak chrome_200_percent.pak resources.pak locales \
      hint_mode.js inspect_mode.js mouse_emu.js select_detector.js visual_mode.js \
      tutorial.html scripts \
      "$out/lib/brow6el/"
    makeWrapper "$out/lib/brow6el/brow6el" "$out/bin/brow6el" \
      --set-default VK_ICD_FILENAMES "$out/lib/brow6el/vk_swiftshader_icd.json"
    runHook postInstall
  '';

  meta = {
    description = "Terminal web browser with Sixel and Kitty graphics support, built on CEF";
    homepage = "https://tangled.org/janantos.tngl.sh/brow6el";
    # Upstream publishes no licence for its own sources; only the bundled CEF
    # (BSD-3-Clause) and libsixel (MIT) dependencies are licensed.
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
    mainProgram = "brow6el";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
