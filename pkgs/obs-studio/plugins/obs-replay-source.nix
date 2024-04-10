{ stdenv
, lib
, fetchFromGitHub
, cmake
, libcaption
, obs-studio
}:

stdenv.mkDerivation ({
  pname = "obs-replay-source";
  version = "1.7.0-unstable-2024-03-22";

  src = fetchFromGitHub {
    owner = "exeldro";
    repo = "obs-replay-source";
    rev = "520c52c5513eb91f32220afc0a1ba1d4f04fd646";
    sha256 = "sha256-+/0j4w/biK/GpmyVmvT6WHYdjXMQQwjCkzAb7oNdpNA=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ libcaption obs-studio ];

  postInstall = ''
    rm -rf $out/obs-plugins $out/data
  '';

  meta = with lib; {
    description = "Replay source for OBS studio";
    homepage = "https://github.com/exeldro/obs-replay-source";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = with maintainers; [ flexiondotorg pschmitt ];
  };
})
