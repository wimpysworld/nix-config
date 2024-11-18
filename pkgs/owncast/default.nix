{ lib
, buildGoModule
, fetchFromGitHub
, nixosTests
, bash
, which
, ffmpeg
, makeBinaryWrapper
}:
let
  version = "0.1.3";
in buildGoModule {
  pname = "owncast";
  inherit version;
  src = fetchFromGitHub {
    owner = "flexiondotorg";
    repo = "owncast";

    # owncast/0.1.3
    #rev = "v${version}";
    #hash = "sha256-VoItAV/8hzrqj4bIgMum9Drr/kAafH63vXw3GO6nSOc=";

    # ffmpeg6 testing
    #rev = "gek/ffmpeg-6";
    #hash = "sha256-Y5vfcNZsi+BRhFncR8rD4BK4lR4kgcIO+iAElXBBzQw=";

    # flexiondotorg/ffmpeg6
    rev = "ffmpeg6";
    hash = "sha256-kSLYlC49g1S6lpj8NsfYzO3Q32J50si9STCJuQWviYA=";
  };
  # owncast/0.1.3
  #vendorHash = "sha256-JitvKfCLSravW5WRE0QllJTrRPLaaBg1GxJi3kmtiIU=";

  # owncast/develop
  #vendorHash = "sha256-Mp7epsFqlJqBDcE61tS6eNSXiwt6rzMZdh3nJ33L3eA=";

  # flexiondotorg/ffmpeg6
  vendorHash = "sha256-yxWXh16vZIND9QB3xb0G5OOVhA7iy2dWNUzQXNi6gEk=";

  propagatedBuildInputs = [ ffmpeg ];

  nativeBuildInputs = [ makeBinaryWrapper ];

  postInstall = ''
    wrapProgram $out/bin/owncast \
      --prefix PATH : ${lib.makeBinPath [ bash which ffmpeg ]}
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
