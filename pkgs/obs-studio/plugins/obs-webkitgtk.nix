{ lib
, stdenv
, fetchFromGitHub
, webkitgtk_4_1
, pkg-config
, meson
, ninja
, obs-studio
}:

stdenv.mkDerivation rec {
  pname = "obs-webkitgtk";
  version = "unstable-2023-11-10";

  src = fetchFromGitHub {
    owner = "fzwoch";
    repo = pname;
    rev = "ddf230852c3c338e69b248bdf453a0630f1298a7";
    hash = "sha256-DU2w9dRgqWniTE76KTAtFdxIN82VKa/CS6ZdfNcTMto=";
  };

  nativeBuildInputs = [ pkg-config meson ninja ];
  buildInputs = [ webkitgtk_4_1 obs-studio ];

  # - We need "getLib" instead of default derivation, otherwise it brings gstreamer-bin;
  # - without gst-plugins-base it won't even show proper errors in logs;
  # - Without gst-plugins-bad it won't find element "h264parse";
  # - gst-plugins-ugly adds "x264" to "Encoder type";
  # Tip: "could not link appsrc to videoconvert1" can mean a lot of things, enable GST_DEBUG=2 for help.
  #passthru.obsWrapperArguments =
  #  let
  #    gstreamerHook = package: "--prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${lib.getLib package}/lib/gstreamer-1.0";
  #  in
  #  with gst_all_1; builtins.map gstreamerHook [
  #    gstreamer
  #    gst-plugins-base
  #    gst-plugins-bad
  #    gst-plugins-ugly
  #  ];

  # Fix output directory
  #postInstall = ''
  #  mkdir $out/lib/obs-plugins
    #mv $out/lib/obs-gstreamer.so $out/lib/obs-plugins/
  #'';

  meta = with lib; {
    description = "Yet another OBS Studio browser source";
    homepage = "https://github.com/fzwoch/obs-webkitgtk";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
