{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
, curl
, qt6
}:
stdenv.mkDerivation rec {
  pname = "obs-localvocal";
  version = "0.1.0";

  # FTBFS because it wants to clone git repos during the build
  src = fetchFromGitHub {
    owner = "occ-ai";
    repo = "obs-localvocal";
    rev = version;
    sha256 = "sha256-/czUGvMOuf4Xk6uho0Ev1KDaLHRxckdx245+wWN4MgA=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ curl obs-studio qt6.qtbase];
  dontWrapQtApps = true;
  cmakeFlags = [
      "-DQT_VERSION=6"
      "-DENABLE_QT=ON"
      "-DUSE_SYSTEM_CURL=ON"
      #"-DCMAKE_COMPILE_WARNING_AS_ERROR=OFF"
  ];

  meta = with lib; {
    description = "OBS plugin for local speech recognition and captioning using AI";
    homepage = "https://github.com/occ-ai/localvocal";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
