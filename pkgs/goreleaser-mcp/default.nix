{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "goreleaser-mcp";
  version = "0.3.4";

  src = fetchFromGitHub {
    owner = "goreleaser";
    repo = "mcp";
    rev = "v${version}";
    hash = "sha256-VMuP3/u8tTtqC2n/Xrq1bCdUdf6xXMtHgBC2KF0hBhc=";
  };

  vendorHash = "sha256-tndQDFg5fANwriXMykU9vU0SEXzQVdk/nbeBDl2Ms5Y=";

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
    "-X main.builtBy=nix"
  ];

  meta = with lib; {
    description = "The GoReleaser MCP server";
    homepage = "https://goreleaser.com/mcp";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = [ maintainers.flexiondotorg ];
    mainProgram = "goreleaser-mcp";
  };
}
