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

    rev = "49c07594fba75e7c098cb4914b8668b9fc081f8d";
    hash = "sha256-YUi/M9fqwhC75n/YKooj5RqfMy+kdon1jsBvTMKvPw4=";
  };
  vendorHash = "sha256-yxWXh16vZIND9QB3xb0G5OOVhA7iy2dWNUzQXNi6gEk=";

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
