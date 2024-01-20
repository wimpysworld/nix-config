{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
}:

stdenv.mkDerivation rec {
  pname = "obs-noise";
  version = "0.0.4a";

  src = fetchFromGitHub {
    owner = "FiniteSingularity";
    repo = "obs-noise";
    rev = "v${version}";
    sha256 = "sha256-LWmxe7/1GZ1S8tkdPpCsLVSYdeNyzhYD/sKrSR2OjPg=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ obs-studio ];

  postFixup = ''
    mv $out/data/obs-plugins/${pname}/shaders $out/share/obs/obs-plugins/${pname}/
    rm -rf $out/obs-plugins
    rm -rf $out/data
  '';

  meta = with lib; {
    description = "A plug-in for noise generation and noise effects for OBS.";
    homepage = "https://github.com/FiniteSingularity/obs-noise";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
