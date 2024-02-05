{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
}:

stdenv.mkDerivation rec {
  pname = "obs-retro-effects";
  version = "0.0.2a";

  src = fetchFromGitHub {
    owner = "FiniteSingularity";
    repo = "obs-retro-effects";
    rev = "${version}";
    sha256 = "sha256-EPzfCKL4JQiRaHyJJw0HNqfhHiYd/v2705R+j5H/Oow=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ obs-studio ];

  postFixup = ''
    mv $out/data/obs-plugins/${pname}/shaders $out/share/obs/obs-plugins/${pname}/
    rm -rf $out/obs-plugins
    rm -rf $out/data
  '';

  meta = with lib; {
    description = "A collection of OBS filters to give your stream that retro feel.";
    homepage = "https://github.com/FiniteSingularity/obs-retro-effects";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
