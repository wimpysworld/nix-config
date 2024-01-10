{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
, pugixml
, curl
, qt6
}:
stdenv.mkDerivation rec {
  pname = "obs-urlsource";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "occ-ai";
    repo = "obs-urlsource";
    rev = version;
    sha256 = "sha256-9Jt2SoIspcKzsFAMTzw8MxlPG4o/gtGOYwwS1f4ZRyA=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ curl obs-studio pugixml qt6.qtbase ];
  dontWrapQtApps = true;
  cmakeFlags = [
      "-DQT_VERSION=6"
      "-DENABLE_QT=ON"
      "-DUSE_SYSTEM_CURL=ON"
      "-DUSE_SYSTEM_PUGIXML=ON"
      "-DCMAKE_COMPILE_WARNING_AS_ERROR=OFF"
  ];

  meta = with lib; {
    description = "OBS plugin to fetch data from a URL or file, connect to an API or AI service, parse responses and display text, image or audio on scene";
    homepage = "https://github.com/occ-ai/obs-urlsource";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
