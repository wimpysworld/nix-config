{ lib
, stdenv
, fetchurl
, cmake
, glib
, nss
, nspr
, atk
, at-spi2-atk
, libdrm
, expat
, libxcb
, libxkbcommon
, libX11
, libXcomposite
, libXdamage
, libXext
, libXfixes
, libXrandr
, mesa
, gtk3
, pango
, cairo
, alsa-lib
, dbus
, at-spi2-core
, cups
, libxshmfence
, obs-studio
}:

let
  gl_rpath = lib.makeLibraryPath [
    stdenv.cc.cc.lib
  ];

  rpath = lib.makeLibraryPath [
    glib
    nss
    nspr
    atk
    at-spi2-atk
    libdrm
    expat
    libxcb
    libxkbcommon
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    mesa
    gtk3
    pango
    cairo
    alsa-lib
    dbus
    at-spi2-core
    cups
    libxshmfence
  ];
  cef_name = "cef_binary";
  cef_version = "5060";
  cef_rev = "v3";
in
stdenv.mkDerivation rec {
  pname = cef_name;
  version = cef_version;

  src = fetchurl {
    url = "https://cdn-fastly.obsproject.com/downloads/${pname}_${version}_linux_x86_64_${cef_rev}.tar.xz";
    sha256 = "sha256-ElOmo2w7isW17Om/226uardeSVFjdfxHXi6HF5Wtm+o=";
  };

  nativeBuildInputs = [ cmake ];
  cmakeFlags = [ "-DPROJECT_ARCH=x86_64" ];
  makeFlags = [ "libcef_dll_wrapper" ];
  dontStrip = true;
  dontPatchELF = true;

  # Delete the bundled CMakeCache.txt
  postUnpack = ''
    rm -v ${cef_name}_${cef_version}_linux_x86_64/build/CMakeCache.txt
  '';

  installPhase = ''
    mkdir -p $out/lib/ $out/share/cef/
    cp libcef_dll_wrapper/libcef_dll_wrapper.a $out/lib/
    cp ../Release/libcef.so $out/lib/
    cp ../Release/libEGL.so $out/lib/
    cp ../Release/libGLESv2.so $out/lib/
    patchelf --set-rpath "${rpath}" $out/lib/libcef.so
    patchelf --set-rpath "${gl_rpath}" $out/lib/libEGL.so
    patchelf --set-rpath "${gl_rpath}" $out/lib/libGLESv2.so
    cp ../Release/*.bin $out/share/cef/
    cp -r ../Resources/* $out/share/cef/
    cp -r ../include $out/
  '';

  meta = with lib; {
    description = "Fork of CEF (Chromium Embedded Framework) with OBS-specific patches";
    homepage = "https://github.com/obsproject/cef";
    maintainers = with maintainers; [ flexiondotorg ];
    sourceProvenance = with sourceTypes; [
      fromSource
      binaryNativeCode
    ];
    license = licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}
