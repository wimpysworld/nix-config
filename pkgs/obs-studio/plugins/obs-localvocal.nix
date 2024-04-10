{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
, curl
, qt6
, openai-whisper
}:
stdenv.mkDerivation rec {
  pname = "obs-localvocal";
  version = "0.1.0";

  # FIXME: This is WIP! FTBFS because it can't clone Whisper buring the build step
  src = fetchFromGitHub {
    owner = "occ-ai";
    repo = "obs-localvocal";
    rev = version;
    sha256 = "sha256-/czUGvMOuf4Xk6uho0Ev1KDaLHRxckdx245+wWN4MgA=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ curl obs-studio qt6.qtbase openai-whisper ];
  dontWrapQtApps = true;
  cmakeFlags = [
      "-DQT_VERSION=6"
      "-DENABLE_QT=ON"
      "-DUSE_SYSTEM_CURL=ON"
      "-DCMAKE_COMPILE_WARNING_AS_ERROR=OFF"
  ];

  #postUnpack = ''
  #  cp -r ${openai-whisper.src}/* $sourceRoot/Whispercpp_Build
  #  chmod -R +w $sourceRoot/Whispercpp_Build
  #'';


  meta = with lib; {
    description = "OBS plugin for local speech recognition and captioning using AI";
    homepage = "https://github.com/occ-ai/obs-localvocal";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Only;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
