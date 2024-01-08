{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
}:

stdenv.mkDerivation rec {
  pname = "obs-dvd-screensaver";
  version = "0.0.2";

  src = fetchFromGitHub {
    owner = "wimpysworld";
    repo = "obs-dvd-screensaver";
    rev = version;
    sha256 = "sha256-uZdFP3TULECzYNKtwaxFIcFYeFYdEoJ+ZKAqh9y9MEo=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ obs-studio ];

  meta = with lib; {
    description = "DVD screen saver for OBS Studio";
    homepage = "https://github.com/wimpysworld/obs-dvd-screensaver";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
