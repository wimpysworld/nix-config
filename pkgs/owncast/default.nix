{ lib
, buildGoModule
, fetchFromGitHub
, nixosTests
, bash
, which
, ffmpeg-full
, makeBinaryWrapper
}:
let
  version = "0.2.0";
in buildGoModule {
  pname = "owncast";
  inherit version;
  src = fetchFromGitHub {
    owner = "owncast";
    repo = "owncast";
    #rev = "v${version}";

    rev = "2c2bf2b5bbf49885f14f19c3f04dbbb0f3fbc5f2";
    hash = "sha256-1ghdwAq+m2Kz4yy50+IU4KtyYBbtJz3vwfmCgja0LRE=";
  };
  vendorHash = "sha256-h17CzPyboCessk6oRHTurIzjhLgg7/jxfBPd5Vp3Vos=";

  patches = [
    ./4022.diff   # VA-API
    ./4028.diff   # Quicksync
  ];

  propagatedBuildInputs = [ ffmpeg-full ];

  nativeBuildInputs = [ makeBinaryWrapper ];

  postInstall = ''
    wrapProgram $out/bin/owncast \
      --prefix PATH : ${lib.makeBinPath [ bash which ffmpeg-full ]}
  '';

  installCheckPhase = ''
    runHook preCheck
    $out/bin/owncast --help
    runHook postCheck
  '';

  passthru.tests.owncast = nixosTests.owncast;

  meta = with lib; {
    description = "self-hosted video live streaming solution";
    homepage = "https://owncast.online";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = with maintainers; [ MayNiklas ];
    mainProgram = "owncast";
  };
}
