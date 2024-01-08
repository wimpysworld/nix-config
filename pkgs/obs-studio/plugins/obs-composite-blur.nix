{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
}:

stdenv.mkDerivation rec {
  pname = "obs-composite-blur";
  version = "v1.1.0";

  src = fetchFromGitHub {
    owner = "FiniteSingularity";
    repo = "obs-composite-blur";
    rev = version;
    sha256 = "sha256-icn0X+c7Uf0nTFaVDVTPi26sfWTSeoAj7+guEn9gi9Y=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ obs-studio ];

  postFixup = ''
    mv $out/data/obs-plugins/${pname}/shaders $out/share/obs/obs-plugins/${pname}/
    rm -rf $out/obs-plugins
    rm -rf $out/data
  '';

  meta = with lib; {
    description = "A comprehensive blur plugin for OBS that provides several different blur algorithms, and proper compositing.";
    homepage = "https://github.com/FiniteSingularity/obs-composite-blur";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
