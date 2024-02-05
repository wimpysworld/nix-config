{ stdenv
, lib
, fetchFromGitHub
, cmake
, libcaption
, obs-studio
, qtbase
}:

stdenv.mkDerivation (_finalAttrs: {
  pname = "obs-replay-source";
  version = "1.7.0";


  src = fetchFromGitHub {
    owner = "exeldro";
    repo = "obs-replay-source";
    #rev = finalAttrs.version;
    rev =  "6590fde1c8e4f8c733016646a8165d52e28d094b";
    sha256 = "sha256-foIzWNlU72FWXZVWR8TEiqJJMfl1vWYDTyhV6thYJbA=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ libcaption obs-studio qtbase ];

  postInstall = ''
    rm -rf $out/obs-plugins $out/data
  '';

  dontWrapQtApps = true;

  meta = with lib; {
    description = "Replay source for OBS studio";
    homepage = "https://github.com/exeldro/obs-replay-source";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = with maintainers; [ pschmitt ];
  };
})
