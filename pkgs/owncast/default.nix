{ lib
, buildGoModule
, fetchFromGitHub
, fetchpatch
, nixosTests
, bash
, which
, ffmpeg-full
, makeBinaryWrapper
}:
let
  version = "0.2.0-unstable-2024-12-06";
in buildGoModule {
  pname = "owncast";
  inherit version;
  src = fetchFromGitHub {
    owner = "owncast";
    repo = "owncast";
    #rev = "v${version}";

    rev = "4f1c1ec683fd257e729285aad13e5bfea5f93a5d";
    hash = "sha256-0m2w5CReDbwTqG+uQcooTVeQRPR0unZRL+3FG4fxQe0=";
  };
  vendorHash = "sha256-asJNRqyMEYpyzHzj5huepDeXj5fkoM9lm0nhAG4bDwU=";

  # Add my patches
  patches = [
    (fetchpatch {
      # VA-API
      url = "https://patch-diff.githubusercontent.com/raw/owncast/owncast/pull/4022.diff";
      sha256 = "sha256-fyloQSlDbNWwXcC12wba9HJiqQCT5PztosAjbGl2tw4=";
    })
    (fetchpatch {
      # Quicksync
      url = "https://patch-diff.githubusercontent.com/raw/owncast/owncast/pull/4028.diff";
      sha256 = "sha256-Hwy11C3Fu43qFc0hX2vbhSpEpS7KXHiP0xTmidbBq58=";
    })
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
