{ config
, lib
, stdenv
, fetchFromGitHub
, addOpenGLRunpath
, cmake
, fdk_aac
, ffmpeg-headless
, jansson
, libjack2
, libxkbcommon
, libpthreadstubs
, libXdmcp
, qt6
, speex
, libv4l
, x264
, curl
, wayland
, xorg
, pkg-config
, libvlc
, libGL
, mbedtls
, wrapGAppsHook
, scriptingSupport ? true
, luajit
, swig4
, python3
, alsaSupport ? stdenv.isLinux
, alsa-lib
, pulseaudioSupport ? config.pulseaudio or stdenv.isLinux
, libpulseaudio
, pciutils
, pipewireSupport ? stdenv.isLinux
, pipewire
, libdrm
, libajantv2
, librist
, libva
, srt
, nlohmann_json
, websocketpp
, asio
, decklinkSupport ? false
, blackmagic-desktop-video
, libdatachannel
, cjson
, vulkan-loader
, pkgs
}:

let
  inherit (lib) optional optionals;
  obscef = pkgs.callPackage ../obscef { };
  libdatachannel = pkgs.callPackage ../libdatachannel { };
  libvpl = pkgs.callPackage ../libvpl { };
  qrcodegencpp = pkgs.callPackage ../qrcodegencpp { };
in

stdenv.mkDerivation (finalAttrs: {
  pname = "obs-studio";
  version = "30.1.0-beta3";

  src = fetchFromGitHub {
    owner = "obsproject";
    repo = finalAttrs.pname;
    rev = finalAttrs.version;
    sha256 = "sha256-Uadpfzv8UHHzI3UMCQ/CcuiSme1ke/j8nYRdEkCj8ic=";
    fetchSubmodules = true;
  };

  patches = [
    ./fix-nix-plugin-path.patch
  ];

  nativeBuildInputs = [
    addOpenGLRunpath
    cmake
    pkg-config
    wrapGAppsHook
    qt6.wrapQtAppsHook
  ]
  ++ optional scriptingSupport swig4;

  buildInputs = [
    curl
    fdk_aac
    ffmpeg-headless
    jansson
    obscef
    libjack2
    libv4l
    libxkbcommon
    libpthreadstubs
    libXdmcp
    qt6.qtbase
    qt6.qtsvg
    speex
    wayland
    x264
    libvlc
    mbedtls
    pciutils
    libajantv2
    librist
    libva
    srt
    qt6.qtwayland
    nlohmann_json
    websocketpp
    asio
    libdatachannel
    libvpl
    qrcodegencpp
    cjson
    vulkan-loader
  ]
  ++ optionals scriptingSupport [ luajit python3 ]
  ++ optional alsaSupport alsa-lib
  ++ optional pulseaudioSupport libpulseaudio
  ++ optionals pipewireSupport [ pipewire libdrm ];

  # Copied from the obs-linuxbrowser
  postUnpack = ''
    mkdir -p cef/Release cef/Resources cef/libcef_dll_wrapper/
    for i in ${obscef}/share/cef/*; do
      ln -s $i cef/Release/
      ln -s $i cef/Resources/
    done
    ln -s ${obscef}/lib/libcef.so cef/Release/
    ln -s ${obscef}/lib/libcef_dll_wrapper.a cef/libcef_dll_wrapper/
    ln -s ${obscef}/include cef/
  '';

  cmakeFlags = [
    "-DOBS_VERSION_OVERRIDE=${finalAttrs.version}"
    "-Wno-dev" # kill dev warnings that are useless for packaging
    # Add support for browser source
    "-DBUILD_BROWSER=ON"
    "-DCEF_ROOT_DIR=../../cef"
    "-DENABLE_ALSA=OFF"
    "-DENABLE_JACK=ON"
    "-DENABLE_LIBFDK=ON"
  ];

  # https://github.com/obsproject/obs-studio/issues/10200
  NIX_CFLAGS_COMPILE = [ "-Wno-error=sign-compare" ];

  dontWrapGApps = true;
  preFixup = let
    wrapperLibraries = [
      xorg.libX11
      libvlc
      libGL
    ] ++ optionals decklinkSupport [
      blackmagic-desktop-video
    ];
  in ''
    # Remove libcef before patchelf, otherwise it will fail
    rm $out/lib/obs-plugins/libcef.so

    qtWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "$out/lib:${lib.makeLibraryPath wrapperLibraries}"
      ''${gappsWrapperArgs[@]}
    )
  '';

  postFixup = lib.optionalString stdenv.isLinux ''
    addOpenGLRunpath $out/lib/lib*.so
    addOpenGLRunpath $out/lib/obs-plugins/*.so

    # Link libcef again after patchelfing other libs
    ln -s ${obscef}/lib/* $out/lib/obs-plugins/
  '';

  meta = with lib; {
    description = "Free and open source software for video recording and live streaming";
    longDescription = ''
      This project is a rewrite of what was formerly known as "Open Broadcaster
      Software", software originally designed for recording and streaming live
      video content, efficiently
    '';
    homepage = "https://obsproject.com";
    maintainers = with maintainers; [ jb55 MP2E materus fpletz ];
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "obs";
  };
})
