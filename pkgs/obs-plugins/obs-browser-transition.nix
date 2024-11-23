{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
}:

stdenv.mkDerivation rec {
  pname = "obs-browser-transition";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "exeldro";
    repo = "obs-browser-transition";
    rev = version;
    sha256 = "sha256-m5UDqnqipkybXAZqS7c2Sj/mJKrDBkXElyc0I+c1BmE=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ obs-studio ];

  postInstall = ''
    rm -rf $out/obs-plugins $out/data
  '';

  meta = with lib; {
    description = "Plugin for OBS Studio to show a browser source during scene transition";
    homepage = "https://github.com/exeldro/obs-browser-transition";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Only;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
