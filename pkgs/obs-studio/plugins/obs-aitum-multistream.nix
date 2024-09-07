{ lib
, stdenv
, fetchFromGitHub
, cmake
, curl
, obs-studio
, qtbase
}:

stdenv.mkDerivation rec {
  pname = "obs-aitum-multistream";
  version = "1.0.3";

  src = fetchFromGitHub {
    owner = "Aitum";
    repo = "obs-aitum-multistream";
    rev = version;
    sha256 = "sha256-A1TXhwJhCLVSGkY8HeZW4e1efGILJkfE0FxEEVq3XA4=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ curl obs-studio qtbase ];

  dontWrapQtApps = true;

  meta = with lib; {
    description = "Plugin to stream everywhere from a single instance of OBS";
    homepage = "https://github.com/Aitum/obs-aitum-multistream";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
