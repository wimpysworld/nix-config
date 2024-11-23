{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
}:

stdenv.mkDerivation rec {
  pname = "obs-stroke-glow-shadow";
  version = "v1.0.2";

  src = fetchFromGitHub {
    owner = "FiniteSingularity";
    repo = "obs-stroke-glow-shadow";
    rev = version;
    sha256 = "sha256-aYt3miY71aikIq0SqHXglC/c/tI8yGkIo1i1wXxiTek=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ obs-studio ];

  cmakeFlags = [
    "-DCMAKE_C_FLAGS=-Wno-stringop-overflow"
  ];

  postFixup = ''
    mv $out/data/obs-plugins/${pname}/shaders $out/share/obs/obs-plugins/${pname}/
    rm -rf $out/obs-plugins
    rm -rf $out/data
  '';

  meta = with lib; {
    description = "An OBS plugin to provide efficient Stroke, Glow, and Shadow effects on masked sources.";
    homepage = "https://github.com/FiniteSingularity/obs-stroke-glow-shadow";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Only;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
