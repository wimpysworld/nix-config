{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
}:

stdenv.mkDerivation rec {
  pname = "obs-markdown";
  version = "0.2.4";

  src = fetchFromGitHub {
    owner = "exeldro";
    repo = "obs-markdown";
    rev = version;
    sha256 = "sha256-tL17miSkeMfNV0JoLAIY/IqtwB0PG/kzrYC5CY0B+iE=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ obs-studio ];

  postInstall = ''
    rm -rf $out/obs-plugins $out/data
  '';

  meta = with lib; {
    description = "Plugin for OBS Studio to add Markdown sources";
    homepage = "https://github.com/exeldro/obs-markdown";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Only;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
