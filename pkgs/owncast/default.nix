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
  version = "0.2.1-unstable-2025-01-23";
in buildGoModule {
  pname = "owncast";
  inherit version;
  src = fetchFromGitHub {
    owner = "owncast";
    repo = "owncast";
    #rev = "v${version}";

    rev = "11af286501c44359982f60324b5b727cb40e07d2";
    hash = "sha256-wcDJPCzzJClp15gO3XcbRgrZMHsm61+JnfnNFUcbui4=";
  };
  vendorHash = "sha256-jK450HEQ/P7u/wFW1zLYWosOZ2A7GdC+twzQkAdXjMU=";

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
