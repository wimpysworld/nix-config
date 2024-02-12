{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
, qtbase
}:

stdenv.mkDerivation rec {
  pname = "obs-shaderfilter";
  version = "2.2.2";

  src = fetchFromGitHub {
    owner = "exeldro";
    repo = "obs-shaderfilter";
    rev = version;
    sha256 = "sha256-cz4Qk56e9CC//a+7pz5rcTxPlMwDwSAKfmgMyBZI4mo=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ obs-studio qtbase ];

  dontWrapQtApps = true;

  postInstall = ''
    rm -rf $out/obs-plugins
    rm -rf $out/share/obs/obs-plugins/*
    mv $out/data/obs-plugins/obs-shaderfilter $out/share/obs/obs-plugins/
    rm -rfv $out/data
  '';

  meta = with lib; {
    description = "OBS Studio filter for applying an arbitrary shader to a source.";
    homepage = "https://github.com/exeldro/obs-shaderfilter";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
