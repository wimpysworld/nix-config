{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
, qt6
}:

stdenv.mkDerivation rec {
  pname = "obs-media-controls";
  version = "0.4.1";

  src = fetchFromGitHub {
    owner = "exeldro";
    repo = "obs-media-controls";
    rev = version;
    sha256 = "sha256-r9fqpg0G9rzGSqq5FUS8ul58rj0796aGZIND8PCJ9jk=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ obs-studio qt6.qtbase ];

  dontWrapQtApps = true;

  postInstall = ''
    rm -rf $out/obs-plugins $out/data
  '';

  meta = with lib; {
    description = "Plugin for OBS Studio to add a Media Controls dock.";
    homepage = "https://github.com/exeldro/obs-media-controls";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Only;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
