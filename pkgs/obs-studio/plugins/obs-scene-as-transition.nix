{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
}:

stdenv.mkDerivation rec {
  pname = "obs-scene-as-transition";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "andilippi";
    repo = "obs-scene-as-transition";
    rev = "v${version}";
    sha256 = "sha256-uzNsHdsW140N+Cq0+aOjXmsqDLM9KCRRqQVfH3fSEGU=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ obs-studio ];

  postInstall = ''
    rm -rf $out/obs-plugins $out/data
  '';

  meta = with lib; {
    description = "An OBS Studio plugin that will allow you to use a Scene as a transition";
    homepage = "https://github.com/andilippi/obs-scene-as-transition";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
