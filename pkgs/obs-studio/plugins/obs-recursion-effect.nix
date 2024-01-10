{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
}:

stdenv.mkDerivation rec {
  pname = "obs-recursion-effect";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "exeldro";
    repo = "obs-recursion-effect";
    rev = version;
    sha256 = "sha256-PeWJy423QbX4NULuS15LJ/IR/W+tXCJD9TjZdJOGk6A=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ obs-studio ];

  postInstall = ''
    rm -rf $out/obs-plugins $out/data
  '';

  meta = with lib; {
    description = "Plugin for OBS Studio to add recursion effect to a source using a filter";
    homepage = "https://github.com/exeldro/obs-recursion-effect";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
