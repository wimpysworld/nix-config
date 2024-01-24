{ lib, stdenv, fetchFromGitHub, obs-studio, cmake, qtbase }:

stdenv.mkDerivation rec {
  pname = "obs-multi-rtmp";
  version = "0.5.0.4";

  src = fetchFromGitHub {
    owner = "sorayuki";
    repo = "obs-multi-rtmp";
    rev = version;
    sha256 = "sha256-rpImKi09ARq0htDCj/xUzpTjjgUQx1Ww9yFIOiv+ZI8=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ obs-studio qtbase ];

  cmakeFlags = [
      "-DQT_VERSION=6 -DENABLE_QT=ON -DCMAKE_COMPILE_WARNING_AS_ERROR=OFF"
  ];

  dontWrapQtApps = true;

  meta = with lib; {
    homepage = "https://github.com/sorayuki/obs-multi-rtmp/";
    changelog = "https://github.com/sorayuki/obs-multi-rtmp/releases/tag/${version}";
    description = "Multi-site simultaneous broadcast plugin for OBS Studio";
    license = licenses.gpl2Only;
    maintainers = with maintainers; [ jk ];
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
