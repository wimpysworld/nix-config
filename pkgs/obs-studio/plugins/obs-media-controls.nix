{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
, qt6
}:

stdenv.mkDerivation rec {
  pname = "obs-media-controls";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "exeldro";
    repo = "obs-media-controls";
    rev = "6a186e7ee6abb008436c8c1f5f9187c6dc55e298";
    sha256 = "sha256-j/TsIf4BoEU/U8/d5GukbHJNCQ53uzXs+TymvHUDpzk=";
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
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
